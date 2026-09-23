#!/bin/sh
# Chạy anmates-api native, gửi OTLP vào collector của compose.yml bên cạnh.
# CHỈ dùng local: DB là container scratch, DEV_MODE/DEV_BYPASS_SECRET/
# DISABLE_RATE_LIMIT bật đúng như quy ước dev-local của repo (xem .env.example
# gốc) — KHÔNG dùng file/biến này để chạy nhắm vào bất kỳ endpoint nào khác
# localhost.
#
#   deploy/otel-e2e-local/up.sh       # sinh secret ephemeral + lên compose
#   deploy/otel-e2e-local/run-api.sh
set -e
cd "$(dirname "$0")"

if [ ! -f .env ]; then
	echo "thiếu .env — chạy ./up.sh trước (nó sinh secret ephemeral)" >&2
	exit 1
fi
# shellcheck source=/dev/null
. ./.env

cd ../../anmates-api
export GO111MODULE=on
export DATABASE_URL="postgres://postgres:${OTEL_E2E_DB_PASS}@127.0.0.1:55432/anmates?sslmode=disable"
export JWT_SECRET="${OTEL_E2E_JWT_SECRET}"
export PORT=58080 DEV_MODE=true DEV_BYPASS_SECRET=e2e DISABLE_RATE_LIMIT=1
export OTEL_EXPORTER_OTLP_ENDPOINT=${OTEL_EXPORTER_OTLP_ENDPOINT:-http://127.0.0.1:54317}
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_SERVICE_NAME=anmates-api
export OTEL_TRACES_SAMPLER=parentbased_always_on
export OTEL_RESOURCE_ATTRIBUTES="service.namespace=anmates,service.version=e2e-local,deployment.environment=local,k8s.pod.name=local-pod,k8s.namespace.name=local"
exec go run .
