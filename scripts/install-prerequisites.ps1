# Install prerequisites for AgentScript migration (Windows)
# Run as: powershell -ExecutionPolicy ByPass -c "irm <gist-url> | iex"
# Hosted at: https://gist.githubusercontent.com/shumonsharif/289892cec4d24cdcfdb89464f0c89858/raw/install-prerequisites.ps1

Write-Host "=== AgentScript Migration — Prerequisites Installer (Windows) ===" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# 1. GitHub CLI (gh)
# ---------------------------------------------------------------------------
if (Get-Command gh -ErrorAction SilentlyContinue) {
    Write-Host "[ok] GitHub CLI already installed: $(gh --version | Select-Object -First 1)" -ForegroundColor Green
} else {
    Write-Host "[install] Installing GitHub CLI via winget..." -ForegroundColor Yellow
    winget install GitHub.cli --accept-package-agreements --accept-source-agreements
    # Refresh PATH so gh is available in the current session
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: GitHub CLI installed but not found in PATH. Please restart your terminal and re-run this script." -ForegroundColor Red
        exit 1
    }
    Write-Host "[ok] GitHub CLI installed: $(gh --version | Select-Object -First 1)" -ForegroundColor Green
}
Write-Host ""

# ---------------------------------------------------------------------------
# 2. GitHub authentication
# ---------------------------------------------------------------------------
$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[ok] GitHub CLI is authenticated" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "--- GitHub authentication required ---" -ForegroundColor Yellow
    Write-Host "A browser window will open so you can sign in to GitHub."
    Write-Host "When prompted, select:  github.com  >  HTTPS  >  Login with a web browser"
    Write-Host ""
    gh auth login --hostname github.com --git-protocol https --web
}

# Ensure git credential helper is configured for gh
gh auth setup-git
Write-Host ""

# ---------------------------------------------------------------------------
# 3. Node.js
# ---------------------------------------------------------------------------
if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Host "[ok] Node.js already installed: $(node --version)" -ForegroundColor Green
} else {
    Write-Host "[install] Installing Node.js LTS via winget..." -ForegroundColor Yellow
    winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    Write-Host "[ok] Node.js installed: $(node --version)" -ForegroundColor Green
}
Write-Host ""

# ---------------------------------------------------------------------------
# 4. Salesforce CLI (sf)
# ---------------------------------------------------------------------------
if (Get-Command sf -ErrorAction SilentlyContinue) {
    Write-Host "[ok] Salesforce CLI already installed: $(sf --version | Select-Object -First 1)" -ForegroundColor Green
} else {
    Write-Host "[install] Installing Salesforce CLI..." -ForegroundColor Yellow
    npm install -g @salesforce/cli
    Write-Host "[ok] Salesforce CLI installed: $(sf --version | Select-Object -First 1)" -ForegroundColor Green
}
Write-Host ""

# ---------------------------------------------------------------------------
# 5. uv (Python package manager)
# ---------------------------------------------------------------------------
if (Get-Command uv -ErrorAction SilentlyContinue) {
    Write-Host "[ok] uv already installed: $(uv --version)" -ForegroundColor Green
} else {
    Write-Host "[install] Installing uv..." -ForegroundColor Yellow
    irm https://astral.sh/uv/install.ps1 | iex
    Write-Host "[ok] uv installed. You may need to restart your shell." -ForegroundColor Green
}
Write-Host ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "=== All prerequisites installed ===" -ForegroundColor Cyan
Write-Host ""