# 2026-09-06 — 502 tren /api/*: nginx.conf giu resolver cua docker-compose khi chay tren k8s

**Status:** fix da code + verify bang Docker that, **CHUA user-confirm tren prod** (can rebuild image web + helm upgrade).

## TL;DR
`https://app.anmates.site/api/v1/venues` tra 502 sau ~26-30s, trong khi SPA (`/`) van 200.
Khong phai "web goi API bang DNS thay vi qua nginx" — URL do **chinh la** duong nginx
(same-origin `/api/` -> `proxy_pass`). Cai chet nam o buoc nginx phan giai ten upstream.

## Root cause
`anmates_flutter/nginx.conf` hardcode 2 gia tri **chi dung cho docker compose**:
- `resolver 127.0.0.11` — DNS nhung cua Docker. Trong pod k8s **khong co gi lang nghe** o day.
- `set $api_upstream http://api:8080` — ten service cua compose; Service tren k8s ten `anmates-api`
  (values.yaml `api.serviceName`, va plan 2026-09-01 §H4 da ghi ro phai dung ten do).

Vi `proxy_pass` di qua bien nen nginx phan giai luc request: moi request /api/ ngoi cho
`resolver_timeout` (mac dinh 30s) roi tra 502. Static file khong dung DNS nen `/` van 200 —
dung het moi trieu chung tren DevTools (timeline ~26s) va curl (rc=28 timeout).

## Bang chung (reproduce that, khong doan)
- `curl https://app.anmates.site/` -> 200; `/health` va `/api/v1/...` -> timeout roi 502.
- Dung image nginx that, ep `NGINX_RESOLVER` tro toi dia chi khong ai tra loi:
  `GET / -> 200 in 0.002s`, `GET /api/.. -> 502 in 30.01s`, log nginx:
  `anmates-api could not be resolved (110: Operation timed out)`.

## Solution
nginx.conf tro thanh **template** (co che san co cua image nginx: `/etc/nginx/templates/*.template`
-> envsubst luc khoi dong), 2 gia tri platform-specific chuyen thanh config:
- `anmates_flutter/docker-entrypoint.d/10-upstream-env.envsh` (duoc entrypoint **source** truoc
  buoc envsubst): `API_UPSTREAM` mac dinh `http://api:8080` (compose), con `NGINX_RESOLVER`
  **doc tu `/etc/resolv.conf`** nen tu dung o ca docker (127.0.0.11) lan k8s (CoreDNS ClusterIP).
- `deploy/charts/anmates/templates/web-deployment.yaml`: them env
  `API_UPSTREAM=http://{{ api.serviceName }}:{{ api.service.port }}` -> `http://anmates-api:8080`.

## Files changed
- `anmates_flutter/nginx.conf` — `resolver ${NGINX_RESOLVER}` + `set $api_upstream ${API_UPSTREAM}`
- `anmates_flutter/docker-entrypoint.d/10-upstream-env.envsh` (moi)
- `anmates_flutter/Dockerfile`, `Dockerfile.prebuilt` — COPY vao `templates/` + `/docker-entrypoint.d/`
- `deploy/charts/anmates/templates/web-deployment.yaml` — env API_UPSTREAM

## Verification (da chay)
- Case A (compose defaults, khong env): `/` 200, `/api/v1/venues` 200 "BACKEND-OK", `/health` 200.
- Case B (k8s-like, `API_UPSTREAM=http://anmates-api:8080`): `/api/v1/venues` 200 trong 0.002s.
- Case C (mang co DNS != 127.0.0.11): resolver render dung IP doc tu resolv.conf.
- `helm lint` pass; `helm template` render `value: "http://anmates-api:8080"`.
- **Pending:** rebuild + push image web, `helm upgrade`, roi curl lai qua app.anmates.site.

## Key facts
- nginx KHONG doc /etc/resolv.conf cho `proxy_pass` qua bien — bat buoc phai co directive `resolver`.
- File `.envsh` trong `/docker-entrypoint.d/` duoc **source** (phai co bit +x), nen export trong
  do den duoc buoc envsubst chay sau.
- envsubst chi thay the ten **co thuc trong env**, nen `$uri`, `$host`, `$http_upgrade` an toan.
