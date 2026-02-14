@echo off
REM === BA Agent V5: Claude Code Trigger ===
REM
REM Spawns CC in a visible Windows Terminal window, avoiding the TTY hang bug
REM when Desktop Commander MCP calls execute_command() without a pseudo-terminal.
REM
REM Called from BA skills via:
REM   execute_command('wt -- cmd /c ""{{workspace}}/.ba/scripts/trigger-cc.bat" "{{workspace}}" "{{prompt}}""')
REM
REM Args:
REM   %1 = Workspace path (required, absolute)
REM   %2 = Prompt text (required)

set WORKSPACE=%~1
set PROMPT_TEXT=%~2

if "%WORKSPACE%"=="" (
    echo ERROR: Workspace path required
    echo Usage: trigger-cc.bat "C:\path\to\workspace" "prompt text"
    pause
    exit /b 1
)

if "%PROMPT_TEXT%"=="" (
    echo ERROR: Prompt text required
    echo Usage: trigger-cc.bat "C:\path\to\workspace" "prompt text"
    pause
    exit /b 1
)

REM %~dp0 = directory of this .bat file (portable, no hardcoded paths)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0trigger-cc-runner.ps1" -Workspace "%WORKSPACE%" -PromptText "%PROMPT_TEXT%"
