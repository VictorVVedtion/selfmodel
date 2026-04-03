"""
Benchmark configuration.

All paths, timeouts, model names, and tunables in one place.
"""
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────────────────
BENCHMARK_DIR = Path(__file__).parent.resolve()
WORKSPACE_DIR = BENCHMARK_DIR / "workspace"
PREDICTIONS_DIR = BENCHMARK_DIR / "predictions"
RESULTS_DIR = BENCHMARK_DIR / "results"
PROMPTS_DIR = BENCHMARK_DIR / "prompts"
INBOX_DIR = BENCHMARK_DIR / "inbox"

# ── Dataset ────────────────────────────────────────────────────────────────
DATASET_NAME = "princeton-nlp/SWE-bench_Verified"
DATASET_SPLIT = "test"

# ── Agent CLIs ─────────────────────────────────────────────────────────────
CLAUDE_CMD = "claude"
GEMINI_CMD = "gemini"
CODEX_CMD = "codex"

# ── Models ─────────────────────────────────────────────────────────────────
GEMINI_MODEL = "gemini-2.5-pro"
CLAUDE_MODEL = "opus"  # claude CLI --model flag

# ── Timeouts (seconds) ────────────────────────────────────────────────────
RESEARCHER_TIMEOUT = 180   # Gemini research step (3 min)
SOLVER_TIMEOUT = 600       # Agent solving step (10 min, large repos need time)
REVIEWER_TIMEOUT = 120     # Evaluator review step (2 min)
LEADER_TIMEOUT = 60        # Leader analysis step

# ── Parallelism ───────────────────────────────────────────────────────────
MAX_WORKERS = 1  # serial by default; increase for parallel instance runs

# ── Run modes ─────────────────────────────────────────────────────────────
MODES = ["solo-claude", "solo-codex", "orchestrated"]

# ── Prediction format ─────────────────────────────────────────────────────
MODEL_NAME = "selfmodel-team"  # model_name_or_path in predictions.jsonl
