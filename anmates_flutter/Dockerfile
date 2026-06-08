# syntax=docker/dockerfile:1.7
# Multi-stage build: compile Flutter web → serve with nginx.

FROM ghcr.io/cirruslabs/flutter:stable AS builder
ARG API_BASE_URL=http://localhost:8080
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
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build/web /usr/share/nginx/html
EXPOSE 80
# Use 127.0.0.1 (IPv4), not localhost: busybox wget resolves localhost to IPv6 ::1
# first, but nginx listens on IPv4 only → "connection refused" → stuck "unhealthy".
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1
