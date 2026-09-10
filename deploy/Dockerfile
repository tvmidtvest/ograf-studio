# syntax=docker/dockerfile:1
#
# OGraf Studio standalone server til Hetzner/Portainer bag Caddy.
# Bygges og pushes til GHCR af .github/workflows/release-docker.yml.
#
# Imaget bygger IKKE fra kilde. Det henter den officielle Linux-binary fra
# upstream-releasen (zerodensity/ograf-studio) og verificerer SHA256 mod
# releasens SHA256SUMS.txt. Byg-kontekst er kun deploy/-mappen.
#
# Serveren binder kun til 127.0.0.1 (bevidst upstream-valg), og WebSocket-
# broen (/editor) accepterer kun forbindelser fra loopback. Derfor kører en
# socat-bro i samme container: 0.0.0.0:8080 -> 127.0.0.1:4318. Caddy taler
# til 8080. Se dev_docs/ADR-0001-docker-deploy.md.

FROM debian:bookworm-slim

# Upstream release-tag, fx v0.17. Sættes af workflow'et ud fra git-tag.
ARG OGRAF_VERSION=v0.17
# Sættes automatisk af buildx (amd64 / arm64).
ARG TARGETARCH

ENV TZ=Europe/Copenhagen

# ca-certificates + curl: download og healthcheck. socat: netværksbro.
# tzdata: TZ=Europe/Copenhagen kan resolves.
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl socat tzdata \
  && rm -rf /var/lib/apt/lists/*

RUN set -eu; \
  case "$TARGETARCH" in \
    amd64) asset=OGrafStudioServer-linux-x64 ;; \
    arm64) asset=OGrafStudioServer-linux-arm64 ;; \
    *) echo "Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
  esac; \
  base="https://github.com/zerodensity/ograf-studio/releases/download/${OGRAF_VERSION}"; \
  curl -fsSL --retry 3 -o /tmp/SHA256SUMS.txt "${base}/SHA256SUMS.txt"; \
  curl -fsSL --retry 3 -o /usr/local/bin/ograf-studio-server "${base}/${asset}"; \
  expected=$(awk -v f="$asset" '$2 == f { print $1 }' /tmp/SHA256SUMS.txt); \
  test -n "$expected"; \
  echo "${expected}  /usr/local/bin/ograf-studio-server" | sha256sum -c -; \
  chmod 0755 /usr/local/bin/ograf-studio-server; \
  rm -f /tmp/SHA256SUMS.txt

RUN groupadd --system --gid 1001 ograf \
  && useradd --system --uid 1001 --gid ograf --home-dir /data --shell /usr/sbin/nologin ograf \
  && mkdir -p /data/workspace \
  && chown -R ograf:ograf /data

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER ograf
WORKDIR /data

# OGRAF_MCP_PORT: serverens interne port (127.0.0.1). OGRAF_LISTEN_PORT: den
# port socat udstiller på 0.0.0.0, som Caddy taler til.
ENV OGRAF_WORKSPACE_ROOT=/data/workspace \
  OGRAF_MCP_PORT=4318 \
  OGRAF_LISTEN_PORT=8080

VOLUME ["/data/workspace"]
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
