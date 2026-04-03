"""
Orchestration engine — the brain of the benchmark harness.

Implements three run modes:
- solo-claude: Claude solves everything alone
- solo-codex: Codex solves everything alone
- orchestrated: Researcher (Gemini) → Solver (Claude/Codex) → Reviewer (Gemini)

The orchestrated mode is the selfmodel value proposition:
research before implementation + independent evaluation.
"""
import json
import logging
import time
from dataclasses import dataclass, field
from pathlib import Path

from . import agents, predictions, repo
from ..config import (
    GEMINI_MODEL,
    INBOX_DIR,
    PREDICTIONS_DIR,
    RESEARCHER_TIMEOUT,
    REVIEWER_TIMEOUT,
    SOLVER_TIMEOUT,
    WORKSPACE_DIR,
)
from ..prompts.templates import RESEARCHER, REVIEWER, SOLVER

logger = logging.getLogger(__name__)


@dataclass
class InstanceResult:
    """Result of processing one SWE-bench instance."""
    instance_id: str
    mode: str
    patch: str = ""
    success: bool = False
    duration_s: float = 0.0
    steps: list[dict] = field(default_factory=list)
    error: str = ""


_TEMPLATES = {
    "researcher": RESEARCHER,
    "solver": SOLVER,
    "reviewer": REVIEWER,
}


def _load_prompt_template(name: str) -> str:
    """Load a prompt template by name."""
    return _TEMPLATES[name]


def _render_prompt(template: str, **kwargs) -> str:
    """Simple string format rendering for prompt templates."""
    # Handle optional sections
    if "hints_text" in kwargs:
        hints = kwargs.pop("hints_text", "")
        kwargs["hints_section"] = (
            f"### Hints\n\n{hints}" if hints else ""
        )
    if "research_output" in kwargs:
        research = kwargs.pop("research_output", "")
        kwargs["research_section"] = (
            f"### Research Analysis\n\n{research}" if research else ""
        )
    else:
        kwargs.setdefault("research_section", "")

    # FAIL_TO_PASS test info — key signal for SWE-bench accuracy
    if "fail_to_pass" in kwargs:
        tests_raw = kwargs.pop("fail_to_pass", "[]")
        tests = json.loads(tests_raw) if isinstance(tests_raw, str) else tests_raw
        if tests:
            test_list = "\n".join(f"- `{t}`" for t in tests)
            kwargs["test_info_section"] = (
                f"### Target Tests\n\n"
                f"The following tests currently FAIL and must PASS after your fix:\n\n"
                f"{test_list}\n\n"
                f"Read these test files first to understand the expected behavior."
            )
        else:
            kwargs["test_info_section"] = ""
    else:
        kwargs.setdefault("test_info_section", "")

    kwargs.setdefault("hints_section", "")
    return template.format(**kwargs)


# ── Solo Mode ──────────────────────────────────────────────────────────────

def run_solo_claude(instance: dict, run_id: str) -> InstanceResult:
    """Solo Claude: one agent does everything."""
    return _run_solo(instance, run_id, agent="claude")


def run_solo_codex(instance: dict, run_id: str) -> InstanceResult:
    """Solo Codex: one agent does everything."""
    return _run_solo(instance, run_id, agent="codex")


def _run_solo(instance: dict, run_id: str, agent: str) -> InstanceResult:
    """Generic solo execution: one agent, no research, no review."""
    instance_id = instance["instance_id"]
    result = InstanceResult(instance_id=instance_id, mode=f"solo-{agent}")
    start = time.time()

    try:
        # 1. Setup repo
        repo_dir = repo.ensure_repo_clone(instance["repo"], WORKSPACE_DIR)
        repo.checkout_commit(repo_dir, instance["base_commit"])

        # 2. Build solver prompt (no research section)
        template = _load_prompt_template("solver")
        prompt = _render_prompt(
            template,
            repo=instance["repo"],
            instance_id=instance_id,
            problem_statement=instance["problem_statement"],
            hints_text=instance.get("hints_text", ""),
            fail_to_pass=instance.get("FAIL_TO_PASS", "[]"),
        )

        # 3. Dispatch solver
        if agent == "claude":
            agent_result = agents.dispatch_claude(
                prompt, repo_dir, timeout=SOLVER_TIMEOUT
            )
        elif agent == "codex":
            agent_result = agents.dispatch_codex(
                prompt, repo_dir, timeout=SOLVER_TIMEOUT
            )
        else:
            raise ValueError(f"Unknown solo agent: {agent}")

        result.steps.append({
            "step": "solve",
            "agent": agent_result.agent_name,
            "success": agent_result.success,
            "duration_s": agent_result.duration_s,
        })

        # 4. Collect diff
        patch = repo.collect_diff(repo_dir)
        result.patch = patch
        result.success = bool(patch.strip())

        # 5. Save prediction
        model_name = f"selfmodel-solo-{agent}"
        predictions.write_prediction(
            PREDICTIONS_DIR, run_id, instance_id, model_name, patch
        )

        # 6. Reset repo for next instance
        repo.reset_to_clean(repo_dir, instance["base_commit"])

    except Exception as e:
        logger.error(f"Error processing {instance_id}: {e}")
        result.error = str(e)

    result.duration_s = time.time() - start
    return result


# ── Orchestrated Mode ──────────────────────────────────────────────────────

def run_orchestrated(instance: dict, run_id: str) -> InstanceResult:
    """Orchestrated: Researcher → Solver → Reviewer.

    This is the selfmodel value proposition.
    1. Gemini researches the problem (read-only analysis)
    2. Claude/Codex solves with research context
    3. Gemini reviews the patch independently
    4. If review fails, retry with feedback (max 1 retry)
    """
    instance_id = instance["instance_id"]
    result = InstanceResult(instance_id=instance_id, mode="orchestrated")
    start = time.time()

    try:
        # 1. Setup repo
        repo_dir = repo.ensure_repo_clone(instance["repo"], WORKSPACE_DIR)
        repo.checkout_commit(repo_dir, instance["base_commit"])

        # 2. Research phase (Gemini)
        research_output = _research_phase(instance, repo_dir, result)

        # 3. Solve phase (Claude, enriched with research)
        patch = _solve_phase(instance, repo_dir, research_output, result)

        # 4. Review phase (Gemini, optional retry)
        if patch.strip():
            review_verdict, review_feedback = _review_phase(instance, patch, result)

            # If reviewer says REVISE and we have budget, retry once with feedback
            if review_verdict == "REVISE":
                logger.info(f"Reviewer says REVISE for {instance_id}, retrying with feedback...")
                repo.reset_to_clean(repo_dir, instance["base_commit"])
                retry_hint = (
                    "The previous attempt was reviewed and needs revision.\n\n"
                    f"## Reviewer Feedback\n\n{review_feedback}\n\n"
                    "Address the reviewer's concerns. Focus on correctness and completeness."
                )
                patch = _solve_phase(
                    instance, repo_dir, research_output, result,
                    retry_hint=retry_hint,
                )

        result.patch = patch
        result.success = bool(patch.strip())

        # 5. Save prediction
        predictions.write_prediction(
            PREDICTIONS_DIR, run_id, instance_id, "selfmodel-team", patch
        )

        # 6. Reset repo
        repo.reset_to_clean(repo_dir, instance["base_commit"])

    except Exception as e:
        logger.error(f"Error processing {instance_id}: {e}")
        result.error = str(e)

    result.duration_s = time.time() - start
    return result


def _research_phase(
    instance: dict, repo_dir: Path, result: InstanceResult
) -> str:
    """Gemini research phase: analyze problem, identify relevant files."""
    template = _load_prompt_template("researcher")
    prompt = _render_prompt(
        template,
        repo=instance["repo"],
        instance_id=instance["instance_id"],
        problem_statement=instance["problem_statement"],
        hints_text=instance.get("hints_text", ""),
    )

    # Write prompt to inbox (file buffer pattern)
    agents.write_prompt_file(
        INBOX_DIR, "researcher", instance["instance_id"], prompt
    )

    agent_result = agents.dispatch_gemini(
        prompt, repo_dir, timeout=RESEARCHER_TIMEOUT, model=GEMINI_MODEL
    )

    result.steps.append({
        "step": "research",
        "agent": agent_result.agent_name,
        "success": agent_result.success,
        "duration_s": agent_result.duration_s,
    })

    if agent_result.success:
        logger.info(f"Research complete for {instance['instance_id']}")
        return agent_result.output
    else:
        logger.warning(
            f"Research failed for {instance['instance_id']}: {agent_result.error}"
        )
        return ""  # proceed without research


def _solve_phase(
    instance: dict,
    repo_dir: Path,
    research_output: str,
    result: InstanceResult,
    retry_hint: str = "",
) -> str:
    """Claude solve phase: edit code to fix the issue."""
    template = _load_prompt_template("solver")
    prompt = _render_prompt(
        template,
        repo=instance["repo"],
        instance_id=instance["instance_id"],
        problem_statement=instance["problem_statement"],
        hints_text=instance.get("hints_text", ""),
        research_output=research_output,
        fail_to_pass=instance.get("FAIL_TO_PASS", "[]"),
    )

    if retry_hint:
        prompt += f"\n\n## Retry Note\n\n{retry_hint}\n"

    # Write prompt to inbox
    agents.write_prompt_file(
        INBOX_DIR, "solver", instance["instance_id"], prompt
    )

    agent_result = agents.dispatch_claude(
        prompt, repo_dir, timeout=SOLVER_TIMEOUT
    )

    result.steps.append({
        "step": "solve" if not retry_hint else "solve-retry",
        "agent": agent_result.agent_name,
        "success": agent_result.success,
        "duration_s": agent_result.duration_s,
    })

    if agent_result.success:
        return repo.collect_diff(repo_dir)
    else:
        logger.error(
            f"Solver failed for {instance['instance_id']}: {agent_result.error}"
        )
        return ""


def _review_phase(
    instance: dict, patch: str, result: InstanceResult
) -> tuple[str, str]:
    """Gemini review phase: independent evaluation of the patch.

    Returns: (verdict, feedback_text)
        verdict: "ACCEPT" | "REVISE" | "REJECT"
        feedback_text: reviewer's full output for retry context
    """
    if not patch.strip():
        return "REJECT", "Empty patch."

    template = _load_prompt_template("reviewer")
    prompt = _render_prompt(
        template,
        repo=instance["repo"],
        instance_id=instance["instance_id"],
        problem_statement=instance["problem_statement"],
        patch=patch,
    )

    agent_result = agents.dispatch_gemini(
        prompt, Path("."), timeout=REVIEWER_TIMEOUT, model=GEMINI_MODEL
    )

    result.steps.append({
        "step": "review",
        "agent": agent_result.agent_name,
        "success": agent_result.success,
        "duration_s": agent_result.duration_s,
    })

    if not agent_result.success:
        logger.warning(f"Review failed for {instance['instance_id']}, accepting by default")
        return "ACCEPT", ""

    # Parse verdict from output, preserve full feedback
    feedback = agent_result.output
    output_upper = feedback.upper()
    if "VERDICT: REJECT" in output_upper:
        return "REJECT", feedback
    elif "VERDICT: REVISE" in output_upper:
        return "REVISE", feedback
    else:
        return "ACCEPT", feedback
