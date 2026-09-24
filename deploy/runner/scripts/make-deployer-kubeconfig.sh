#!/usr/bin/env bash
# Run ON devops-pc as your normal user (not sudo) with an ADMIN kubeconfig.
# Creates the ci-deployer identity in ns ci-cd, allowed to deploy only into
# ns anmates (../rbac-deployer.yaml), and writes its kubeconfig to ../kubeconfig,
# which docker-compose.yml mounts read-only into the runner.
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

# sudo would pick up root's kubeconfig and make the file root-owned.
if [[ "$(id -u)" == 0 ]]; then
  echo "run as your normal user, not root/sudo" >&2
  exit 1
fi

ctx="$(kubectl config current-context)"
server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
echo "context: ${ctx}  server: ${server}"
read -r -p "Create ci-deployer on THIS cluster? [y/N] " ok
[[ "$ok" == [yY] || "$ok" == [yY][eE][sS] ]] || { echo "aborted" >&2; exit 1; }

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
# -A is required: without it can-i asks inside the context's namespace (anmates),
# where the Role's `resources: ["*"]` answers "yes" even for cluster-scoped
# resources like nodes — a false alarm, while a real `get nodes` is Forbidden.
for check in "list nodes" "list secrets"; do
  # shellcheck disable=SC2086 # $check is intentionally split into verb + resource
  if kubectl --kubeconfig "$new" auth can-i $check -A >/dev/null 2>&1; then
    echo "ci-deployer can '${check}' cluster-wide — RBAC is broader than intended" >&2
    exit 1
  fi
done

# Owned by you, readable by your primary group (on Ubuntu: a group of just you).
# The runner container (uid 1001) joins that group via group_add, reading
# KUBECONFIG_GID from .env. rm first: an older file may belong to another user.
rm -f "$OUT"
install -m 0640 "$new" "$OUT"
gid="$(id -g)"
touch .env && chmod 600 .env
if grep -q '^KUBECONFIG_GID=' .env; then
  sed -i "s/^KUBECONFIG_GID=.*/KUBECONFIG_GID=${gid}/" .env
else
  echo "KUBECONFIG_GID=${gid}" >>.env
fi
echo "wrote $(realpath "$OUT") ($(id -un):$(id -gn), mode 640) and KUBECONFIG_GID=${gid} to .env"
