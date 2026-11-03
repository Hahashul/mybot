<#
  Removes local mybot / OpenBot data from this PC so you can test a fresh setup.

  It first LISTS everything it would delete and waits for you to type DELETE.
  Nothing is removed before that.

  Removed by default:
    - Dev app data in %APPDATA%\OpenBot Dev*   (database openbot.db, logs, browser profile)
    - %LOCALAPPDATA%\OpenBot\openbot-dev-instances
    - Project folders: node_modules, apps\auth-api\.wrangler, out-dev-app
    - Bun itself in %USERPROFILE%\.bun (setup.ps1 installs it again)

  Never touched:
    - Node.js and Git
    - Your project source code and git history
    - %USERPROFILE%\.claude and %USERPROFILE%\.codex (your CLI logins)

  Options:
    -IncludeWorkspaces  Also delete %USERPROFILE%\OpenBot (agent workspaces and file transfers).
    -KeepBun            Do not delete Bun.
    -Yes                Skip the DELETE prompt.

  Run it from the project folder, with the app closed.
#>
[CmdletBinding()]
param(
  [switch]$IncludeWorkspaces,
  [switch]$KeepBun,
  [switch]$Yes
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

if (-not (Test-Path (Join-Path $ProjectRoot "package.json"))) {
  throw "Run this script from the project folder (the one that has package.json)."
}

# 1. The app must be closed ---------------------------------------------------
$running = Get-Process -ErrorAction SilentlyContinue | Where-Object {
  $_.ProcessName -match '^(electron|openbot|bun)$'
}
if ($running) {
  $names = ($running | Select-Object -ExpandProperty ProcessName -Unique) -join ", "
  Write-Host "These programs are still running: $names" -ForegroundColor Red
  Write-Host "Close the OpenBot window, press Ctrl+C in the terminal that runs it, then run this script again." -ForegroundColor Red
  throw "App is still running."
}

# 2. Build the list of targets ------------------------------------------------
$targets = New-Object System.Collections.Generic.List[object]

function Add-Target([string]$Path, [string]$Why) {
  if (Test-Path -LiteralPath $Path) {
    $targets.Add([pscustomobject]@{ Path = $Path; Why = $Why })
  }
}

if ($env:APPDATA) {
  Get-ChildItem -LiteralPath $env:APPDATA -Directory -Filter "OpenBot Dev*" -ErrorAction SilentlyContinue |
    ForEach-Object { Add-Target $_.FullName "Dev app data (database, logs, browser profile)" }
}
if ($env:LOCALAPPDATA) {
  Add-Target (Join-Path $env:LOCALAPPDATA "OpenBot\openbot-dev-instances") "Dev instance records"
}

Add-Target (Join-Path $ProjectRoot "node_modules") "Installed packages"
foreach ($group in @("apps", "packages")) {
  $groupDir = Join-Path $ProjectRoot $group
  if (Test-Path -LiteralPath $groupDir) {
    Get-ChildItem -LiteralPath $groupDir -Directory | ForEach-Object {
      Add-Target (Join-Path $_.FullName "node_modules") "Installed packages"
    }
  }
}
Add-Target (Join-Path $ProjectRoot "remote\api\node_modules") "Installed packages"
Add-Target (Join-Path $ProjectRoot "apps\auth-api\.wrangler") "Local Cloudflare/D1 test database"
Add-Target (Join-Path $ProjectRoot "out-dev-app") "Dev build output"

if ($IncludeWorkspaces) {
  Add-Target (Join-Path $HOME "OpenBot") "Agent workspaces and file transfers"
}
if (-not $KeepBun) {
  Add-Target (Join-Path $HOME ".bun") "Bun and its package cache"
}

# 3. Show the list and ask ---------------------------------------------------
if ($targets.Count -eq 0) {
  Write-Host "Nothing to remove. This PC is already clean." -ForegroundColor Green
  return
}

Write-Host "`nThis will permanently delete:`n" -ForegroundColor Yellow
foreach ($t in $targets) {
  Write-Host ("  {0}" -f $t.Path)
  Write-Host ("      {0}" -f $t.Why) -ForegroundColor DarkGray
}
if (-not $IncludeWorkspaces -and (Test-Path -LiteralPath (Join-Path $HOME "OpenBot"))) {
  Write-Host "`nNot included: $HOME\OpenBot (agent workspaces). Add -IncludeWorkspaces to delete it too." -ForegroundColor DarkGray
}
Write-Host "`nChats and settings in the dev app data cannot be recovered after this." -ForegroundColor Yellow

if (-not $Yes) {
  $answer = Read-Host "`nType DELETE to continue, or anything else to cancel"
  if ($answer -cne "DELETE") {
    Write-Host "Cancelled. Nothing was removed." -ForegroundColor Green
    return
  }
}

# 4. Delete ------------------------------------------------------------------
$failed = @()
foreach ($t in $targets) {
  Write-Host "Deleting $($t.Path)" -ForegroundColor Cyan
  # rd handles very long node_modules paths better than Remove-Item on Windows.
  cmd /c "rd /s /q `"$($t.Path)`"" 2>$null
  if (Test-Path -LiteralPath $t.Path) { $failed += $t.Path }
}

if ($failed.Count -gt 0) {
  Write-Host "`nCould not delete:" -ForegroundColor Red
  $failed | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
  Write-Host "Something may still be using these files. Close other windows or restart the PC, then run this script again." -ForegroundColor Red
  throw "Some folders were not deleted."
}

Write-Host "`nDone. Run setup.bat to install everything again." -ForegroundColor Green
