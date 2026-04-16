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
# 3. Node.js
# ---------------------------------------------------------------------------
if command -v node &>/dev/null; then
    echo "[ok] Node.js already installed: $(node --version)"
else
    echo "[install] Installing Node.js..."
    brew install node
    echo "[ok] Node.js installed: $(node --version)"
fi

# ---------------------------------------------------------------------------
# 4. Salesforce CLI (sf)
# ---------------------------------------------------------------------------
if command -v sf &>/dev/null; then
    echo "[ok] Salesforce CLI already installed: $(sf --version | head -1)"
else
    echo "[install] Installing Salesforce CLI..."
    npm install -g @salesforce/cli
    echo "[ok] Salesforce CLI installed: $(sf --version | head -1)"
fi

# ---------------------------------------------------------------------------
# 5. uv (Python package manager)
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