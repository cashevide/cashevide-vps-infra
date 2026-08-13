# vps-infra-template

Reusable nginx reverse-proxy for hosting **multiple Dockerized
projects** on one VPS, sharing one pair of ports (80/443).

## How this works

A VPS can only bind port 80/443 to ONE process. This repo runs one
nginx container (`nginx-proxy`) that owns those ports. Every other
project runs WITHOUT its own nginx, WITHOUT its own host port — it
joins a shared Docker network, and `nginx-proxy` routes by domain
name.

**One repo instance = one whole VPS, not one project.** Adding a
second, third, tenth project doesn't mean a new template instance —
it means one more `.conf` file in `conf.d/`.

```
1 project:              3 projects:
  conf.d/                 conf.d/
    cashevide.conf           cashevide.conf
                              fastapi-project.conf
                              express-project.conf
```

nginx auto-loads every `*.conf` in `conf.d/` — no central list, no
edits elsewhere. Each file's `server_name` keeps them from colliding.

New instance only when you provision a genuinely new VPS — use
"Use this template" on GitHub for `vps2-infra`, etc.

## Folder structure

- `docker-compose.yml` — nginx-proxy (starts once, stays up)
- `conf.d/` — real per-project configs (tracked in git)
- `conf.d.example/` — sample config to copy per new project
- `certs/` — real SSL certs (gitignored)

## First-time setup

1. Clone onto the VPS as `vps-infra` (or `vpsN-infra`).
2. Start nginx-proxy (also creates the shared network):

   ```bash
   docker compose up -d
   ```

3. Add projects — see below.

## Adding a project (once per project, not once per VPS)

1. Project's own `docker-compose.yml`: no port 80/443, no own nginx
   service — just expose the app container on the shared network.

2. Join the network — in the project's `docker-compose.yml`:

   ```yaml
   networks:
     proxy-network:
       external: true
   ```

3. Copy the sample config:

   ```bash
   cp conf.d.example/example-project.conf.sample conf.d/<projectname>.conf
   ```

4. Fill in `<PLACEHOLDER>`s:
   - `<PROJECT_NAME>` — short id, e.g. `cashevide`
   - `<PROJECT_CONTAINER_NAME>` — match the container_name (or
     Compose default: `<COMPOSE_PROJECT_NAME>-<service>`)
   - `<INTERNAL_PORT>` — e.g. `8000`
   - `<YOUR_DOMAIN>` — e.g. `api.cashevide.com`

5. SSL cert + key for that domain → `certs/`.

6. Serving static files locally? See "Static files" below.

7. Reload (no downtime for other projects):

   ```bash
   docker compose exec nginx-proxy nginx -s reload
   ```

## conf.d/ is tracked — certs/ is not

`conf.d/*.conf` has domains and container names, not secrets — it's
committed so a VPS crash doesn't lose routing config. `certs/*` stays
gitignored; keys are real secrets, re-download fresh instead.

## Static files

nginx-proxy serves static files (e.g. Django Admin assets) from a
shared host path — not through media/S3. One generic mount:

```
/srv/static-files  →  /usr/share/nginx/static
```

Each project bind-mounts its own subfolder in its OWN compose file:

```yaml
volumes:
  - /srv/static-files/<projectname>:/app/staticfiles
```

Reference it in that project's `conf.d/<projectname>.conf`:

```nginx
location /static/ {
    alias /usr/share/nginx/static/<projectname>/staticfiles/;
}
```

This repo's docker-compose.yml never needs editing for a new project.

## Media files

Local media storage needs the same bind-mount + `/media/` pattern as
static files. S3/R2-backed media needs nothing here — the app's
MEDIA_URL points straight at the storage provider.

## Removing a project

Delete `conf.d/<projectname>.conf`, reload nginx-proxy. Done — other
projects unaffected.

## Moving to a new VPS

Tied to one machine. New VPS → "Use this template" on GitHub for a
fresh repo. Don't reuse `certs/` across machines — download fresh.

## See also

`DEPLOYMENT.md` — deploy sequence for this specific VPS.
