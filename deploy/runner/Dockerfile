# syntax=docker/dockerfile:1.7
# Self-hosted GitHub Actions runner for .github/workflows/cd.yml, run as a
# container on devops-pc (runbook: README.md). CI builds on GitHub-hosted
# runners; this one only needs helm + kubectl to roll the SHA-tagged GHCR
# images onto the on-prem cluster.
#
# Bump a version: edit the ARG, then `docker compose build --pull && docker compose up -d`.
ARG RUNNER_IMAGE=ghcr.io/actions/actions-runner:latest
FROM ${RUNNER_IMAGE}

ARG TARGETARCH
ARG HELM_VERSION=v4.0.0
# Empty = latest stable at build time. Pin to the cluster's minor (±1) if it lags.
ARG KUBECTL_VERSION=

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" \
      | tar -xz -C /tmp \
 && install -m 0755 "/tmp/linux-${TARGETARCH}/helm" /usr/local/bin/helm \
 && rm -rf "/tmp/linux-${TARGETARCH}"

RUN KV="${KUBECTL_VERSION:-$(curl -fsSL https://dl.k8s.io/release/stable.txt)}" \
 && curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KV}/bin/linux/${TARGETARCH}/kubectl" \
 && chmod 0755 /usr/local/bin/kubectl

# Named volumes copy ownership from the image, so these stay writable by runner.
# ~/.kube too: kubectl writes its discovery cache next to the mounted config.
RUN mkdir -p /runner-state /home/runner/_work /home/runner/.kube \
 && chown runner:runner /runner-state /home/runner/_work /home/runner/.kube

USER runner
# Fail the build (not the first deploy) if a tool is missing.
RUN helm version --short && kubectl version --client

COPY --chmod=755 entrypoint.sh /usr/local/bin/runner-entrypoint.sh
WORKDIR /home/runner
ENTRYPOINT ["/usr/local/bin/runner-entrypoint.sh"]
