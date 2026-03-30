#!/usr/bin/env bash
set -euo pipefail
echo "Removing selfmodel skill..."
rm -rf "${HOME}/.claude/skills/selfmodel"
rm -rf "${HOME}/.claude/commands/selfmodel"
echo "Done."
