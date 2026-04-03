"""
Predictions file management — write/read JSONL in SWE-bench format.

Format per line:
{"instance_id": "...", "model_name_or_path": "...", "model_patch": "..."}
"""
import json
import logging
from pathlib import Path

logger = logging.getLogger(__name__)


def write_prediction(
    predictions_dir: Path,
    run_id: str,
    instance_id: str,
    model_name: str,
    patch: str,
) -> None:
    """Append one prediction to the run's JSONL file."""
    predictions_dir.mkdir(parents=True, exist_ok=True)
    out_file = predictions_dir / f"{run_id}.jsonl"

    entry = {
        "instance_id": instance_id,
        "model_name_or_path": model_name,
        "model_patch": patch,
    }

    with open(out_file, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    logger.info(f"Prediction saved: {instance_id} → {out_file.name}")


def read_predictions(predictions_file: Path) -> list[dict]:
    """Read all predictions from a JSONL file."""
    entries = []
    with open(predictions_file, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))
    return entries


def get_prediction_stats(predictions_file: Path) -> dict:
    """Quick stats on a predictions file."""
    entries = read_predictions(predictions_file)
    empty = sum(1 for e in entries if not e.get("model_patch"))
    return {
        "total": len(entries),
        "with_patch": len(entries) - empty,
        "empty_patch": empty,
        "repos": len({e["instance_id"].rsplit("-", 1)[0] for e in entries}),
    }
