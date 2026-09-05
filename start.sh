#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# start.sh — AnMates local dev launcher
# Supports: macOS (OrbStack / Docker Desktop) · Linux · Windows (WSL2 / Git Bash)
# Usage:  ./start.sh
# Custom: FLUTTER_WEB_PORT=3000 API_PORT=9000 ./start.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()   { echo -e "${GREEN}[AnMates]${NC} $1"; }
warn()  { echo -e "${YELLOW}[AnMates]${NC} $1"; }
error() { echo -e "${RED}[AnMates]${NC} $1"; exit 1; }

# ── Config (override via env vars) ────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_PORT="${FLUTTER_WEB_PORT:-54180}"
API_PORT="${API_PORT:-8080}"

# ── Detect OS ─────────────────────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  MINGW*|CYGWIN*|MSYS*) PLATFORM="windows" ;;
  *) PLATFORM="unknown" ;;
esac

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  AnMates — Local Dev Launcher  [${PLATFORM}]${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ── 1. Detect LAN IP ──────────────────────────────────────────────────────────
if [[ "$PLATFORM" == "macos" ]]; then
  LAN_IP=$(ipconfig getifaddr en0 2>/dev/null \
         || ipconfig getifaddr en1 2>/dev/null \
         || echo "localhost")
elif [[ "$PLATFORM" == "linux" || "$PLATFORM" == "windows" ]]; then
  LAN_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' \
         || hostname -I 2>/dev/null | awk '{print $1}' \
         || echo "localhost")
else
  LAN_IP="localhost"
fi
log "LAN IP: $LAN_IP"

# ── 2. Setup Docker host ──────────────────────────────────────────────────────
if [[ "$PLATFORM" == "macos" ]]; then
  if [[ -S "$HOME/.orbstack/run/docker.sock" ]]; then
    export DOCKER_HOST="unix://$HOME/.orbstack/run/docker.sock"
    DOCKER_RUNTIME="OrbStack"
  elif [[ -S "$HOME/.docker/run/docker.sock" ]]; then
    export DOCKER_HOST="unix://$HOME/.docker/run/docker.sock"
    DOCKER_RUNTIME="Docker Desktop"
  elif [[ -S "/var/run/docker.sock" ]]; then
    export DOCKER_HOST="unix:///var/run/docker.sock"
    DOCKER_RUNTIME="Docker"
  else
    warn "OrbStack not running. Starting..."
    open -a OrbStack 2>/dev/null || error "Docker not found.\nmacOS: Install OrbStack → https://orbstack.dev\n  OR: Install Docker Desktop → https://www.docker.com/products/docker-desktop"
    log "Waiting for OrbStack..."
    for i in {1..20}; do
      [[ -S "$HOME/.orbstack/run/docker.sock" ]] && break
      sleep 2
      [[ $i == 20 ]] && error "OrbStack did not start. Open it manually and retry."
    done
    export DOCKER_HOST="unix://$HOME/.orbstack/run/docker.sock"
    DOCKER_RUNTIME="OrbStack"
  fi
elif [[ "$PLATFORM" == "linux" ]]; then
  if [[ -S "/var/run/docker.sock" ]]; then
    export DOCKER_HOST="unix:///var/run/docker.sock"
    DOCKER_RUNTIME="Docker Engine"
  else
    error "Docker not running.\nLinux: sudo systemctl start docker"
  fi
else
  # Windows Git Bash / WSL2
  DOCKER_RUNTIME="Docker Desktop"
fi
log "Docker runtime: $DOCKER_RUNTIME ✓"

# ── 3. Verify docker is accessible ───────────────────────────────────────────
docker info &>/dev/null || error "Cannot connect to Docker daemon ($DOCKER_RUNTIME).\nMake sure Docker is running and try again."

# ── 4. Check .env ────────────────────────────────────────────────────────────
[[ -f "$SCRIPT_DIR/.env" ]] || error ".env not found in AnMatesApp/\nCopy from .env.example: cp .env.example .env\nThen fill in the values."

# ── 5. Set API_BASE_URL for Flutter Docker build ──────────────────────────────
# Exporting overrides the .env value when docker-compose passes it as a build arg.
# The browser resolves this URL — use LAN IP so mobile devices on the same
# network can reach the API.
export API_BASE_URL="http://$LAN_IP:$API_PORT"
log "API_BASE_URL → $API_BASE_URL"

# ── 5b. Compose files ────────────────────────────────────────────────────────
# COMPOSE_FILE is read automatically by every `docker compose` call below.
export COMPOSE_PATH_SEPARATOR=":"
export COMPOSE_FILE="docker-compose.yml"

# ── 6. Build + start all services ────────────────────────────────────────────
log "Building and starting services (DB · API · Flutter web)..."
log "First run: Flutter image pull + Dart compile may take a few minutes."
cd "$SCRIPT_DIR"
docker compose up --build -d 2>&1 \
  | grep -E "#[0-9]+|Starting|Started|Running|Created|Healthy|Built|Warning|[Ee]rror" \
  || true

# ── 7. Wait for API health ────────────────────────────────────────────────────
log "Waiting for API health check..."
for i in {1..30}; do
  if curl -sf "http://localhost:$API_PORT/health" &>/dev/null; then
    log "API healthy ✓"
    break
  fi
  sleep 2
  if [[ $i == 30 ]]; then
    warn "API not responding. Check logs:"
    warn "  docker compose logs api"
    warn "  docker compose logs db"
    error "API not healthy after 60s."
  fi
done

# ── 8. Wait for Flutter web (nginx) ──────────────────────────────────────────
log "Waiting for Flutter web (nginx)..."
for i in {1..60}; do
  if curl -sf "http://localhost:$WEB_PORT" &>/dev/null; then
    log "Flutter web ready ✓"
    break
  fi
  sleep 3
  if [[ $i == 60 ]]; then
    warn "Flutter web not responding. Check logs:"
    warn "  docker compose logs flutter_web"
    error "Flutter web not ready after 180s."
  fi
done

# ── 9. Open browser ───────────────────────────────────────────────────────────
APP_URL="http://localhost:$WEB_PORT"
case "$PLATFORM" in
  macos)   open "$APP_URL" 2>/dev/null || true ;;
  linux)   xdg-open "$APP_URL" 2>/dev/null || true ;;
  windows) start "$APP_URL" 2>/dev/null || true ;;
esac

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  AnMates is running!${NC}"
echo ""
echo -e "  Flutter web   →  ${CYAN}http://localhost:$WEB_PORT${NC}"
echo -e "  LAN (mobile)  →  ${CYAN}http://$LAN_IP:$WEB_PORT${NC}"
echo -e "  Go API        →  ${CYAN}http://localhost:$API_PORT${NC}"
echo -e "  API health    →  ${CYAN}http://localhost:$API_PORT/health${NC}"
echo ""
echo -e "  Press ${YELLOW}Ctrl+C${NC} to stop"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ── 10. Stream logs ───────────────────────────────────────────────────────────
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${CYAN}[API go-fiber]${NC}  Go backend   · port $API_PORT"
echo -e "  ${GREEN}[WEB nginx]${NC}     Flutter web  · port $WEB_PORT"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

_start_log_stream() {
  cd "$SCRIPT_DIR"
  docker compose logs -f --tail="${1:-20}" api 2>&1 | while IFS= read -r line; do
    clean="${line#*| }"
    echo -e "${CYAN}[API go-fiber]${NC} $clean"
  done &
  LOG_PID=$!
}

_stop_services() {
  kill "$LOG_PID" 2>/dev/null || true
  pkill -P $$ 2>/dev/null || true
  sleep 0.3
}

LOG_PID=""
_ACTION=""

_cleanup() {
  trap '' INT TERM
  echo ""
  _stop_services

  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}  AnMates — bạn muốn làm gì?${NC}"
  echo ""
  echo -e "  ${GREEN}[1]${NC} Stop & Exit  — dừng containers, giải phóng RAM/CPU"
  echo -e "       ${GREEN}→${NC} chạy lại ./start.sh để tiếp tục"
  echo -e "  ${CYAN}[2]${NC} Rebuild     — build lại code mới + restart tất cả services"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  printf "  Chọn [1/2]: "
  read -r _ACTION </dev/tty

  trap _cleanup INT TERM
}

trap _cleanup INT TERM
_start_log_stream 20

# ── Main loop ─────────────────────────────────────────────────────────────────
while true; do
  wait "$LOG_PID" || true

  case "${_ACTION}" in
    2)
      _ACTION=""
      echo ""
      log "Rebuilding all services..."
      cd "$SCRIPT_DIR"
      docker compose up --build -d 2>&1 \
        | grep -E "#[0-9]+|Starting|Started|Running|Created|Healthy|Built|Warning|[Ee]rror" \
        || true

      log "Waiting for API health check..."
      for i in {1..30}; do
        if curl -sf "http://localhost:$API_PORT/health" &>/dev/null; then
          log "API healthy ✓"; break
        fi
        sleep 2
        [[ $i == 30 ]] && warn "API not responding after rebuild."
      done

      _start_log_stream 0
      log "AnMates running ✓ — Ctrl+C for options"
      ;;

    *)
      echo ""
      log "Dừng containers — giải phóng RAM/CPU..."
      cd "$SCRIPT_DIR"
      docker compose stop 2>&1 | grep -E "Stopped|Warning|error" || true
      log "Containers đã dừng. Chạy lại ./start.sh để tiếp tục."
      exit 0
      ;;
  esac
done
