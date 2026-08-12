# Deployment notes — this VPS

Deploy/redeploy steps for Cashevide (and future projects) on this
VPS. Lives here, not in cashevide-api, because it's about this
machine, not the Django app.

## Fresh VPS — one-time setup

1. Clone this repo:

    git clone <https://github.com/cashevide/cashevide-vps-infra.git>
    cd cashevide-vps-infra

2. Create the shared static-files dir:

    sudo mkdir -p /srv/static-files/cashevide

3. Get the Cloudflare origin cert for api.cashevide.com (Cloudflare
    dashboard → SSL/TLS → Origin Server), place it:

        cashevide-vps-infra/certs/cashevide.pem
        cashevide-vps-infra/certs/cashevide.key

4. Start nginx-proxy (also creates `proxy-network`):

    docker compose up -d

5. Clone Cashevide (sibling folder, not inside this repo):

    cd ..
    git clone <https://github.com/cashevide/cashevide-api.git>
    cd cashevide-api

6. Add `.env` (not in git — restore from backup or `.env.example`).

7. Start Cashevide:

    docker compose up -d --build

8. Create the admin superuser (one-time — entrypoint no longer does
    this automatically):

        docker compose exec web python manage.py createsuperuser

    Save the credentials in a password manager. Not stored anywhere
    else.

9. Reload nginx-proxy:

    cd ../cashevide-vps-infra
    docker compose exec nginx-proxy nginx -s reload

10. Check: <https://api.cashevide.com>

**Order matters:** infra must start before Cashevide (`proxy-network`
is external, Cashevide expects it to already exist). Static-files dir
must exist before `collectstatic` runs.

## Routine restart (day-to-day)

    cd cashevide-api
    docker compose down
    docker compose up -d --build

No need to touch cashevide-vps-infra. Superuser is untouched — old
login still works.

## When to touch cashevide-vps-infra

| Situation                          | Action                                                                               |
| ---------------------------------- | ------------------------------------------------------------------------------------ |
| Domain/port/container name changed | Edit `conf.d/cashevide.conf`, then `docker compose exec nginx-proxy nginx -s reload` |
| Cert renewed                       | Replace files in `certs/`, then reload as above                                      |
| nginx-proxy down after reboot      | `docker compose up -d` (should auto-restart, check `docker ps` if not)               |

## Restoring a database backup

Superuser is no longer auto-created, so a fresh restore won't hit the
old `users_user_pkey` conflict — **unless you already ran step 8** on
this instance. If so, clear it first:

    docker compose exec db psql -U <DB_USER> <DB_NAME> -c "DELETE FROM users_user;"

Then restore:

    cat backup.sql | docker compose exec -T db psql -U <DB_USER> <DB_NAME>

Expected harmless errors during restore (skip, not a failure):
`django_content_type`, `auth_permission`, `django_migrations` —
these are populated by migrations already. Real data (users, clients,
invoices) should restore clean.

## Disaster recovery (VPS died)

1. "Fresh VPS — one-time setup" above, full sequence.
2. Restore DB backup if you have one (see above).
3. Certs aren't in git — re-download from Cloudflare.
4. Everything else comes back from git as-is.

## Sanity checks

    docker ps                          # nginx-proxy + cashevide-web/db/redis all "Up"
    docker network ls | grep proxy     # proxy-network exists
    ls /srv/static-files/cashevide     # staticfiles present
    curl -I https://api.cashevide.com  # real response, not connection refused
