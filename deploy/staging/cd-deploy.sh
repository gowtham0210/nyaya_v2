#!/usr/bin/env bash
# Server side of .github/workflows/deploy-staging.yml. Installed once by hand as
# /opt/nyaya-v2/cd-deploy.sh (root, 700) and tied to GitHub's key in
# /root/.ssh/authorized_keys:
#   command="/opt/nyaya-v2/cd-deploy.sh",restrict ssh-ed25519 AAAA... github-nyaya-v2-staging
# so that key can run only this. The commit to deploy arrives as the SSH
# command, the GHCR token (valid only while the GitHub job runs) on stdin.
set -euo pipefail

REPO=gowtham0210/nyaya_v2
OWNER=gowtham0210
DIR=/opt/nyaya-v2

SHA=${SSH_ORIGINAL_COMMAND:-}
if ! [[ $SHA =~ ^[0-9a-f]{40}$ ]]; then
  echo "expected a full commit id" >&2
  exit 2
fi
IFS= read -r TOKEN || true
[ -n "${TOKEN:-}" ] || { echo "no registry token on stdin" >&2; exit 2; }

cd "$DIR"
# One deploy at a time, also against a hand-run deploy.sh started meanwhile.
exec 9>"$DIR/.deploy.lock"
flock -w 600 9

work=$(mktemp -d)
# A separate Docker login, so root's own GHCR login (other projects) is untouched.
export DOCKER_CONFIG="$work/docker"
trap 'rm -rf "$work"' EXIT

# Config files from that exact commit (the repository is public).
raw="https://raw.githubusercontent.com/$REPO/$SHA/deploy/staging"
for f in docker-compose.yml nginx.conf backup.sh backup.cron; do
  curl -fsSL --retry 3 "$raw/$f" -o "$work/$f"
done

echo "== backup"
./backup.sh

echo "== pull $SHA"
printf '%s\n' "$TOKEN" | docker login ghcr.io -u "$OWNER" --password-stdin >/dev/null
# Pulled with the new compose file before anything here changes: if the pull
# fails, the server keeps its old files and IMAGE_TAG, and still runs as before.
IMAGE_TAG=$SHA docker compose -f "$work/docker-compose.yml" --project-directory "$DIR" \
  pull api cms
install -m 644 "$work/docker-compose.yml" docker-compose.yml
install -m 755 "$work/backup.sh" backup.sh
install -m 644 "$work/backup.cron" /etc/cron.d/nyaya-v2-backup
install -m 644 "$work/nginx.conf" /opt/yercaud/nginx/user_conf.d/nyaya-v2-staging.conf
# Manual docker compose commands later use the same images.
sed -i '/^IMAGE_TAG=/d' .env
echo "IMAGE_TAG=$SHA" >> .env

echo "== start"
# A recreate once failed with a container name clash although the new
# containers started; one retry settles that.
docker compose up -d --no-build api cms ||
  { sleep 5; docker compose up -d --no-build api cms; }
# nginx-certbot: certificates for new names, then reload.
docker kill --signal=HUP yercaud-nginx-1 >/dev/null

for c in nyaya-v2-api nyaya-v2-cms; do
  image=$(docker inspect -f '{{.Config.Image}}' "$c")
  case "$image" in
    *":$SHA") ;;
    *) echo "$c runs $image, not $SHA" >&2; exit 1 ;;
  esac
done
docker compose ps
# Keep the last few images for going back; drop older ones.
for name in api cms; do
  docker image ls "ghcr.io/$OWNER/nyaya-v2-$name" --format '{{.Tag}}' |
    grep -v -e "^$SHA$" -e '^manual$' | tail -n +4 |
    xargs -r -I{} docker image rm "ghcr.io/$OWNER/nyaya-v2-$name:{}" >/dev/null || true
done
echo "== deployed $SHA"
