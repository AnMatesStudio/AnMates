#!/usr/bin/env bash
# Register (first boot only) then run the GitHub Actions runner.
#
# Registration credentials (.runner, .credentials, .credentials_rsaparams) are
# kept in the /runner-state volume, so a container restart / host reboot
# reconnects with NO token. RUNNER_TOKEN (Settings → Actions → Runners → New
# self-hosted runner, valid 1h) is only read while that volume is empty.
set -Eeuo pipefail

REPO_URL=https://github.com/AnMatesStudio/AnMates
RUNNER_NAME=devops-pc
RUNNER_LABELS=pc-runner
STATE_DIR=/runner-state
STATE_FILES=(.runner .credentials .credentials_rsaparams)

if [[ -f "$STATE_DIR/.runner" ]]; then
  echo "[entrypoint] restoring registration of '${RUNNER_NAME}'"
  for f in "${STATE_FILES[@]}"; do cp "$STATE_DIR/$f" ./; done
else
  : "${RUNNER_TOKEN:?not registered yet — set RUNNER_TOKEN in .env (see README §4)}"
  echo "[entrypoint] registering '${RUNNER_NAME}' (labels: ${RUNNER_LABELS})"
  # --replace takes over the slot of the old native runner with the same name.
  ./config.sh --unattended --replace \
    --url "$REPO_URL" \
    --token "$RUNNER_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS"
  for f in "${STATE_FILES[@]}"; do cp "$f" "$STATE_DIR/"; done
fi

# Container env is inherited by every job step — never leak the token to workflows.
unset RUNNER_TOKEN

# exec: run.sh replaces this shell, so `docker stop` (SIGTERM) reaches the
# listener and it ends its session cleanly.
exec ./run.sh
