#!/usr/bin/env bash
# selfmodel skill installer
# Usage: git clone <repo> && cd selfmodel && bash install.sh
set -euo pipefail

SKILL_DIR="${HOME}/.claude/skills/selfmodel"
CMD_DIR="${HOME}/.claude/commands/selfmodel"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "selfmodel skill installer"
echo "========================="

# Check prerequisites
if [[ ! -d "${HOME}/.claude" ]]; then
    echo "Error: ~/.claude/ not found. Is Claude Code installed?"
    exit 1
fi

if [[ ! -d "${SRC_DIR}/skill" ]]; then
    echo "Error: skill/ directory not found. Run from the selfmodel repo root."
    exit 1
fi

# Backup existing
if [[ -d "${SKILL_DIR}" ]]; then
    echo "Existing installation found. Backing up..."
    mv "${SKILL_DIR}" "${SKILL_DIR}.bak.$(date +%s)"
fi
if [[ -d "${CMD_DIR}" ]]; then
    mv "${CMD_DIR}" "${CMD_DIR}.bak.$(date +%s)"
fi

# Install
echo "Installing skill..."
mkdir -p "${SKILL_DIR}"
cp -r "${SRC_DIR}/skill/"* "${SKILL_DIR}/"

echo "Installing commands..."
mkdir -p "${CMD_DIR}"
cp -r "${SRC_DIR}/commands/"* "${CMD_DIR}/"

chmod +x "${SKILL_DIR}/scripts/"*.sh 2>/dev/null || true

# Verify
SKILL_COUNT=$(find "${SKILL_DIR}" -type f | wc -l | tr -d ' ')
CMD_COUNT=$(find "${CMD_DIR}" -type f | wc -l | tr -d ' ')

echo ""
echo "Done! ${SKILL_COUNT} skill files + ${CMD_COUNT} commands installed."
echo ""
echo "Commands: /selfmodel:init  /selfmodel:sprint  /selfmodel:review"
echo "          /selfmodel:status  /selfmodel:plan  /selfmodel:loop"
echo ""
echo "Quick start: cd <your-project> && run /selfmodel:init in Claude Code"
