#!/usr/bin/env bash
# Builds and (re)starts Nyaya v2 staging on the VPS from this checkout.
#   ./deploy/staging/deploy.sh [--seed]
# --seed imports the starter questions (published as unreviewed staging data)
# and (re)creates the staff accounts with SEED_PASSWORD from the server's .env.
set -euo pipefail
HOST=${NYAYA_STAGING_HOST:-root@200.141.13.65}
DIR=/opt/nyaya-v2
cd "$(git rev-parse --show-toplevel)"

rsync -az --delete --exclude node_modules --exclude dist --exclude .next \
  --exclude .data --exclude .env --exclude '*.tsbuildinfo' backend cms "$HOST:$DIR/"
rsync -az deploy/staging/docker-compose.yml "$HOST:$DIR/"
rsync -az deploy/staging/nginx.conf "$HOST:/opt/yercaud/nginx/user_conf.d/nyaya-v2-staging.conf"

ssh "$HOST" "DIR=$DIR SEED=${1:-}" bash -s <<'REMOTE'
set -euo pipefail
cd "$DIR"
# Secrets are made once on the server and stay there.
if [ ! -f .env ]; then
  umask 077
  {
    echo "POSTGRES_PASSWORD=$(openssl rand -hex 24)"
    echo "JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n')"
    echo "SEED_PASSWORD=$(openssl rand -base64 18 | tr -d '\n/+=')"
  } > .env
fi
docker compose up -d --build
if [ "$SEED" = "--seed" ]; then
  docker compose exec -T -e SEED_PUBLISH_IMPORTED=true api node dist/db/seed.js
fi
# nginx-certbot: HUP makes certificates for new server names (placeholder ones
# first, so nginx can load) and reloads nginx.
docker kill --signal=HUP yercaud-nginx-1 >/dev/null
docker compose ps
REMOTE
