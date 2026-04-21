#!/bin/bash
# Install prerequisites for AgentScript migration (macOS)
# Hosted at: https://gist.githubusercontent.com/shumonsharif/664a87d1bc36dfd95930c48a5ce6a3aa/raw/install-prerequisites.sh
set -e

echo "=== AgentScript Migration — Prerequisites Installer ==="
echo ""

# ---------------------------------------------------------------------------
# 1. GitHub CLI (gh)
# ---------------------------------------------------------------------------
if command -v gh &>/dev/null; then
    echo "[ok] GitHub CLI already installed: $(gh --version | head -1)"
else
    echo "[install] Installing GitHub CLI..."
    if ! command -v brew &>/dev/null; then
        echo "  Homebrew not found — installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install gh
    echo "[ok] GitHub CLI installed: $(gh --version | head -1)"
fi

# ---------------------------------------------------------------------------
# 2. GitHub authentication
# ---------------------------------------------------------------------------
if gh auth status &>/dev/null; then
    echo "[ok] GitHub CLI is authenticated"
else
    echo ""
    echo "--- GitHub authentication required ---"
    echo "A browser window will open so you can sign in to GitHub."
    echo "When prompted, select:  github.com  >  HTTPS  >  Login with a web browser"
    echo ""
    gh auth login --hostname github.com --git-protocol https --web
fi

# Ensure git credential helper is configured for gh
gh auth setup-git

# ---------------------------------------------------------------------------
# 3. Python 3.11+
# ---------------------------------------------------------------------------
check_python_version() {
    if command -v python3 &>/dev/null; then
        PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
        PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
        PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

        if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 11 ]; then
            return 0  # Python 3.11+ found
        fi
    fi
    return 1  # Python 3.11+ not found
}

if check_python_version; then
    echo "[ok] Python already installed: $(python3 --version)"
else
    CURRENT_VERSION=$(python3 --version 2>&1 || echo "not installed")
    echo "[install] Python $CURRENT_VERSION found, but 3.11+ is required. Installing Python 3.11..."

    if ! command -v brew &>/dev/null; then
        echo "  Homebrew not found — installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    brew install python@3.11

    # Add Python 3.11 to PATH
    PYTHON_BIN_PATH="$(brew --prefix python@3.11)/bin"

    # Update PATH in current session
    export PATH="$PYTHON_BIN_PATH:$PATH"

    # Determine shell config file
    SHELL_CONFIG=""
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_CONFIG="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        if [ -f "$HOME/.bash_profile" ]; then
            SHELL_CONFIG="$HOME/.bash_profile"
        else
            SHELL_CONFIG="$HOME/.bashrc"
        fi
    fi

    # Add to shell config if not already present
    if [ -n "$SHELL_CONFIG" ]; then
        if ! grep -q "python@3.11/bin" "$SHELL_CONFIG" 2>/dev/null; then
            echo "" >> "$SHELL_CONFIG"
            echo "# Python 3.11 (added by AgentScript migration installer)" >> "$SHELL_CONFIG"
            echo "export PATH=\"$PYTHON_BIN_PATH:\$PATH\"" >> "$SHELL_CONFIG"
            echo "[ok] Added Python 3.11 to PATH in $SHELL_CONFIG"

            # Source the config file to apply changes immediately
            echo "[ok] Sourcing $SHELL_CONFIG to apply changes immediately..."
            source "$SHELL_CONFIG"
        fi
    fi

    # Verify installation
    if check_python_version; then
        echo "[ok] Python 3.11 installed and configured: $(python3 --version)"
    else
        echo "[warning] Python 3.11 installed but 'python3' command still points to old version."
        echo "         If using 'python3.11' works, create an alias or symlink."
        echo "         Otherwise, restart your terminal."
    fi
fi

# ---------------------------------------------------------------------------
# 4. Node.js
# ---------------------------------------------------------------------------
if command -v node &>/dev/null; then
    echo "[ok] Node.js already installed: $(node --version)"
else
    echo "[install] Installing Node.js..."
    brew install node
    echo "[ok] Node.js installed: $(node --version)"
fi

# ---------------------------------------------------------------------------
# 5. Salesforce CLI (sf)
# ---------------------------------------------------------------------------
if command -v sf &>/dev/null; then
    echo "[ok] Salesforce CLI already installed: $(sf --version | head -1)"
else
    echo "[install] Installing Salesforce CLI..."
    npm install -g @salesforce/cli
    echo "[ok] Salesforce CLI installed: $(sf --version | head -1)"
fi

# ---------------------------------------------------------------------------
# 6. uv (Python package manager)
# ---------------------------------------------------------------------------
if command -v uv &>/dev/null; then
    echo "[ok] uv already installed: $(uv --version)"
else
    echo "[install] Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    echo "[ok] uv installed. You may need to restart your shell or run: source \$HOME/.local/bin/env"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== All prerequisites installed ==="
echo ""

# Verify Python version one final time
if check_python_version; then
    echo "✅ Python version validated: $(python3 --version)"
    echo "✅ All tools are ready to use in this terminal session"
else
    echo "⚠️  Python 3.11 is installed but the 'python3' command may still point to the system version"
    echo "   Try one of the following:"
    echo "   1. Use 'python3.11' explicitly instead of 'python3'"
    echo "   2. Restart your terminal (recommended)"
    echo "   3. Run: source ~/.zshrc (or ~/.bash_profile)"
    echo "   Current python3: $(python3 --version 2>&1 || echo 'not found')"
fi
echo ""