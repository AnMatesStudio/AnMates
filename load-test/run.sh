#!/usr/bin/env bash
# Load-test runner for AnMates API
# Usage: ./run.sh [options]
#   -v <n>   Peak virtual users (default: 500)
#   -u <n>   Pre-created user pool size (default: 100)
#   -c       Remove result files before running
#   -h       Show this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VUS=500
USER_POOL=500
CLEAN=0

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while getopts "v:u:ch" opt; do
  case $opt in
    v) VUS="$OPTARG" ;;
    u) USER_POOL="$OPTARG" ;;
    c) CLEAN=1 ;;
    h) usage ;;
    *) echo "Unknown option: -$OPTARG"; exit 1 ;;
  esac
done

# ── colours ──────────────────────────────────────────────────────────────────
CYAN='\033[0;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; WHITE='\033[1;37m'; RESET='\033[0m'

banner() { echo -e "\n${CYAN}==> $1${RESET}"; }
ok()     { echo -e "    ${GREEN}$1${RESET}"; }
warn()   { echo -e "    ${YELLOW}[warn] $1${RESET}"; }
die()    { echo -e "\n${RED}[ERROR] $1${RESET}"; exit 1; }

open_browser() {
  # Works in WSL (Windows), macOS, and Linux desktops
  local url="$1"
  if command -v cmd.exe &>/dev/null; then
    cmd.exe /c start "$url" 2>/dev/null || true   # WSL / Windows
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$url" &>/dev/null || true            # Linux desktop
  elif command -v open &>/dev/null; then
    open "$url" || true                             # macOS
  fi
}

# ── preflight ────────────────────────────────────────────────────────────────
banner "Preflight checks"
command -v docker &>/dev/null || die "docker not found in PATH"
docker compose version &>/dev/null || die "docker compose plugin not available"
ok "docker compose: OK"
[[ -f "$SCRIPT_DIR/k6-script.js" ]] || die "k6-script.js not found"
ok "k6-script.js: found"

# ── clean previous results ────────────────────────────────────────────────────
if [[ $CLEAN -eq 1 ]]; then
  banner "Cleaning previous results"
  rm -f "$SCRIPT_DIR/results/raw.json" "$SCRIPT_DIR/results/report.html"
  ok "results cleared"
fi
mkdir -p "$SCRIPT_DIR/results"

# ── tear down any leftover containers ────────────────────────────────────────
banner "Tearing down previous stack (if any)"
docker compose down --remove-orphans &>/dev/null || true
ok "done"

# ── run ───────────────────────────────────────────────────────────────────────
banner "Starting stack  (db + api build + k6 load test)"
echo -e "    Peak VUs  : ${WHITE}$VUS${RESET}"
echo -e "    User pool : ${WHITE}$USER_POOL${RESET}"
echo -e "    Dashboard : ${WHITE}http://localhost:5665${RESET}"
echo -e "    This takes ~4 minutes. Press Ctrl+C to abort.\n"

export USER_POOL PEAK_VUS="$VUS"

# Start stack in background so we can open the browser while it runs
docker compose up --build --abort-on-container-exit &
COMPOSE_PID=$!

# Wait for k6 dashboard to be ready (up to 60 s), then open browser
banner "Waiting for k6 dashboard on port 5665"
DASHBOARD_URL="http://localhost:5665"
for i in $(seq 1 30); do
  if curl -sf "$DASHBOARD_URL" -o /dev/null 2>/dev/null; then
    ok "Dashboard ready"
    echo -e "    Opening ${WHITE}${DASHBOARD_URL}${RESET} in your browser..."
    open_browser "$DASHBOARD_URL"
    break
  fi
  sleep 2
done

# Wait for docker compose to finish
wait $COMPOSE_PID || true

banner "Tearing down stack"
docker compose down --remove-orphans &>/dev/null || true
ok "containers removed"

# ── parse results ─────────────────────────────────────────────────────────────
RAW="$SCRIPT_DIR/results/raw.json"
[[ -f "$RAW" ]] || die "raw.json not found — test may have failed before k6 wrote output"

banner "Parsing results"

python3 "$SCRIPT_DIR/parse_results.py" "$RAW" "$VUS" "$USER_POOL"
