"""
Target repository setup — clone, checkout, diff collection.

Clones each repo once under workspace/, reuses across instances.
Uses git checkout to switch between base_commits.
"""
import logging
import subprocess
from pathlib import Path

logger = logging.getLogger(__name__)


def ensure_repo_clone(repo_name: str, workspace_dir: Path) -> Path:
    """Clone repo if not already present. Returns repo directory path.

    Uses bare-style naming: django/django → workspace/django__django
    """
    safe_name = repo_name.replace("/", "__")
    repo_dir = workspace_dir / safe_name

    if repo_dir.exists() and (repo_dir / ".git").exists():
        logger.info(f"Repo already cloned: {repo_dir}")
        return repo_dir

    url = f"https://github.com/{repo_name}.git"
    logger.info(f"Cloning {url} → {repo_dir}")
    workspace_dir.mkdir(parents=True, exist_ok=True)

    # Blobless clone: fetch tree structure immediately, blobs on demand.
    # Saves 50-70% download for large repos (Django 2.5GB → ~800MB).
    # Supports checkout of any historical commit (blobs fetched as needed).
    subprocess.run(
        ["git", "clone", "--quiet", "--filter=blob:none", url, str(repo_dir)],
        check=True,
        timeout=1200,  # large repos may need 20 min
    )
    return repo_dir


def checkout_commit(repo_dir: Path, commit_hash: str) -> None:
    """Hard checkout to a specific commit. Cleans working tree."""
    logger.info(f"Checking out {commit_hash[:10]} in {repo_dir.name}")
    subprocess.run(
        ["git", "checkout", "--force", commit_hash],
        cwd=repo_dir, check=True, capture_output=True,
    )
    subprocess.run(
        ["git", "clean", "-fdx"],
        cwd=repo_dir, check=True, capture_output=True,
    )


def reset_to_clean(repo_dir: Path, commit_hash: str) -> None:
    """Full reset: discard all changes and return to base commit."""
    subprocess.run(
        ["git", "reset", "--hard", commit_hash],
        cwd=repo_dir, check=True, capture_output=True,
    )
    subprocess.run(
        ["git", "clean", "-fdx"],
        cwd=repo_dir, check=True, capture_output=True,
    )


def collect_diff(repo_dir: Path) -> str:
    """Collect unified diff of all staged + unstaged changes.

    Returns the diff string suitable for model_patch in predictions.
    """
    # Stage everything first to capture new files
    subprocess.run(
        ["git", "add", "-A"],
        cwd=repo_dir, check=True, capture_output=True,
    )
    result = subprocess.run(
        ["git", "diff", "--cached"],
        cwd=repo_dir, capture_output=True, text=True,
    )
    return result.stdout


def get_repo_file_tree(repo_dir: Path, max_depth: int = 3) -> str:
    """Get directory tree for context. Lightweight, no file contents."""
    result = subprocess.run(
        ["find", ".", "-maxdepth", str(max_depth),
         "-type", "f", "-not", "-path", "./.git/*",
         "-not", "-path", "./.tox/*",
         "-not", "-path", "./node_modules/*",
         "-not", "-path", "./__pycache__/*"],
        cwd=repo_dir, capture_output=True, text=True, timeout=30,
    )
    lines = result.stdout.strip().split("\n")
    if len(lines) > 200:
        return "\n".join(lines[:200]) + f"\n... ({len(lines) - 200} more files)"
    return result.stdout.strip()
