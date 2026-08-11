# Deployment notes — this VPS

Quick reference for deploying/redeploying Cashevide (and future
projects) on this specific VPS. This file lives here (not in
cashevide-api) because it's about THIS machine's setup, not about
the Django app itself.

## One-time setup on a fresh VPS

Do this once, in this exact order, before anything else:

1. Clone this repo:

    git clone <https://github.com/noufalkdlr/cashevide-vps-infra.git>
    cd cashevide-vps-infra

2. Create the shared static-files directory (used by all projects,
    see README "Static files" section):

        sudo mkdir -p /srv/static-files/cashevide

3. Get the Cloudflare origin certificate for api.cashevide.com from
    the Cloudflare dashboard (SSL/TLS → Origin Server) and place it
    here:

        cashevide-vps-infra/certs/cashevide.pem
        cashevide-vps-infra/certs/cashevide.key

4. Start nginx-proxy (this also creates the shared `proxy-network`):

    docker compose up -d

5. Clone the Cashevide API repo (separately, alongside this one, not
    inside it):

        cd ..
        git clone https://github.com/cashevide/cashevide-api.git
        cd cashevide-api

6. Add the project's `.env` file (not in git — copy from wherever
    it's backed up, or recreate from `.env.example` if one exists).

7. Start Cashevide:

    docker compose up -d --build

8. Reload nginx-proxy so it picks up the route (only needed the very
    first time, or after editing conf.d/cashevide.conf):

        cd ../cashevide-vps-infra
        docker compose exec nginx-proxy nginx -s reload

9. Check it's live: <https://api.cashevide.com>

## Why the order matters

- `cashevide-vps-infra` must start FIRST — it creates `proxy-network`,
  which cashevide-api's docker-compose.yml expects to already exist
  (`external: true`). If you start cashevide-api first, it will fail
  with a "network not found" error.
- The static-files directory (step 2) must exist before Cashevide
  writes to it via `collectstatic`, and before nginx-proxy tries to
  read from it.

## Routine restarts / redeploys (day-to-day)

Once both are already set up, for ORDINARY restarts of Cashevide
alone (code changes, routine redeploy), you do NOT need to touch
cashevide-vps-infra at all — nginx-proxy keeps running independently:

    cd cashevide-api
    docker compose down
    docker compose up -d --build

This is safe on its own because `proxy-network` and
`/srv/static-files/cashevide` already exist from the one-time setup —
Cashevide just rejoins them.

## When you DO need to touch cashevide-vps-infra again

- **Changed the domain, port, or container name** → edit
  `conf.d/cashevide.conf`, then:

      docker compose exec nginx-proxy nginx -s reload

- **Renewed/replaced the SSL certificate** → replace the files in
  `certs/`, then reload nginx-proxy the same way.
- **nginx-proxy itself was stopped or the VPS rebooted and it didn't
  come back** → from `cashevide-vps-infra/`:

      docker compose up -d

  (`restart: unless-stopped` should normally bring it back
  automatically on reboot, but check with `docker ps` if in doubt.)

## Full disaster recovery (VPS died, starting from nothing)

1. Follow "One-time setup on a fresh VPS" above, start to finish.
2. Certs are the only thing not in git — re-download the origin
   certificate from Cloudflare's dashboard, it doesn't need the old
   VPS to still exist.
3. Everything else (nginx config, docker-compose files, Cashevide
   code) comes back from git exactly as it was.

## Quick sanity checks

    docker ps                          # nginx-proxy + cashevide-web/db/redis all "Up"
    docker network ls | grep proxy     # proxy-network exists
    ls /srv/static-files/cashevide     # staticfiles present after collectstatic runs
    curl -I https://api.cashevide.com  # should return a real HTTP response, not connection refused
