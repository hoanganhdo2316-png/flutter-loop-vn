#Requires -Version 5.1
<#
.SYNOPSIS
    Installs the flutter-loop-vn Claude Code skill to %USERPROFILE%\.claude\skills\
.DESCRIPTION
    Run with: powershell -ExecutionPolicy Bypass -File install.ps1
    Or right-click the file and choose "Run with PowerShell"
#>

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "`n$Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [WARN] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
}

function Ask-Continue {
    param([string]$Question)
    $answer = Read-Host "$Question [y/N]"
    return $answer -match '^[Yy]'
}

try {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor White
    Write-Host "  flutter-loop-vn — Skill Installer" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor White

    # ── Step 1: Check Claude Code ─────────────────────────────────────────────
    Write-Step "Step 1/6 — Checking Claude Code..."
    $claudeOk = $false
    try {
        $null = & claude --version 2>&1
        if ($LASTEXITCODE -eq 0 -or $?) {
            $claudeOk = $true
            Write-Ok "Claude Code is installed."
        }
    } catch {}

    if (-not $claudeOk) {
        Write-Fail "Claude Code not found."
        Write-Host "  Download it from: https://claude.ai/download" -ForegroundColor Yellow
        if (-not (Ask-Continue "Claude Code is not installed. Continue anyway?")) {
            Write-Host "Installation cancelled. Install Claude Code first, then re-run this script." -ForegroundColor Yellow
            exit 1
        }
        Write-Warn "Continuing without Claude Code — the skill will not work until it is installed."
    }

    # ── Step 2: Check Git Bash ────────────────────────────────────────────────
    Write-Step "Step 2/6 — Checking Git Bash..."
    $bashOk = $false
    try {
        $null = & bash --version 2>&1
        if ($LASTEXITCODE -eq 0 -or $?) {
            $bashOk = $true
            Write-Ok "Git Bash (bash) is available."
        }
    } catch {}

    if (-not $bashOk) {
        Write-Fail "Git Bash not found."
        Write-Host "  Git Bash is REQUIRED — all .sh scripts in this skill need bash to run." -ForegroundColor Red
        Write-Host "  Download Git for Windows (includes Git Bash): https://git-scm.com/download/win" -ForegroundColor Yellow
        if (-not (Ask-Continue "Git Bash is not installed. Continue anyway?")) {
            Write-Host "Installation cancelled. Install Git for Windows first, then re-run this script." -ForegroundColor Yellow
            exit 1
        }
        Write-Warn "Continuing without Git Bash — scripts will fail until bash is available in PATH."
    }

    # ── Step 3: Remove old installs ───────────────────────────────────────────
    Write-Step "Step 3/6 — Removing old skill installs (if any)..."
    $skillsRoot = "$env:USERPROFILE\.claude\skills"
    $oldNames = @("flutter-android-loop", "flutter-loop-vn")

    foreach ($name in $oldNames) {
        $oldPath = Join-Path $skillsRoot $name
        if (Test-Path $oldPath) {
            Remove-Item -Recurse -Force $oldPath
            Write-Ok "Removed existing install: $oldPath"
        }
    }

    # ── Step 4: Create destination directories ────────────────────────────────
    Write-Step "Step 4/6 — Creating skill directory..."
    $destRoot    = Join-Path $skillsRoot "flutter-loop-vn"
    $destScripts = Join-Path $destRoot "scripts"

    New-Item -ItemType Directory -Force $destScripts | Out-Null
    Write-Ok "Created: $destRoot"
    Write-Ok "Created: $destScripts"

    # ── Step 5: Copy files ────────────────────────────────────────────────────
    Write-Step "Step 5/6 — Copying skill files..."
    $sourceRoot    = $PSScriptRoot
    $sourceScripts = Join-Path $sourceRoot "scripts"

    $filesToCopy = @(
        @{ Src = Join-Path $sourceRoot "SKILL.md";  Dst = Join-Path $destRoot "SKILL.md"  },
        @{ Src = Join-Path $sourceRoot "README.md"; Dst = Join-Path $destRoot "README.md" }
    )

    $scriptFiles = Get-ChildItem -Path $sourceScripts -File -ErrorAction SilentlyContinue
    foreach ($f in $scriptFiles) {
        $filesToCopy += @{ Src = $f.FullName; Dst = Join-Path $destScripts $f.Name }
    }

    $copiedCount = 0
    foreach ($pair in $filesToCopy) {
        Copy-Item -Path $pair.Src -Destination $pair.Dst -Force
        Write-Ok "Copied: $($pair.Dst)"
        $copiedCount++
    }

    # ── Step 6: Verify ────────────────────────────────────────────────────────
    Write-Step "Step 6/6 — Verifying installation..."
    $installed = Get-ChildItem -Recurse $destRoot -File
    Write-Host ""
    Write-Host "  Installed $($installed.Count) file(s):" -ForegroundColor White
    foreach ($f in $installed) {
        Write-Host "    $($f.FullName.Replace($destRoot, '').TrimStart('\/'))" -ForegroundColor Gray
    }

    if ($installed.Count -ne $copiedCount) {
        Write-Warn "Expected $copiedCount files but found $($installed.Count) after copy. Check the output above."
    } else {
        Write-Ok "All $copiedCount files verified."
    }

    # ── Done ──────────────────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "  Installation complete!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor White
    Write-Host "  1. Open Claude Code in your Flutter project directory" -ForegroundColor Gray
    Write-Host "  2. Type /flutter-loop-vn to get started" -ForegroundColor Gray
    Write-Host "  3. Example: /flutter-loop-vn Add Zalo OAuth login screen" -ForegroundColor Gray
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host "  Installation failed" -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host ""
    Write-Fail "Error: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "What failed: $($_.InvocationInfo.PositionMessage)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Suggestions:" -ForegroundColor White
    Write-Host "  - Run PowerShell as Administrator if you see permission errors" -ForegroundColor Gray
    Write-Host "  - Make sure the scripts\ folder exists next to install.ps1" -ForegroundColor Gray
    Write-Host "  - Check that %USERPROFILE%\.claude\skills\ is writable" -ForegroundColor Gray
    Write-Host ""
    exit 1
}
