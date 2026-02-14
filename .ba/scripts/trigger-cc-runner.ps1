param(
    [Parameter(Mandatory=$true)]
    [string]$Workspace
)

$Workspace = $Workspace.Trim('"').Trim("'")

# --- Auto-detect Claude Code CLI ---
$claudePath = $null

# 1. Check PATH
$pathResult = Get-Command "claude" -ErrorAction SilentlyContinue
if ($pathResult) {
    $claudePath = $pathResult.Source
}

# 2. Fallback: known install locations
if (-not $claudePath) {
    $knownPaths = @(
        "$env:USERPROFILE\.local\bin\claude.exe",
        "$env:LOCALAPPDATA\Programs\claude\claude.exe"
    )
    foreach ($p in $knownPaths) {
        if (Test-Path $p) {
            $claudePath = $p
            break
        }
    }
}

# --- Validate ---
if (-not $claudePath) {
    Write-Host "ERROR: Claude Code CLI not found." -ForegroundColor Red
    Write-Host "  Checked: PATH, ~/.local/bin/, LocalAppData" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

if (-not (Test-Path $Workspace)) {
    Write-Host "ERROR: Workspace not found: $Workspace" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Set-Location $Workspace

# --- Read prompt from file (avoids cmd.exe quote-stripping) ---
$promptFile = Join-Path $Workspace ".ba/triggers/.cc-prompt"

if (-not (Test-Path $promptFile)) {
    Write-Host "ERROR: Prompt file not found: $promptFile" -ForegroundColor Red
    Write-Host "  BA skill must write_file() the prompt before triggering." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$PromptText = (Get-Content $promptFile -Raw).Trim()
Remove-Item $promptFile -Force

if ([string]::IsNullOrWhiteSpace($PromptText)) {
    Write-Host "ERROR: Prompt file was empty." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# --- Header ---
Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "  BA Agent V5 - Claude Code Trigger" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "  Workspace : $Workspace" -ForegroundColor Gray
Write-Host "  Claude    : $claudePath" -ForegroundColor Gray
Write-Host "  Prompt    : $PromptText" -ForegroundColor Gray
Write-Host "  Started   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host ""

# --- Step 1: Auto-execute prompt via pipe (prevents TTY hang) ---
Write-Host "[Step 1] Running prompt via pipe..." -ForegroundColor Yellow
Write-Host "---" -ForegroundColor DarkGray

$startTime = Get-Date

$result = $PromptText | & $claudePath -p --output-format text --dangerously-skip-permissions 2>&1
$exitCode = $LASTEXITCODE

Write-Host $result

$elapsed = (Get-Date) - $startTime
Write-Host ""
Write-Host "---" -ForegroundColor DarkGray
Write-Host "[Step 1 Complete] Exit: $exitCode | Duration: $($elapsed.ToString('mm\:ss'))" -ForegroundColor Yellow
Write-Host ""

# --- Step 2: Continue in interactive mode ---
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "[Step 2] Opening interactive session..." -ForegroundColor Green
Write-Host "  You can now type commands or Ctrl+C to exit" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host ""

& $claudePath --continue --dangerously-skip-permissions

Write-Host ""
Write-Host "========================================" -ForegroundColor DarkCyan
Write-Host "  Session ended at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor DarkCyan
Read-Host "Press Enter to close"
