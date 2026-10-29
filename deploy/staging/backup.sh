#!/usr/bin/env bash
# Nightly copy of the staging database, kept on the VPS for 14 days.
# Installed as /opt/nyaya-v2/backup.sh by deploy.sh; run by /etc/cron.d/nyaya-v2-backup.
#
# Restore a copy (replaces everything in the staging database):
#   cd /opt/nyaya-v2 && docker compose stop api cms
#   gunzip -c backups/nyaya-YYYY-MM-DD-HHMM.sql.gz | docker compose exec -T db psql -U nyaya -d nyaya -v ON_ERROR_STOP=1
#   docker compose start api cms
set -euo pipefail
# Copies hold password hashes: readable by root only.
umask 077
cd /opt/nyaya-v2
mkdir -p backups
out="backups/nyaya-$(date -u +%F-%H%M).sql.gz"
# A failed copy leaves no partial file behind.
trap 'rm -f "$out.tmp"' ERR
# --clean --if-exists: the copy drops and recreates each table, so a restore
# replaces the current data instead of clashing with it.
docker compose exec -T db pg_dump -U nyaya -d nyaya --clean --if-exists | gzip > "$out.tmp"
mv "$out.tmp" "$out"
find backups -name 'nyaya-*.sql.gz' -mtime +14 -delete
echo "$(date -u +%FT%TZ) saved $out ($(du -h "$out" | cut -f1))"
