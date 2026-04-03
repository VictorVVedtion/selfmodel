"""
SWE-bench dataset loading and instance management.

Loads from HuggingFace, supports filtering by instance IDs, repo, difficulty.
"""
import json
from typing import Optional

from datasets import load_dataset


def load_swebench(
    dataset_name: str,
    split: str,
    instance_ids: Optional[list[str]] = None,
    repos: Optional[list[str]] = None,
    max_count: Optional[int] = None,
) -> list[dict]:
    """Load SWE-bench dataset with optional filters.

    Args:
        dataset_name: HuggingFace dataset path.
        split: Dataset split (usually "test").
        instance_ids: Filter to specific instance IDs.
        repos: Filter to specific repos (e.g., ["django/django"]).
        max_count: Limit number of instances returned.

    Returns:
        List of instance dicts, each with all SWE-bench fields.
    """
    ds = load_dataset(dataset_name, split=split)

    if instance_ids:
        id_set = set(instance_ids)
        ds = ds.filter(lambda x: x["instance_id"] in id_set)

    if repos:
        repo_set = set(repos)
        ds = ds.filter(lambda x: x["repo"] in repo_set)

    instances = [dict(row) for row in ds]

    if max_count and len(instances) > max_count:
        instances = instances[:max_count]

    return instances


def parse_test_list(raw: str) -> list[str]:
    """Parse FAIL_TO_PASS / PASS_TO_PASS fields (JSON-encoded string lists)."""
    return json.loads(raw) if raw else []


def get_instance_summary(instance: dict) -> dict:
    """Quick summary for logging."""
    f2p = parse_test_list(instance.get("FAIL_TO_PASS", "[]"))
    return {
        "id": instance["instance_id"],
        "repo": instance["repo"],
        "difficulty": instance.get("difficulty", "unknown"),
        "fail_to_pass_count": len(f2p),
        "problem_length": len(instance.get("problem_statement", "")),
    }


def group_by_repo(instances: list[dict]) -> dict[str, list[dict]]:
    """Group instances by repo for efficient clone reuse."""
    groups: dict[str, list[dict]] = {}
    for inst in instances:
        repo = inst["repo"]
        groups.setdefault(repo, []).append(inst)
    return groups
