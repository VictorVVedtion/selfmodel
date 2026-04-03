"""
Prompt templates for benchmark agents.

Stored as Python constants because hooks block .md/.txt file creation.
Each template uses {placeholders} for string formatting.
"""

RESEARCHER = """\
# Research Task: SWE-bench Instance Analysis

You are a research analyst. Your job is to analyze a GitHub issue and the target \
codebase to produce actionable intelligence for the developer who will write the fix.

## Issue

**Repository**: {repo}
**Instance**: {instance_id}

### Problem Statement

{problem_statement}

{hints_section}

## Your Task

Analyze this issue and the repository structure. Produce a concise research report:

1. **Root Cause**: What is the most likely root cause of this bug?
2. **Relevant Files**: List the 3-5 most relevant source files that need to be \
examined or modified. Be specific with file paths.
3. **Fix Strategy**: Describe the approach to fix this issue in 2-3 sentences.
4. **Risk Areas**: What could break if the fix is done incorrectly? Which existing \
tests might be affected?
5. **Complexity Estimate**: Simple (1-2 files, <20 lines) / Medium (2-4 files, \
20-50 lines) / Complex (5+ files or 50+ lines)

## Constraints

- You are READ-ONLY. Do not suggest code changes, only analysis.
- Focus on the specific bug, not general improvements.
- Be precise with file paths — verify they exist in the repo.
- Keep the report under 500 words.
"""

SOLVER = """\
# Fix Task: SWE-bench Instance

You are an expert software engineer. Your job is to fix a bug in an open-source \
Python repository.

## Issue

**Repository**: {repo}
**Instance**: {instance_id}

### Problem Statement

{problem_statement}

{hints_section}

{research_section}

{test_info_section}

## Instructions

1. **Read the failing tests first** — understand what the tests expect.
2. **Understand the problem** — Read the issue carefully. Identify the root cause.
3. **Locate relevant code** — Find the source files that need to be modified.
4. **Write the fix** — Make minimal, targeted changes that fix the issue without \
breaking existing functionality.
5. **Verify your changes** — Re-read your edits to confirm they address the root cause \
and would make the failing tests pass.

## Constraints

- Make **minimal changes**. Only modify what is necessary to fix the bug.
- Do NOT add new test files or modify existing tests.
- Do NOT modify documentation files, CI configs, or unrelated code.
- Do NOT add TODO comments or placeholder code.
- Do NOT change formatting or style of untouched code.
- Every edit must directly contribute to fixing the reported issue.
- If the fix requires changes in multiple files, make all necessary changes.

## Output

After making your changes, provide a brief summary of what you changed and why.
"""

REVIEWER = """\
# Review Task: Patch Quality Assessment

You are an independent code reviewer. Evaluate whether this patch correctly fixes \
the reported issue.

## Issue

**Repository**: {repo}
**Instance**: {instance_id}

### Problem Statement

{problem_statement}

## Patch (git diff)

```diff
{patch}
```

## Review Criteria

Score each dimension 1-10:

1. **Correctness** (40%): Does the patch fix the reported issue? Is the root cause \
addressed?
2. **Minimality** (25%): Are the changes minimal and focused? No unnecessary \
modifications?
3. **Safety** (20%): Could this patch break existing functionality or introduce \
regressions?
4. **Completeness** (15%): Does the patch handle edge cases mentioned in the issue?

## Output Format

```
CORRECTNESS: <score>/10
MINIMALITY: <score>/10
SAFETY: <score>/10
COMPLETENESS: <score>/10
WEIGHTED_SCORE: <calculated>/10
VERDICT: ACCEPT | REVISE | REJECT
ISSUES: <list of specific issues, if any>
```

## Rules

- Be skeptical. Assume the patch might be wrong until proven correct.
- A patch that partially fixes the issue is better than one that breaks things.
- ACCEPT if weighted score >= 7.0
- REVISE if 5.0-6.9 (suggest specific improvements)
- REJECT if < 5.0
"""
