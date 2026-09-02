# syntax=docker/dockerfile:1.7
# Self-contained build: compile Flutter web inside the image → serve with nginx.
# Used by docker-compose/start.sh so local dev needs no Flutter SDK installed.
#
# CI does NOT use this file — it already has the SDK set up for analyze/test, so
# it builds the bundle on the runner and packages it with `Dockerfile.prebuilt`
# (seconds instead of minutes). Keep the nginx stage below in sync with that file.

FROM ghcr.io/cirruslabs/flutter:stable AS builder
# Absolute API URL for local compose, where web (:54180) and API (:8080) are
# different origins. Left empty in same-origin deploys — see auth_service.dart.
ARG API_BASE_URL=http://localhost:8080
# Goong Maptiles key (client-side map tiles). Empty = blank "Bản đồ" tab (build
# still succeeds). Distinct from the server-side GOONG_API_KEY (REST).
ARG GOONG_MAPTILES_KEY=
WORKDIR /app

# Prime dependency cache.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source and build.
COPY . .
RUN flutter pub get \
 && flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=GOONG_MAPTILES_KEY=${GOONG_MAPTILES_KEY}

FROM nginx:1.27-alpine
RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build/web /usr/share/nginx/html
EXPOSE 80
# Use 127.0.0.1 (IPv4), not localhost: busybox wget resolves localhost to IPv6 ::1
# first, but nginx listens on IPv4 only → "connection refused" → stuck "unhealthy".
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1
