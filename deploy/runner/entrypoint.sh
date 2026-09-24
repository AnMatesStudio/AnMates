#!/usr/bin/env bash
# Register (when given a token) then run the GitHub Actions runner.
#
# Registration credentials (.runner, .credentials, .credentials_rsaparams) are
# kept in the /runner-state volume, so a container restart / host reboot
# reconnects with NO token.
#
# RUNNER_TOKEN (Settings → Actions → Runners → New self-hosted runner, valid 1h)
# wins over the saved state: set a fresh one after re-creating the runner on
# GitHub and the old, server-deleted registration is replaced. A token left in
# .env past its hour is rejected by GitHub and the saved state is used instead.
set -Eeuo pipefail

REPO_URL=https://github.com/AnMatesStudio/AnMates
RUNNER_NAME=devops-pc
RUNNER_LABELS=pc-runner
STATE_DIR=/runner-state
STATE_FILES=(.runner .credentials .credentials_rsaparams)

register() {
  echo "[entrypoint] registering '${RUNNER_NAME}' (labels: ${RUNNER_LABELS})"
  # config.sh refuses to run over an existing local registration.
  rm -f "${STATE_FILES[@]}"
  # --replace takes over a runner of the same name already listed on GitHub.
  ./config.sh --unattended --replace \
    --url "$REPO_URL" \
    --token "$RUNNER_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" || return 1
  cp "${STATE_FILES[@]}" "$STATE_DIR/"
}

if [[ -n "${RUNNER_TOKEN:-}" ]] && register; then
  :
elif [[ -f "$STATE_DIR/.runner" ]]; then
  [[ -n "${RUNNER_TOKEN:-}" ]] && echo "[entrypoint] RUNNER_TOKEN rejected (expired?) — using saved registration"
  echo "[entrypoint] restoring registration of '${RUNNER_NAME}'"
  for f in "${STATE_FILES[@]}"; do cp "$STATE_DIR/$f" ./; done
else
  echo "[entrypoint] not registered — put a fresh RUNNER_TOKEN in .env (README §4)" >&2
  exit 1
fi

# Container env is inherited by every job step — never leak the token to workflows.
unset RUNNER_TOKEN

# exec: run.sh replaces this shell, so `docker stop` (SIGTERM) reaches the
# listener and it ends its session cleanly.
exec ./run.sh
