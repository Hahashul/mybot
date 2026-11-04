#!/usr/bin/env bash
# One-step setup for mybot on macOS (also works on most Linux).
#
# Run from inside the project:   bash setup.sh
# Or from anywhere, no clone:    curl -fsSL https://raw.githubusercontent.com/Hahashul/mybot/main/setup.sh | bash
#
# It installs Node 24+ (through nvm) and the exact Bun version the project needs (1.4.2),
# gets the repo if you are not already inside it, runs "bun install --frozen-lockfile",
# then starts the app with "bun run dev".
#
# Options (when running a saved file):  --no-start   install only, do not start the app

REPO_URL="${MYBOT_REPO_URL:-https://github.com/Hahashul/mybot.git}"
INSTALL_DIR="${MYBOT_DIR:-$HOME/mybot}"
BUN_VERSION="1.4.2"
NODE_MAJOR=24
NVM_VERSION="v0.40.3"
START=1
[ "$1" = "--no-start" ] && START=0

step() { printf '\n\033[36m==> %s\033[0m\n' "$1"; }
ok()   { printf '    \033[32m%s\033[0m\n' "$1"; }
warn() { printf '    \033[33m%s\033[0m\n' "$1"; }
die()  { printf '\n\033[31mERROR: %s\033[0m\n' "$1"; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

node_major() {
  if have node; then node --version | sed 's/^v//' | cut -d. -f1; else echo 0; fi
}
bun_version() {
  if have bun; then bun --version | tr -d '[:space:]'; else echo ""; fi
}

export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
export PATH="$BUN_INSTALL/bin:$PATH"

# 1. Git ---------------------------------------------------------------------
step "Checking Git"
if ! have git; then
  if [ "$(uname)" = "Darwin" ]; then
    warn "Git is missing. A macOS window will ask to install the Command Line Tools."
    xcode-select --install 2>/dev/null
    die "Finish the Command Line Tools install, then run this script again."
  fi
  die "Git is missing. Install it with your package manager (for example: sudo apt install git), then run this script again."
fi
ok "$(git --version)"

# 2. Node.js 24+ -------------------------------------------------------------
step "Checking Node.js (need $NODE_MAJOR or newer)"
if [ "$(node_major)" -lt "$NODE_MAJOR" ]; then
  warn "Node $NODE_MAJOR+ not found. Installing it with nvm..."
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | bash || die "Could not install nvm."
  fi
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm install "$NODE_MAJOR" || die "nvm could not install Node $NODE_MAJOR."
  nvm use "$NODE_MAJOR" >/dev/null
  if [ "$(node_major)" -lt "$NODE_MAJOR" ]; then
    die "Node $NODE_MAJOR or newer is still not available. Install it from https://nodejs.org and run this script again."
  fi
fi
ok "Node $(node --version)"

# 3. Bun (exact version) -----------------------------------------------------
step "Checking Bun (need exactly $BUN_VERSION)"
if [ "$(bun_version)" != "$BUN_VERSION" ]; then
  current="$(bun_version)"
  if [ -n "$current" ]; then warn "Found Bun $current. Installing Bun $BUN_VERSION..."; else warn "Bun is missing. Installing Bun $BUN_VERSION..."; fi
  curl -fsSL https://bun.com/install | bash -s "bun-v$BUN_VERSION" || die "The Bun installer failed."
  export PATH="$BUN_INSTALL/bin:$PATH"
  hash -r
  if [ "$(bun_version)" != "$BUN_VERSION" ]; then
    die "Bun $BUN_VERSION is not the active version (found '$(bun_version)'). Another Bun may be earlier on your PATH. Open a new terminal and run this script again."
  fi
fi
ok "Bun $(bun_version)"

# 4. Find or get the project -------------------------------------------------
step "Locating the project"
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/package.json" ] && [ -f "$SCRIPT_DIR/bun.lock" ]; then
  ROOT="$SCRIPT_DIR"
  ok "Using the project in $ROOT"
elif [ -d "$INSTALL_DIR/.git" ]; then
  ROOT="$INSTALL_DIR"
  ok "Found an existing copy in $ROOT. Updating..."
  git -C "$ROOT" pull --ff-only || warn "Could not update automatically. Continuing with the files you have."
else
  ok "Cloning $REPO_URL into $INSTALL_DIR"
  git clone "$REPO_URL" "$INSTALL_DIR" || die "Clone failed. Check the URL and that you are signed in to GitHub."
  ROOT="$INSTALL_DIR"
fi
cd "$ROOT" || die "Cannot open $ROOT"

# 5. Dependencies ------------------------------------------------------------
step "Installing dependencies (the first run can take several minutes)"
bun install --frozen-lockfile || die "bun install failed. Scroll up for the first error message."
ok "Dependencies installed"

# 6. Agent CLI reminder ------------------------------------------------------
step "Checking for an AI agent CLI"
found=""
for cli in claude codex grok; do have "$cli" && found="$found $cli"; done
if [ -n "$found" ]; then
  ok "Found:$found"
else
  warn "No claude, codex or grok command found. The app needs at least one installed and signed in."
  warn "Claude Code: curl -fsSL https://claude.ai/install.sh | bash"
fi

# 7. Start -------------------------------------------------------------------
if [ "$START" -eq 0 ]; then
  printf '\n\033[32mSetup finished. Start the app any time with: cd "%s" && bun run dev\033[0m\n' "$ROOT"
  exit 0
fi
step "Starting the app (press Ctrl+C to stop)"
exec bun run dev
