# vps-infra-template

Reusable nginx reverse-proxy setup for hosting **multiple Dockerized
projects** on a single VPS, sharing one pair of ports (80/443).

## How this works

One VPS can only bind port 80 and port 443 to ONE process. This repo
sets up exactly one nginx container (`nginx-proxy`) that owns those
ports. Every other project on the VPS runs WITHOUT its own nginx and
WITHOUT exposing any host port — it just joins a shared Docker
network, and `nginx-proxy` routes traffic to it based on domain name.

**This template is not "one project = one template use."**
One instance of this repo (e.g. `vps1-infra`) serves the WHOLE VPS —
however many projects live on it. Adding a second, third, or tenth
project does NOT mean creating a second `vps-infra` instance. It
means adding one more `.conf` file inside the same `conf.d/` folder.

Example — 1 project on this VPS:

    conf.d/
      cashevide.conf

Example — 3 projects on this VPS:

    conf.d/
      cashevide.conf
      fastapi-project.conf
      express-project.conf

nginx automatically loads every `*.conf` file in `conf.d/` — there is
no central list to edit. Each file's own `server_name` (domain) is
what keeps them from conflicting with each other.

You only need a SECOND instance of this template when you provision
a SECOND VPS (a genuinely different machine). Use GitHub's
"Use this template" button to create `vps2-infra`, `vps3-infra`, etc.

## Folder structure

- `docker-compose.yml` — nginx-proxy container (starts once, stays up)
- `conf.d/` — Real per-project configs (tracked in git — see note below)
- `conf.d.example/` — Sample config to copy from, per new project
- `certs/` — Real SSL certs (gitignored, secrets)

## First-time setup on a fresh VPS

1. Clone this repo onto the VPS as `vps-infra` (or `vpsN-infra`).
2. Start the shared network + nginx-proxy:

   docker compose up -d

3. For each project you want to add, follow "Adding a new project"
   below.

## Adding a new project (do this once per project, not once per VPS)

1. Make sure the project's own `docker-compose.yml` does NOT publish
    port 80/443 and does NOT run its own nginx service. It should only
    expose its app container on the shared network (see notes in the
    project repo itself).

2. Join the project's container to this proxy's network. In the
    project's `docker-compose.yml`, add:

        networks:
          proxy-network:
            external: true

    and attach the app service to it.

3. Copy the sample config:

    cp conf.d.example/example-project.conf.sample conf.d/<projectname>.conf

4. Edit `conf.d/<projectname>.conf` and replace every `<PLACEHOLDER>`:
    - `<PROJECT_NAME>` — short id, e.g. `cashevide`
    - `<PROJECT_CONTAINER_NAME>` — must match the container_name (or
      the Compose-generated name: `<COMPOSE_PROJECT_NAME>-<service>`)
      of that project's docker-compose.yml
    - `<INTERNAL_PORT>` — the port the app listens on inside its own
      container (e.g. 8000)
    - `<YOUR_DOMAIN>` — e.g. api.cashevide.com

5. Place the SSL cert + key for that domain into `certs/`.

6. If the project serves static files locally (not via S3/R2), see
    "Static files" below.

7. Reload nginx-proxy (no downtime for other projects):

    docker compose exec nginx-proxy nginx -s reload

## conf.d/ is tracked in git — certs/ is not

Unlike `certs/`, the real per-project `.conf` files in `conf.d/` ARE
committed to this repo (once you create an instance from this
template and push real config to it). They contain domain names and
container names, not secrets — keeping them in git means a VPS crash
doesn't lose the routing config, only a fresh certificate re-download
from Cloudflare (or wherever certs come from) is needed.

Only `certs/*` stays gitignored, because certificate keys are
genuine secrets.

## Static files

nginx-proxy serves static files (e.g. Django Admin CSS/JS) directly
from a shared host directory — it does NOT go through media/S3
storage. This repo's docker-compose.yml mounts one generic path:

    /srv/static-files  →  /usr/share/nginx/static  (inside nginx-proxy)

Each project keeps its own subfolder under `/srv/static-files/<projectname>/`
by bind-mounting it in its OWN docker-compose.yml, e.g.:

    volumes:
      - /srv/static-files/<projectname>:/app/staticfiles

Then reference it in that project's conf.d/<projectname>.conf:

    location /static/ {
        alias /usr/share/nginx/static/<projectname>/staticfiles/;
    }

This repo's docker-compose.yml never needs editing when a new
project is added — only the project's own compose file and its
conf.d entry change.

## Media files

If a project stores media files locally rather than on S3/R2-style
object storage, that also needs a bind-mount + `/media/` location
following the same pattern as static files above. If a project uses
S3/R2 (or similar) for media, nginx never needs to handle `/media/`
for it at all — the app's own MEDIA_URL points straight at that
storage provider.

## Removing a project

Delete its `conf.d/<projectname>.conf` file and reload nginx-proxy.
Other projects are unaffected. If it had a static-files bind-mount in
its own docker-compose.yml, that goes away with that project's own
compose file — nothing to clean up here.

## Moving to a new VPS

This repo is tied to ONE physical/virtual machine. For a new VPS,
click "Use this template" on GitHub to create a fresh, independent
repo (e.g. `vps2-infra`) — do not reuse this repo's `certs/` content
on a different machine (download fresh certs instead).

## See also

`DEPLOYMENT.md` — step-by-step deploy sequence for this specific VPS
(fresh setup, routine redeploys, disaster recovery).
