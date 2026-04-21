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
# 3. Python 3.11+
# ---------------------------------------------------------------------------
function Test-PythonVersion {
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $pythonVersion = python --version 2>&1 | Out-String
        if ($pythonVersion -match "Python (\d+)\.(\d+)") {
            $major = [int]$matches[1]
            $minor = [int]$matches[2]
            if ($major -ge 3 -and $minor -ge 11) {
                return $true
            }
        }
    }
    return $false
}

if (Test-PythonVersion) {
    $pythonVersion = python --version 2>&1 | Out-String
    Write-Host "[ok] Python already installed: $pythonVersion" -ForegroundColor Green
} else {
    $currentVersion = "not installed"
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $currentVersion = python --version 2>&1 | Out-String
    }
    Write-Host "[install] Python $currentVersion found, but 3.11+ is required. Installing Python 3.11..." -ForegroundColor Yellow

    winget install Python.Python.3.11 --accept-package-agreements --accept-source-agreements

    # Refresh PATH to include new Python installation
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")

    # Verify installation
    if (Test-PythonVersion) {
        $pythonVersion = python --version 2>&1 | Out-String
        Write-Host "[ok] Python 3.11 installed and configured: $pythonVersion" -ForegroundColor Green
    } else {
        Write-Host "[warning] Python 3.11 installed but 'python' command still points to old version." -ForegroundColor Yellow
        Write-Host "         Please restart your terminal or PowerShell window." -ForegroundColor Yellow
        Write-Host "         Current python: $(python --version 2>&1)" -ForegroundColor Yellow
    }
}
Write-Host ""

# ---------------------------------------------------------------------------
# 4. Node.js
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
# 5. Salesforce CLI (sf)
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
# 6. uv (Python package manager)
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

# Verify Python version one final time
if (Test-PythonVersion) {
    $pythonVersion = python --version 2>&1 | Out-String
    Write-Host "✅ Python version validated: $pythonVersion" -ForegroundColor Green
} else {
    Write-Host "⚠️  Please restart your terminal to use the new Python 3.11 installation" -ForegroundColor Yellow
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $currentVersion = python --version 2>&1 | Out-String
        Write-Host "   Current python: $currentVersion" -ForegroundColor Yellow
    } else {
        Write-Host "   Current python: not found" -ForegroundColor Yellow
    }
}
Write-Host ""