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
- `conf.d/` — Real per-project configs (gitignored, VPS-specific)
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
   - `<PROJECT_CONTAINER_NAME>` — must match the container_name in
     that project's docker-compose.yml
   - `<INTERNAL_PORT>` — the port the app listens on inside its own
     container (e.g. 8000)
   - `<YOUR_DOMAIN>` — e.g. api.cashevide.com

5. Place the SSL cert + key for that domain into `certs/`.

6. Reload nginx-proxy (no downtime for other projects):

       docker compose exec nginx-proxy nginx -s reload

## Removing a project

Delete its `conf.d/<projectname>.conf` file and reload nginx-proxy.
Other projects are unaffected.

## Moving to a new VPS

This repo is tied to ONE physical/virtual machine. For a new VPS,
click "Use this template" on GitHub to create a fresh, independent
repo (e.g. `vps2-infra`) — do not reuse this repo's `conf.d/` or
`certs/` content on a different machine.