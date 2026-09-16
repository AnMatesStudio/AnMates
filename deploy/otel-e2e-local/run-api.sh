#!/bin/sh
# Chạy anmates-api native, gửi OTLP vào collector của compose.yml bên cạnh.
# CHỈ dùng local: DB là container scratch, secret là giá trị giả.
#   docker compose -f deploy/otel-e2e-local/compose.yml up -d
#   deploy/otel-e2e-local/run-api.sh
set -e
cd "$(dirname "$0")/../../anmates-api"
export GO111MODULE=on
export DATABASE_URL="postgres://postgres:e2e@127.0.0.1:55432/anmates?sslmode=disable"
export JWT_SECRET="e2e-local-secret-0123456789abcdefghij"
export PORT=58080 DEV_MODE=true DEV_BYPASS_SECRET=e2e DISABLE_RATE_LIMIT=1
export OTEL_EXPORTER_OTLP_ENDPOINT=${OTEL_EXPORTER_OTLP_ENDPOINT:-http://127.0.0.1:54317}
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_SERVICE_NAME=anmates-api
export OTEL_TRACES_SAMPLER=parentbased_always_on
export OTEL_RESOURCE_ATTRIBUTES="service.namespace=anmates,service.version=e2e-local,deployment.environment=local,k8s.pod.name=local-pod,k8s.namespace.name=local"
exec go run .
