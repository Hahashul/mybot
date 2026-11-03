<#
  One-step setup for mybot on Windows.

  Easiest: double-click setup.bat (or run it in Command Prompt).

  What it does:
    1. Installs Git and Node.js 24+ with winget if they are missing.
    2. Installs the exact Bun version this project needs (1.4.2).
    3. Uses this folder if you run it from inside the project; otherwise clones your repo.
    4. Runs "bun install --frozen-lockfile".
    5. Starts the app with "bun run dev" (skip with -NoStart).

  Options:
    -RepoUrl     Git URL to clone when the script is not inside the project.
    -InstallDir  Where to clone it (default: %USERPROFILE%\mybot).
    -NoStart     Install everything but do not start the app.
#>
[CmdletBinding()]
param(
  [string]$RepoUrl = "https://github.com/Hahashul/mybot.git",
  [string]$InstallDir = (Join-Path $HOME "mybot"),
  [switch]$NoStart
)

$ErrorActionPreference = "Stop"

# Versions the project requires (from package.json, .nvmrc and README).
$BunVersion = "1.4.2"
$NodeMajor = 24

function Step([string]$Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Ok([string]$Message)   { Write-Host "    $Message" -ForegroundColor Green }
function Warn([string]$Message) { Write-Host "    $Message" -ForegroundColor Yellow }
function Fail([string]$Message) {
  Write-Host "`nERROR: $Message" -ForegroundColor Red
  throw $Message
}

function Has([string]$Name) {
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# Reload PATH so tools installed a moment ago work in this same window.
function Update-SessionPath {
  $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $user = [Environment]::GetEnvironmentVariable("Path", "User")
  $env:Path = "$machine;$user;$HOME\.bun\bin"
}

function Install-WithWinget([string]$Id) {
  if (-not (Has "winget")) {
    Fail "winget is not available. Install '$Id' by hand, then run this script again."
  }
  winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements
  Update-SessionPath
}

function Get-NodeMajor {
  if (-not (Has "node")) { return 0 }
  $text = (node --version).Trim().TrimStart("v")
  return [int]($text.Split(".")[0])
}

function Get-BunVersion {
  if (-not (Has "bun")) { return "" }
  return (bun --version).Trim()
}

Update-SessionPath

# 1. Git ---------------------------------------------------------------------
Step "Checking Git"
if (-not (Has "git")) {
  Warn "Git is missing. Installing..."
  Install-WithWinget "Git.Git"
  if (-not (Has "git")) {
    Fail "Git was installed but is not on PATH yet. Close this window, open a new one, and run the script again."
  }
}
Ok (git --version)

# 2. Node.js 24+ -------------------------------------------------------------
Step "Checking Node.js (need $NodeMajor or newer)"
if ((Get-NodeMajor) -lt $NodeMajor) {
  Warn "Node.js $NodeMajor+ not found. Installing the LTS release..."
  Install-WithWinget "OpenJS.NodeJS.LTS"
  if ((Get-NodeMajor) -lt $NodeMajor) {
    Fail "Node.js $NodeMajor or newer is still not available. Install it from https://nodejs.org, open a new window, and run the script again."
  }
}
Ok "Node $(node --version)"

# 3. Bun (exact version) -----------------------------------------------------
Step "Checking Bun (need exactly $BunVersion)"
if ((Get-BunVersion) -ne $BunVersion) {
  $current = Get-BunVersion
  if ($current) { Warn "Found Bun $current. Installing Bun $BunVersion..." } else { Warn "Bun is missing. Installing Bun $BunVersion..." }
  Invoke-Expression "& {$(Invoke-RestMethod https://bun.com/install.ps1)} -Version $BunVersion"
  Update-SessionPath
  if ((Get-BunVersion) -ne $BunVersion) {
    Fail "Bun $BunVersion is not the active version (found '$(Get-BunVersion)'). Another Bun may be earlier on your PATH. Open a new window and run the script again."
  }
}
Ok "Bun $(Get-BunVersion)"

# 4. Find or clone the project ----------------------------------------------
Step "Locating the project"
$insideProject = $PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "package.json")) -and (Test-Path (Join-Path $PSScriptRoot "bun.lock"))
if ($insideProject) {
  $Root = $PSScriptRoot
  Ok "Using the project in $Root"
}
elseif (Test-Path (Join-Path $InstallDir ".git")) {
  $Root = $InstallDir
  Ok "Found an existing copy in $Root. Updating..."
  git -C $Root pull --ff-only
  if ($LASTEXITCODE -ne 0) { Warn "Could not update automatically. Continuing with the files you have." }
}
else {
  Ok "Cloning $RepoUrl into $InstallDir"
  Warn "If the repo is private, a browser window may open so you can sign in to GitHub."
  git clone $RepoUrl $InstallDir
  if ($LASTEXITCODE -ne 0) { Fail "Clone failed. Check the URL and that you are signed in to GitHub." }
  $Root = $InstallDir
}
Set-Location $Root

# 5. Dependencies ------------------------------------------------------------
Step "Installing dependencies (the first run can take several minutes)"
bun install --frozen-lockfile
if ($LASTEXITCODE -ne 0) { Fail "bun install failed. Scroll up for the first error message." }
Ok "Dependencies installed"

# 6. Agent CLI reminder ------------------------------------------------------
Step "Checking for an AI agent CLI"
$agents = @("claude", "codex", "grok") | Where-Object { Has $_ }
if ($agents.Count -gt 0) {
  Ok ("Found: " + ($agents -join ", "))
}
else {
  Warn "No claude, codex or grok command found. The app needs at least one installed and signed in."
  Warn "Claude Code: https://claude.ai/install.ps1   (it also needs Git for Windows, which is installed above)"
}

# 7. Start -------------------------------------------------------------------
if ($NoStart) {
  Write-Host "`nSetup finished. Start the app any time with start-mybot.bat" -ForegroundColor Green
  return
}
Step "Starting the app (press Ctrl+C in this window to stop)"
bun run dev
