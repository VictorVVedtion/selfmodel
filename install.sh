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
BACKUP_DIR="${HOME}/.claude/.backups"
if [[ -d "${SKILL_DIR}" ]] || [[ -d "${CMD_DIR}" ]]; then
    mkdir -p "${BACKUP_DIR}"
fi
if [[ -d "${SKILL_DIR}" ]]; then
    echo "Existing installation found. Backing up..."
    mv "${SKILL_DIR}" "${BACKUP_DIR}/selfmodel.$(date +%s)"
fi
if [[ -d "${CMD_DIR}" ]]; then
    mv "${CMD_DIR}" "${BACKUP_DIR}/selfmodel-commands.$(date +%s)"
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

# Install CLI to PATH
CLI_SRC="${SRC_DIR}/scripts/selfmodel.sh"
CLI_TARGET="/usr/local/bin/selfmodel"
if [[ -f "${CLI_SRC}" ]]; then
    chmod +x "${CLI_SRC}"
    if [[ -w "/usr/local/bin" ]]; then
        ln -sf "${CLI_SRC}" "${CLI_TARGET}"
        echo "CLI: selfmodel → ${CLI_TARGET}"
    elif command -v sudo &>/dev/null; then
        echo "Installing CLI to /usr/local/bin (may need password)..."
        sudo ln -sf "${CLI_SRC}" "${CLI_TARGET}" 2>/dev/null && \
            echo "CLI: selfmodel → ${CLI_TARGET}" || \
            echo "Skipped CLI install (no sudo). Run manually: sudo ln -sf ${CLI_SRC} ${CLI_TARGET}"
    else
        echo "Skipped CLI install. Add to PATH manually:"
        echo "  ln -sf ${CLI_SRC} /usr/local/bin/selfmodel"
    fi
fi

echo ""
echo "Done! ${SKILL_COUNT} skill files + ${CMD_COUNT} commands installed."
echo ""
echo "Commands: /selfmodel:init  /selfmodel:sprint  /selfmodel:review"
echo "          /selfmodel:status  /selfmodel:plan  /selfmodel:loop"
echo ""
echo "CLI:      selfmodel init | update --remote | version | status"
echo ""
echo "Quick start: cd <your-project> && run /selfmodel:init in Claude Code"
