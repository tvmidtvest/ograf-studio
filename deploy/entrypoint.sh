#!/bin/sh
# Starter socat-broen i baggrunden og OGraf Studio-serveren i forgrunden.
#
# Serveren lytter kun på 127.0.0.1:$OGRAF_MCP_PORT, og WebSocket-broen kræver
# loopback som kilde-adresse. socat lytter på 0.0.0.0:$OGRAF_LISTEN_PORT og
# åbner en ny loopback-forbindelse pr. klient, så begge krav er opfyldt.
#
# exec gør serveren til PID 1 (via sh-exec), så SIGTERM fra Docker rammer den
# direkte og containeren stopper pænt. Dør serveren, dør containeren, og
# restart-politikken starter den igen. Dør socat alene, fejler healthchecket
# (det går gennem $OGRAF_LISTEN_PORT), og Portainer/Docker kan reagere.
set -eu

: "${OGRAF_MCP_PORT:=4318}"
: "${OGRAF_LISTEN_PORT:=8080}"
: "${OGRAF_WORKSPACE_ROOT:=/data/workspace}"

socat "TCP-LISTEN:${OGRAF_LISTEN_PORT},fork,reuseaddr" "TCP:127.0.0.1:${OGRAF_MCP_PORT}" &

exec /usr/local/bin/ograf-studio-server \
  --port "${OGRAF_MCP_PORT}" \
  --workspace "${OGRAF_WORKSPACE_ROOT}" \
  --no-open
