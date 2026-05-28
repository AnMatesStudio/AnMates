# syntax=docker/dockerfile:1.7
FROM golang:1.25-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o api .

# alpine instead of scratch: adds /bin/sh for docker exec debugging + ca-certificates
FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata
WORKDIR /app
COPY --from=builder /app/api ./api

# Tune Go runtime for 1 vCPU / 1 GB Cloud Run instance.
# Override both in Cloud Run env vars when scaling up.
# GOMAXPROCS: Go doesn't read this from env automatically — main.go reads it.
# GOMEMLIMIT: Go 1.19+ reads this automatically; keep GC pressure below OOM threshold.
ENV GOMAXPROCS=1 \
    GOMEMLIMIT=900MiB

EXPOSE 8080
ENTRYPOINT ["/app/api"]
