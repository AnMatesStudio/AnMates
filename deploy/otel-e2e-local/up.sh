#!/bin/sh
# Sinh secret ephemeral cho rig E2E local rồi khởi động compose.yml.
#
# Không hardcode mật khẩu/JWT secret trong file commit được: mỗi lần chạy sinh
# một bộ mới, ghi vào .env cạnh file này (đã gitignore — xem .gitignore gốc
# repo). Rig này CHỈ chạm vào container scratch, không bao giờ trỏ vào DB/
# collector thật — xem cảnh báo port-bind trong compose.yml.
set -e
cd "$(dirname "$0")"

if [ ! -f .env ]; then
	{
		echo "OTEL_E2E_DB_PASS=$(openssl rand -hex 20)"
		echo "OTEL_E2E_JWT_SECRET=$(openssl rand -hex 32)"
	} > .env
	echo "sinh secret ephemeral mới vào $(pwd)/.env"
fi

docker compose --env-file .env -f compose.yml up -d
echo "rig lên rồi — chạy tiếp: deploy/otel-e2e-local/run-api.sh"
