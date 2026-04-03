# 🌊 Rampage Report: selfmodel

| Field | Value |
|-------|-------|
| **Date** | 2026-04-03 |
| **Surfaces** | ⌨️ CLI |
| **Duration** | ~4m |
| **Intensity** | standard |
| **Personas** | all 7 |

---

## Overall Resilience: 72/100 ⚠️

```
████████░░  72
```

**Verdict**: PASS_WITH_CONCERNS

---

## ⌨️ CLI Surface — `selfmodel.sh` v0.2.0

**Score**: 72/100
**Command Coverage**: 100% (5/5 subcommands + 2 scripts)

| Dimension | Score | Bar |
|-----------|-------|-----|
| Arguments | 59 | ██████░░░░ |
| Input (stdin) | 100 | ██████████ |
| Signals | 100 | ██████████ |
| Environment | 95 | ██████████ |
| Concurrency | 100 | ██████████ |
| Error quality | 44 | ████░░░░░░ |

---

### Findings

#### RAMPAGE-001: `--help` flag crashes `adapt` and is ignored on all subcommands 🟠

| Field | Value |
|-------|-------|
| **Severity** | High |
| **Persona** | 😵 Confused |
| **Journey** | New user tries `selfmodel init --help` |
| **Chaos behavior** | C-ARG-02: unknown flag |
| **Dimension** | Arguments |

**What happened:**
- `selfmodel init --help` treats `--help` as a directory name, prints "Initializing selfmodel in --help", then prompts for project type
- `selfmodel adapt --help` treats `--help` as directory, then crashes: `mkdir: unrecognized option '--help/.selfmodel/contracts/active'`
- `selfmodel update --help` treats `--help` as directory, errors "No .selfmodel/ found"
- No subcommand supports `--help` or `-h`

**Expected:**
Each subcommand should display its own help text when called with `--help`.

---

#### RAMPAGE-002: `adapt` silently proceeds on non-existent directory, exit 0 🟠

| Field | Value |
|-------|-------|
| **Severity** | High |
| **Persona** | 😵 Confused |
| **Journey** | User runs `selfmodel adapt /nonexistent/path` |
| **Chaos behavior** | C-FIL-01: non-existent path |
| **Dimension** | Arguments |

**What happened:**
`selfmodel adapt /nonexistent/path` detects "unknown" project type (all false), then proceeds to create `.selfmodel/` structure inside a non-existent path. Exit code: 0.

**Expected:**
Should validate the directory exists before proceeding. Exit 1 with clear error message.

---

#### RAMPAGE-003: `init` accepts a file path as directory argument 🟠

| Field | Value |
|-------|-------|
| **Severity** | High |
| **Persona** | 😵 Confused |
| **Journey** | User runs `selfmodel init /tmp/some-file` |
| **Chaos behavior** | C-FIL-02: directory as file |
| **Dimension** | Arguments |

**What happened:**
`selfmodel init /tmp/rampage-file` (where the path is a regular file, not a directory) starts the interactive setup without error. Would create `.selfmodel/` subdirectory under a file path.

**Expected:**
Should check if path is a file and error: "Path is a file, not a directory."

---

#### RAMPAGE-004: `install.sh` backup creates skill namespace pollution 🟠

| Field | Value |
|-------|-------|
| **Severity** | High |
| **Persona** | 🔍 Explorer |
| **Journey** | User uninstalls then reinstalls selfmodel |
| **Chaos behavior** | L-LIF-04: double close / reinstall cycle |
| **Dimension** | Error quality |

**What happened:**
Running `uninstall.sh` then `install.sh` creates a backup directory `~/.claude/skills/selfmodel.bak.{timestamp}`. Claude Code interprets this backup directory as a SEPARATE SKILL, registering `selfmodel.bak.1775245579` with 6 sub-commands (`:init`, `:sprint`, etc.). This pollutes the skill namespace with ghost commands.

**Evidence:**
System recognized: `selfmodel.bak.1775245579:init`, `selfmodel.bak.1775245579:sprint`, etc.

**Expected:**
Backup should be stored outside `~/.claude/skills/` (e.g., `~/.claude/.backups/`), or `install.sh` should clean up backups after successful install.

---

#### RAMPAGE-005: `adapt --help` crashes but exits 0 ⚠️

| Field | Value |
|-------|-------|
| **Severity** | Medium |
| **Persona** | 😵 Confused |
| **Journey** | Same as RAMPAGE-001 |
| **Chaos behavior** | C-ARG-02: unknown flag |
| **Dimension** | Error quality |

**What happened:**
`adapt --help` causes `mkdir: unrecognized option` error, but the script exits with code 0 (success). Shell scripts with `set -e` should propagate the error.

**Expected:**
Exit code should be non-zero when `mkdir` fails.

---

#### RAMPAGE-006: `update --version` silently ignored without `--remote` ⚠️

| Field | Value |
|-------|-------|
| **Severity** | Medium |
| **Persona** | 😵 Confused |
| **Journey** | User runs `selfmodel update --version v1.0` |
| **Chaos behavior** | C-ARG-10: conflicting/irrelevant flags |
| **Dimension** | Error quality |

**What happened:**
`selfmodel update --version '$(whoami)'` completes successfully, updating from local templates. The `--version` flag is completely ignored without warning. Also, `--version` with command injection string is handled safely (no injection), but the flag should either work or warn.

**Expected:**
Either: (a) warn "—version requires —remote", or (b) use `--version` for local template versioning too.

---

#### RAMPAGE-007: Unknown command exits 1 but missing `set -e` in some paths 🟡

| Field | Value |
|-------|-------|
| **Severity** | Low |
| **Persona** | 🔍 Explorer |
| **Journey** | User types wrong subcommand |
| **Chaos behavior** | C-ARG-02: unknown flag |
| **Dimension** | Error quality |

**What happened:**
`selfmodel foobar` correctly prints "Unknown command: foobar" and exits 1.  But the error message says `Run 'selfmodel help' for usage` — the `help` subcommand doesn't exist (it's just no-args).

**Expected:**
Say `Run 'selfmodel' for usage` or add a `help` subcommand.

---

### Resilience Highlights (Things That Worked)

| Test | Persona | Result |
|------|---------|--------|
| Binary stdin to `init` | 💥 Edge Case | Handled: "Invalid choice", exit 0 |
| Emoji directory path | 💥 Edge Case | Accepted without crash |
| Spaces in path | 💥 Edge Case | Accepted without crash |
| Very long path (200 chars) | 💥 Edge Case | Accepted without crash |
| Ctrl+C during `init` | 🚪 Abandoner | Clean exit, no leftover files |
| Double `init` same dir | ⚡ Impatient | Correctly rejected: "already exists" |
| 5 concurrent `status` | 🔀 Multitasker | All succeeded without issues |
| Empty HOME | 💥 Edge Case | `status` works fine |
| Command injection `$(...)` | 💥 Edge Case | No injection, treated as literal string |
| SQL injection in arg | 💥 Edge Case | No injection, treated as literal string |
| Double uninstall | 🔍 Explorer | Idempotent, no error |

---

## Findings by Persona

| Persona | Findings | Most Common Dimension |
|---------|----------|----------------------|
| ⚡ Impatient | 0 | — |
| 😵 Confused | 5 | Arguments |
| 🔍 Explorer | 2 | Error quality |
| 🔀 Multitasker | 0 | — |
| 💥 Edge Case | 0 | — |
| 🚪 Abandoner | 0 | — |
| 🏃 Speedrunner | 0 | — |

**Pattern**: The Confused persona found ALL the argument validation issues. The CLI assumes users know what they're doing. Edge cases and concurrent access are handled well.

---

## Dead Ends

| Location | Issue |
|----------|-------|
| `selfmodel init` interactive prompt | If stdin is closed, prints "Project type [1-4]:" and hangs forever (no timeout). Non-interactive CI context would stall. |
| `selfmodel foobar` error message | Says "Run 'selfmodel help'" but `help` subcommand doesn't exist |

---

## Summary

| Severity | Count |
|----------|-------|
| 🔴 Critical | 0 |
| 🟠 High | 4 |
| ⚠️ Medium | 2 |
| 🟡 Low | 1 |
| **Total** | **7** |

### Recommended Action

⚠️ Good foundation, but fix the high-severity items before shipping. The main theme: **argument validation is too permissive**. The CLI trusts user input too much — `--help` as a directory name, files as directories, non-existent paths accepted silently. The install.sh backup pollution is a separate but real issue for users who upgrade.

Priorities:
1. Add `--help` / `-h` support to all subcommands
2. Validate directory paths exist and are directories
3. Move install.sh backups outside `~/.claude/skills/`
4. Exit non-zero on `mkdir` failures
