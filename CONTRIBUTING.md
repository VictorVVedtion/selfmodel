# Contributing to selfmodel

Thank you for your interest in contributing to selfmodel! This document provides guidelines for contributing.

## Development Setup

```bash
git clone https://github.com/VictorVVedtion/selfmodel.git
cd selfmodel && bash install.sh
```

Requires: `jq` (`brew install jq` on macOS, `apt install jq` on Linux)

## How to Contribute

### Reporting Bugs

- Use GitHub Issues with the `bug` label
- Include your OS, shell version, and `jq` version
- Provide the exact command that failed and its output
- Check existing issues before creating a new one

### Suggesting Features

- Use GitHub Issues with the `enhancement` label
- Describe the use case and expected behavior
- Explain how it fits into the existing architecture

### Submitting Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/your-feature`
3. Follow our coding standards (see below)
4. Test your changes locally with `bash scripts/selfmodel.sh status`
5. Commit with conventional commit messages: `feat:`, `fix:`, `docs:`, `refactor:`
6. Submit a Pull Request against `main`

## Coding Standards

selfmodel follows strict quality principles (see `CLAUDE.md` Iron Rules):

- **No TODO comments** — implement completely or don't submit
- **No mock data** — all real data, real paths
- **Proper error handling** — every `try` has a meaningful `catch`
- **Clear naming** — variable and function names read like prose
- **Shell scripts** — use `shellcheck` before submitting

## Project Structure

```
selfmodel/
├── CLAUDE.md              # Operating manual (English)
├── scripts/selfmodel.sh   # CLI entry point
├── scripts/hooks/         # Claude Code enforcement hooks
├── .selfmodel/playbook/   # On-demand loaded protocol files
└── benchmark/             # Evaluation harness
```

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
