"""
Agent CLI dispatch wrappers.

Each agent type wraps a CLI tool (claude, gemini, codex).
Uses stdin for prompt delivery to avoid ARG_MAX on long problem_statements.
"""
import logging
import os
import subprocess
import time
from pathlib import Path

logger = logging.getLogger(__name__)


class AgentResult:
    """Standardized agent execution result."""

    __slots__ = ("success", "output", "error", "duration_s", "agent_name")

    def __init__(
        self,
        success: bool,
        output: str = "",
        error: str = "",
        duration_s: float = 0.0,
        agent_name: str = "",
    ):
        self.success = success
        self.output = output
        self.error = error
        self.duration_s = duration_s
        self.agent_name = agent_name

    def __repr__(self) -> str:
        status = "OK" if self.success else "FAIL"
        return f"AgentResult({self.agent_name} {status} {self.duration_s:.1f}s)"


def write_prompt_file(inbox_dir: Path, agent: str, instance_id: str, content: str) -> Path:
    """Write prompt to inbox file (file buffer pattern).

    Returns the path to the written file.
    """
    agent_dir = inbox_dir / agent
    agent_dir.mkdir(parents=True, exist_ok=True)
    prompt_file = agent_dir / f"{instance_id}.md"
    prompt_file.write_text(content, encoding="utf-8")
    return prompt_file


def dispatch_claude(
    prompt: str,
    working_dir: Path,
    timeout: int = 600,
    model: str = "opus",
) -> AgentResult:
    """Dispatch to Claude Code CLI.

    Claude CLI can read/write/edit files directly in working_dir.
    Uses -p (print mode) for non-interactive execution.
    Prompt passed as positional arg; stdin used as fallback for very long prompts.

    Flags:
      --dangerously-skip-permissions: no interactive permission prompts
      --allowedTools: restrict to code editing tools only
    Note: --bare is NOT used because it skips OAuth/keychain auth.
    """
    # For prompts > 100KB, use stdin to avoid ARG_MAX
    use_stdin = len(prompt.encode("utf-8")) > 100_000

    cmd = [
        "claude",
        "-p",
        "--model", model,
        "--allowedTools", "Read,Write,Edit,Bash,Glob,Grep",
        "--dangerously-skip-permissions",
    ]

    if not use_stdin:
        cmd.append(prompt)

    logger.info(f"Dispatching Claude ({model}) in {working_dir.name} "
                f"[stdin={use_stdin}, prompt_len={len(prompt)}]")
    start = time.time()

    try:
        result = subprocess.run(
            cmd,
            cwd=working_dir,
            input=prompt if use_stdin else None,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=_agent_env(),
        )
        duration = time.time() - start

        return AgentResult(
            success=result.returncode == 0,
            output=result.stdout,
            error=result.stderr if result.returncode != 0 else "",
            duration_s=duration,
            agent_name=f"claude-{model}",
        )
    except subprocess.TimeoutExpired:
        return AgentResult(
            success=False,
            error=f"Timeout after {timeout}s",
            duration_s=time.time() - start,
            agent_name=f"claude-{model}",
        )


def dispatch_codex(
    prompt: str,
    working_dir: Path,
    timeout: int = 600,
) -> AgentResult:
    """Dispatch to Codex CLI.

    Codex exec runs non-interactively with file write access.
    Uses stdin for long prompts (codex exec reads from stdin when prompt is '-').
    """
    use_stdin = len(prompt.encode("utf-8")) > 100_000

    if use_stdin:
        cmd = ["codex", "exec", "-"]
    else:
        cmd = ["codex", "exec", prompt]

    logger.info(f"Dispatching Codex in {working_dir.name} "
                f"[stdin={use_stdin}, prompt_len={len(prompt)}]")
    start = time.time()

    try:
        result = subprocess.run(
            cmd,
            cwd=working_dir,
            input=prompt if use_stdin else None,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=_agent_env(),
        )
        duration = time.time() - start

        return AgentResult(
            success=result.returncode == 0,
            output=result.stdout,
            error=result.stderr if result.returncode != 0 else "",
            duration_s=duration,
            agent_name="codex",
        )
    except subprocess.TimeoutExpired:
        return AgentResult(
            success=False,
            error=f"Timeout after {timeout}s",
            duration_s=time.time() - start,
            agent_name="codex",
        )


def dispatch_gemini(
    prompt: str,
    working_dir: Path,
    timeout: int = 180,
    model: str = "gemini-2.5-pro",
) -> AgentResult:
    """Dispatch to Gemini CLI.

    Used for research (read-only) and review phases.
    -p: non-interactive print mode
    -y: yolo mode (auto-approve all tool calls)

    Gemini -p takes the prompt as its string value.
    For very long prompts, stdin is piped.
    """
    use_stdin = len(prompt.encode("utf-8")) > 100_000

    if use_stdin:
        cmd = ["gemini", "-p", "", "-m", model, "-y"]
    else:
        cmd = ["gemini", "-p", prompt, "-m", model, "-y"]

    logger.info(f"Dispatching Gemini ({model}) in {working_dir.name} "
                f"[stdin={use_stdin}, prompt_len={len(prompt)}]")
    start = time.time()

    try:
        result = subprocess.run(
            cmd,
            cwd=working_dir,
            input=prompt if use_stdin else None,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=_agent_env(),
        )
        duration = time.time() - start

        return AgentResult(
            success=result.returncode == 0,
            output=result.stdout,
            error=result.stderr if result.returncode != 0 else "",
            duration_s=duration,
            agent_name=f"gemini-{model}",
        )
    except subprocess.TimeoutExpired:
        return AgentResult(
            success=False,
            error=f"Timeout after {timeout}s",
            duration_s=time.time() - start,
            agent_name=f"gemini-{model}",
        )


def _agent_env() -> dict:
    """Build environment for agent subprocesses.

    Inherits current env, adds CI=true to suppress interactive prompts.
    """
    env = os.environ.copy()
    env["CI"] = "true"
    env["NONINTERACTIVE"] = "1"
    return env
