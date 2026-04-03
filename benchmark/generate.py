#!/usr/bin/env python3
"""
SWE-bench generation script — the core of the benchmark harness.

Usage:
    python generate.py --mode orchestrated --count 10
    python generate.py --mode solo-claude --instances "django__django-11583,astropy__astropy-12907"
    python generate.py --mode solo-codex --repo "django/django" --count 5
"""
import argparse
import json
import logging
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from benchmark.config import (
    DATASET_NAME,
    DATASET_SPLIT,
    MAX_WORKERS,
    PREDICTIONS_DIR,
    RESULTS_DIR,
)
from benchmark.lib.dataset import get_instance_summary, group_by_repo, load_swebench
from benchmark.lib.orchestrator import run_orchestrated, run_solo_claude, run_solo_codex

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("generate")

MODE_RUNNERS = {
    "solo-claude": run_solo_claude,
    "solo-codex": run_solo_codex,
    "orchestrated": run_orchestrated,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="SWE-bench generation with selfmodel orchestration")
    parser.add_argument(
        "--mode", choices=list(MODE_RUNNERS.keys()), default="orchestrated",
        help="Run mode (default: orchestrated)",
    )
    parser.add_argument(
        "--count", type=int, default=None,
        help="Max number of instances to process",
    )
    parser.add_argument(
        "--instances", type=str, default=None,
        help="Comma-separated instance IDs to process",
    )
    parser.add_argument(
        "--repo", type=str, default=None,
        help="Filter to specific repo (e.g., django/django)",
    )
    parser.add_argument(
        "--run-id", type=str, default=None,
        help="Run identifier (default: auto-generated)",
    )
    parser.add_argument(
        "--workers", type=int, default=MAX_WORKERS,
        help=f"Parallel workers (default: {MAX_WORKERS})",
    )
    parser.add_argument(
        "--dataset", type=str, default=DATASET_NAME,
        help=f"HuggingFace dataset name (default: {DATASET_NAME})",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Load dataset and show plan without executing",
    )
    parser.add_argument(
        "--resume", action="store_true",
        help="Skip instances already in the predictions file",
    )
    return parser.parse_args()


def generate_run_id(mode: str) -> str:
    """Generate a unique run ID."""
    ts = time.strftime("%Y%m%d-%H%M%S")
    return f"{mode}-{ts}"


def process_instance(instance: dict, mode: str, run_id: str) -> dict:
    """Process a single instance. Returns serializable result dict."""
    runner = MODE_RUNNERS[mode]
    result = runner(instance, run_id)
    return {
        "instance_id": result.instance_id,
        "mode": result.mode,
        "success": result.success,
        "has_patch": bool(result.patch.strip()),
        "patch_lines": len(result.patch.strip().split("\n")) if result.patch.strip() else 0,
        "duration_s": round(result.duration_s, 1),
        "steps": result.steps,
        "error": result.error,
    }


def main():
    args = parse_args()
    run_id = args.run_id or generate_run_id(args.mode)

    logger.info(f"Run ID: {run_id}")
    logger.info(f"Mode: {args.mode}")

    # Load dataset
    instance_ids = args.instances.split(",") if args.instances else None
    repos = [args.repo] if args.repo else None

    logger.info(f"Loading dataset: {args.dataset}")
    instances = load_swebench(
        args.dataset, DATASET_SPLIT,
        instance_ids=instance_ids, repos=repos, max_count=args.count,
    )
    logger.info(f"Loaded {len(instances)} instances")

    # Show plan
    by_repo = group_by_repo(instances)
    logger.info("Instance distribution:")
    for repo_name, repo_instances in sorted(by_repo.items(), key=lambda x: -len(x[1])):
        logger.info(f"  {repo_name}: {len(repo_instances)}")

    if args.dry_run:
        logger.info("Dry run — showing first 5 instances:")
        for inst in instances[:5]:
            summary = get_instance_summary(inst)
            logger.info(f"  {summary['id']} ({summary['repo']}) "
                       f"difficulty={summary['difficulty']} "
                       f"problem_len={summary['problem_length']}")
        return

    # Resume: skip already-completed instances
    completed_ids = set()
    if args.resume:
        pred_file = PREDICTIONS_DIR / f"{run_id}.jsonl"
        if pred_file.exists():
            from benchmark.lib.predictions import read_predictions
            existing = read_predictions(pred_file)
            completed_ids = {e["instance_id"] for e in existing if e.get("model_patch", "").strip()}
            logger.info(f"Resuming: skipping {len(completed_ids)} already-completed instances")
            instances = [i for i in instances if i["instance_id"] not in completed_ids]

    # Execute
    results = []
    total = len(instances)

    if args.workers <= 1:
        # Serial execution
        for i, inst in enumerate(instances, 1):
            logger.info(f"[{i}/{total}] Processing {inst['instance_id']}...")
            result = process_instance(inst, args.mode, run_id)
            results.append(result)
            status = "OK" if result["success"] else "FAIL"
            logger.info(
                f"[{i}/{total}] {result['instance_id']}: {status} "
                f"({result['duration_s']}s, {result['patch_lines']} lines)"
            )
    else:
        # Parallel execution
        with ProcessPoolExecutor(max_workers=args.workers) as executor:
            futures = {
                executor.submit(process_instance, inst, args.mode, run_id): inst
                for inst in instances
            }
            for i, future in enumerate(as_completed(futures), 1):
                result = future.result()
                results.append(result)
                status = "OK" if result["success"] else "FAIL"
                logger.info(
                    f"[{i}/{total}] {result['instance_id']}: {status} "
                    f"({result['duration_s']}s)"
                )

    # Summary
    succeeded = sum(1 for r in results if r["success"])
    failed = sum(1 for r in results if not r["success"])
    total_time = sum(r["duration_s"] for r in results)

    logger.info("=" * 60)
    logger.info(f"Run complete: {run_id}")
    logger.info(f"  Total: {len(results)} | Success: {succeeded} | Failed: {failed}")
    logger.info(f"  Total time: {total_time:.0f}s | Avg: {total_time / len(results):.1f}s")
    logger.info(f"  Predictions: {PREDICTIONS_DIR / f'{run_id}.jsonl'}")

    # Save run metadata
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    meta_file = RESULTS_DIR / f"{run_id}-meta.json"
    meta = {
        "run_id": run_id,
        "mode": args.mode,
        "dataset": args.dataset,
        "total_instances": len(results),
        "succeeded": succeeded,
        "failed": failed,
        "total_time_s": round(total_time, 1),
        "results": results,
    }
    meta_file.write_text(json.dumps(meta, indent=2, ensure_ascii=False))
    logger.info(f"  Metadata: {meta_file}")


if __name__ == "__main__":
    main()
