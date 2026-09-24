#!/usr/bin/env bash
# Run ON devops-pc with an ADMIN kubeconfig. Creates the ci-deployer identity
# in ns ci-cd, allowed to deploy only into ns anmates (../rbac-deployer.yaml),
# and writes a kubeconfig for it
# to ../kubeconfig, which docker-compose.yml mounts read-only into the runner.
#
#   KUBECONFIG=~/.kube/config ./scripts/make-deployer-kubeconfig.sh
#
# Idempotent. The token never expires (legacy SA token Secret) — rotate it with:
#   kubectl -n ci-cd delete secret ci-deployer-token && rerun this script
set -Eeuo pipefail

cd "$(dirname "$0")/.."
SA_NS=ci-cd     # where the identity + its token live
APP_NS=anmates  # the only namespace it may deploy into
OUT=./kubeconfig # docker-compose.yml mounts exactly this path
RUNNER_UID=1001 # `runner` user inside ghcr.io/actions/actions-runner

ctx="$(kubectl config current-context)"
server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
echo "context: ${ctx}  server: ${server}"
read -r -p "Create ci-deployer on THIS cluster? [y/N] " ok
[[ "$ok" == [yY] ]] || exit 1

kubectl get namespace "$APP_NS" >/dev/null
kubectl apply -f rbac-deployer.yaml

# The token controller fills the Secret asynchronously.
for _ in $(seq 1 30); do
  token="$(kubectl -n "$SA_NS" get secret ci-deployer-token -o jsonpath='{.data.token}' | base64 -d)"
  [[ -n "$token" ]] && break
  sleep 1
done
[[ -n "${token:-}" ]] || { echo "token not populated in secret ci-deployer-token" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
kubectl -n "$SA_NS" get secret ci-deployer-token -o jsonpath='{.data.ca\.crt}' | base64 -d >"$tmp/ca.crt"

new="$tmp/kubeconfig"
kubectl config --kubeconfig "$new" set-cluster onprem --server "$server" \
  --certificate-authority "$tmp/ca.crt" --embed-certs=true >/dev/null
kubectl config --kubeconfig "$new" set-credentials ci-deployer --token "$token" >/dev/null
kubectl config --kubeconfig "$new" set-context ci-deployer@onprem \
  --cluster onprem --user ci-deployer --namespace "$APP_NS" >/dev/null
kubectl config --kubeconfig "$new" use-context ci-deployer@onprem >/dev/null

# Prove the scope before handing it to CI: allowed in ns, denied cluster-wide.
kubectl --kubeconfig "$new" -n "$APP_NS" auth can-i patch deployments >/dev/null \
  || { echo "ci-deployer cannot patch deployments in ${APP_NS}" >&2; exit 1; }
if kubectl --kubeconfig "$new" auth can-i list nodes >/dev/null 2>&1; then
  echo "ci-deployer can list nodes — RBAC is broader than intended" >&2
  exit 1
fi

# Owned by the runner container's uid (read through a read-only bind mount).
SUDO=; [[ "$(id -u)" == 0 ]] || SUDO=sudo
$SUDO install -m 0600 -o "$RUNNER_UID" -g "$RUNNER_UID" "$new" "$OUT"
echo "wrote $(realpath "$OUT") (owner uid ${RUNNER_UID}, mode 600)"
