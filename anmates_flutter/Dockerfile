# syntax=docker/dockerfile:1.7
# Self-contained build: compile Flutter web inside the image → serve with nginx.
# Used by docker-compose/start.sh so local dev needs no Flutter SDK installed.
#
# CI does NOT use this file — it already has the SDK set up for analyze/test, so
# it builds the bundle on the runner and packages it with `Dockerfile.prebuilt`
# (seconds instead of minutes). Keep the nginx stage below in sync with that file.

FROM ghcr.io/cirruslabs/flutter:stable AS builder
# Absolute API URL, baked into the JS bundle at build time. Empty by default —
# see auth_service.dart's Uri.base.origin runtime fallback — so the same image
# works behind localhost, a LAN IP, or a public tunnel with no rebuild. Only
# pass a non-empty value for a split-origin deploy (web and API on different
# hosts/ports with no reverse proxy between them); a value baked here breaks
# every other origin (see docker-compose.yml's API_BASE_URL comment).
ARG API_BASE_URL=
WORKDIR /app

# Prime dependency cache.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source and build.
COPY . .
RUN flutter pub get \
 && flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:1.27-alpine
RUN rm -f /etc/nginx/conf.d/default.conf
# nginx.conf is a TEMPLATE, not a final config: the entrypoint runs envsubst over
# /etc/nginx/templates/*.template into /etc/nginx/conf.d/ at container start, and
# 10-upstream-env.envsh (sourced first — hence the .envsh suffix and +x) supplies
# the resolver + upstream host, which differ between compose and k8s.
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --chmod=755 docker-entrypoint.d/10-upstream-env.envsh /docker-entrypoint.d/10-upstream-env.envsh
COPY --from=builder /app/build/web /usr/share/nginx/html
EXPOSE 80
# Use 127.0.0.1 (IPv4), not localhost: busybox wget resolves localhost to IPv6 ::1
# first, but nginx listens on IPv4 only → "connection refused" → stuck "unhealthy".
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1
