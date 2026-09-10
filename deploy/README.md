# Deploy af OGraf Studio på hz02

Stakken kører i Portainer på Hetzner (hz02) bag den fælles caddy-docker-proxy
på netværket `proxy`. Domæne: `ograf-studio.hz02.tvmv.dk`. Basic auth med
bruger `tvmv` (hash i `docker-compose.yml`).

Baggrund og fravalgte alternativer: `dev_docs/ADR-0001-docker-deploy.md`.

## Filer

| Fil                                       | Formål                                                  |
| ----------------------------------------- | ------------------------------------------------------- |
| `docker-compose.yml`                      | Portainer-stack med Caddy-labels, volume og healthcheck |
| `.env.example`                            | Stack-variabler (kopiér ind i Portainer)                |
| `Dockerfile`                              | Henter upstreams Linux-binary og verificerer SHA256     |
| `entrypoint.sh`                           | socat-bro `0.0.0.0:8080 -> 127.0.0.1:4318` + server     |
| `../.github/workflows/release-docker.yml` | Bygger `ghcr.io/tvmidtvest/ograf-studio` ved tag        |

## Ny upstream-release

Imaget bygger ikke fra kilde. Det henter den færdige Linux-binary fra
upstream-releasen på `zerodensity/ograf-studio`. Proceduren for fx `v0.18`:

1. Kontrollér, at releasen findes upstream med Linux-assets:

   ```sh
   gh release view v0.18 --repo zerodensity/ograf-studio --json assets --jq '.assets[].name'
   ```

   Listen skal indeholde `OGrafStudioServer-linux-x64`, `OGrafStudioServer-linux-arm64`
   og `SHA256SUMS.txt`.

2. Sæt et fork-eget tag på forkens `main` og push det:

   ```sh
   git fetch fork
   git tag docker-v0.18 fork/main
   git push fork docker-v0.18
   ```

   Tag-navnet styrer versionen: `docker-v0.18` giver `OGRAF_VERSION=v0.18` og
   image-tags `0.18`, `sha-<commit>` og `latest`.

3. Følg builden:

   ```sh
   gh run list --repo tvmidtvest/ograf-studio --workflow release-docker.yml --limit 1
   ```

4. Opdatér stacken i Portainer. Sæt `IMAGE_TAG=0.18` i stack-variablerne og
   klik "Update the stack" med "Re-pull image". Hvis secret `PORTAINER_WEBHOOK`
   er sat i forken, kalder workflow'et webhook'en automatisk.

5. Verificér: `https://ograf-studio.hz02.tvmv.dk/health` svarer `{"ok":true,...}`
   efter login.

### Hvorfor ikke upstreams eget tag

GitHub læser workflow-filer fra den commit, et tag peger på. Upstreams tags
(`v0.18`) peger på commits uden `release-docker.yml` og `deploy/`, så et push
af dem starter intet. Derfor bruges præfikset `docker-v` på forkens `main`.

### Manuel build uden tag

Workflow'et kan også startes manuelt med en upstream-version:

```sh
gh workflow run release-docker.yml --repo tvmidtvest/ograf-studio --ref main -f ograf_version=v0.18
```

Det giver de samme image-tags som et tag-push.

## Synk af forken med upstream

Deploy-filerne ligger kun i forken. Hent upstreams ændringer ind i forkens
`main` uden at miste dem:

```sh
git fetch origin
git checkout main
git merge origin/main
git push fork main
```

`origin` er `zerodensity/ograf-studio` (kun læseadgang), `fork` er
`tvmidtvest/ograf-studio`.

## Skift password

Kun bcrypt-hashen ligger i repoet. Ny hash:

```sh
docker run --rm caddy:2 caddy hash-password --plaintext '<nyt password>'
```

Indsæt hashen i labelen `caddy.basic_auth.tvmv` i `docker-compose.yml`, og
erstat hvert `$` med `$$`. Redeploy stakken.

## Kendte krav

- Labelen `basic_auth` kræver Caddy 2.8 eller nyere. På ældre Caddy skal den
  hedde `basicauth`.
- Basic auth dækker også `/mcp`. MCP-klienter skal sende en
  `Authorization: Basic <base64(tvmv:password)>`-header.
- GHCR-pakken er privat. Portainer på hz02 skal have GHCR-credentials
  (samme som for vinklr).
