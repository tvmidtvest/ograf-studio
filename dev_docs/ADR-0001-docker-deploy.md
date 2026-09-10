# ADR-0001: Docker-deploy af OGraf Studio bag Caddy med socat-bro

Dato: 2026-09-10
Status: Accepteret

## Kontekst

OGraf Studio skal køre på Hetzner (hz02) i Portainer bag den fælles
caddy-docker-proxy på `proxy`-netværket, ligesom vinklr og retsinfo.
Domæne: `ograf-studio.hz02.tvmv.dk`, beskyttet med HTTP basic auth.

Upstream (zerodensity/ograf-studio) udgiver færdige standalone-binaries
(Bun-kompileret) pr. release, men intet Docker-image. Tre egenskaber i
upstream-koden styrer designet:

1. `standalone.ts` lytter kun på `127.0.0.1`. Der findes ingen `--host`-option,
   og dokumentationen beskriver det som bevidst.
2. `EditorBridge` (WebSocket på `/editor`) afviser forbindelser, hvis
   `socket.remoteAddress` ikke er loopback.
3. `localhostHostValidation()` fra MCP-SDK'et afviser alle requests, hvis
   `Host`-headerens hostname ikke er `localhost`, `127.0.0.1` eller `[::1]`.

Vi har kun læseadgang til upstream-repoet.

## Beslutning

- **Fork + GHCR.** Deploy-filer og workflow ligger i en fork under
  `tvmidtvest`. Workflow'et bygger `ghcr.io/tvmidtvest/ograf-studio` ved
  git-tag `v*`, samme mønster som vinklr/retsinfo.
- **Ingen build fra kilde.** Dockerfilen henter upstream-releasens
  Linux-binary (x64/arm64) for samme tag og verificerer SHA256 mod releasens
  `SHA256SUMS.txt`. Imaget følger dermed upstreams egne release-tjek.
- **socat-bro i containeren.** `socat` lytter på `0.0.0.0:8080` og åbner en ny
  loopback-forbindelse til `127.0.0.1:4318` pr. klient. Det opfylder både
  bind-kravet (1) og loopback-kravet i WebSocket-broen (2) uden at røre
  upstream-koden.
- **Caddy omskriver Host.** Label `caddy.reverse_proxy.header_up: Host 127.0.0.1`
  gør, at Host-valideringen (3) accepterer requests via proxyen.
- **Basic auth i Caddy** via label `caddy.basic_auth.tvmv: <bcrypt>`. Hashen
  ligger i compose-filen; passwordet ligger ingen steder i repoet.
- **Workspace i named volume** (`/data/workspace`, `OGRAF_WORKSPACE_ROOT`).

## Fravalgte alternativer

- **Patch upstream til `--host 0.0.0.0`.** Kræver vedligehold af en kodefork,
  og løser ikke loopback-tjekket i WebSocket-broen, som så også skulle patches.
- **Portainer bygger fra git.** Slipper for GHCR, men afviger fra de andre
  stacks og giver ingen pinnede, verificerbare images.
- **Undtag `/mcp` fra basic auth.** Ville give uautentificeret skriveadgang
  til workspace. MCP-klienter sender i stedet en `Authorization: Basic`-header.

## Konsekvenser

- Basic auth dækker også `/mcp` og `/editor`-websocket. Browseren genbruger
  credentials på websocket-handshaket, så editoren virker uden ekstra opsætning.
  MCP-klienter (fx Claude Code) skal konfigureres med en Basic-header.
- Labelen `basic_auth` kræver Caddy >= 2.8. På ældre Caddy hedder direktivet
  `basicauth`.
- Ny upstream-version deployes ved at pushe upstream-tagget til forken;
  workflow'et bygger image med samme versionsnummer.
- Healthchecket går gennem socat-porten, så en død bro opdages.
