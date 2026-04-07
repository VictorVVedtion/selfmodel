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
# Strategy: try /usr/local/bin first, fallback to ~/.local/bin (no sudo needed)
CLI_SRC="${SRC_DIR}/scripts/selfmodel.sh"
CLI_INSTALLED=false
if [[ -f "${CLI_SRC}" ]]; then
    chmod +x "${CLI_SRC}"

    # Try 1: /usr/local/bin (system-wide, may need sudo)
    if [[ -w "/usr/local/bin" ]]; then
        ln -sf "${CLI_SRC}" "/usr/local/bin/selfmodel"
        echo "CLI: selfmodel → /usr/local/bin/selfmodel"
        CLI_INSTALLED=true
    elif command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
        # sudo available without password prompt (e.g. NOPASSWD configured)
        sudo ln -sf "${CLI_SRC}" "/usr/local/bin/selfmodel"
        echo "CLI: selfmodel → /usr/local/bin/selfmodel"
        CLI_INSTALLED=true
    fi

    # Try 2: ~/.local/bin (user-local, no sudo needed)
    if [[ "$CLI_INSTALLED" == "false" ]]; then
        LOCAL_BIN="${HOME}/.local/bin"
        mkdir -p "${LOCAL_BIN}"
        ln -sf "${CLI_SRC}" "${LOCAL_BIN}/selfmodel"
        echo "CLI: selfmodel → ${LOCAL_BIN}/selfmodel"
        CLI_INSTALLED=true

        # Ensure ~/.local/bin is in PATH
        if ! echo "$PATH" | tr ':' '\n' | grep -q "^${LOCAL_BIN}$"; then
            # Detect shell and add to appropriate rc file
            SHELL_RC=""
            if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$(basename "${SHELL:-}")" == "zsh" ]]; then
                SHELL_RC="${HOME}/.zshrc"
            elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$(basename "${SHELL:-}")" == "bash" ]]; then
                SHELL_RC="${HOME}/.bashrc"
            fi

            if [[ -n "$SHELL_RC" ]]; then
                if ! grep -q '\.local/bin' "$SHELL_RC" 2>/dev/null; then
                    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
                    echo "  Added ~/.local/bin to PATH in $(basename "$SHELL_RC")"
                    echo "  Run: source $SHELL_RC   (or open a new terminal)"
                fi
            else
                echo "  Add to your shell profile: export PATH=\"\$HOME/.local/bin:\$PATH\""
            fi
        fi
    fi
fi

echo ""
echo "Done! ${SKILL_COUNT} skill files + ${CMD_COUNT} commands installed."
echo ""
echo "Quick start:"
echo "  cd your-project && selfmodel init"
echo ""
echo "Terminal:  selfmodel              (dashboard)"
echo "           selfmodel init         (setup)"
echo "           selfmodel update       (sync)"
echo ""
echo "Claude Code:  /selfmodel:loop     (orchestrate)"
