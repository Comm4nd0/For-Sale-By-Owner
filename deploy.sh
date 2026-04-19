#!/bin/bash
# Deploy script for For Sale By Owner
#
# Normal use:
#   ./deploy.sh                 # pull latest, back up DB, migrate, roll services
#
# Emergency rollback:
#   ./deploy.sh --rollback      # restore the most recent DB snapshot
#                               # (follow up with `git reset --hard <sha>` and
#                               # re-run ./deploy.sh to roll the code back too)
#
# Env overrides:
#   BACKUP_DIR   directory for DB snapshots (default /root/fsbo-backups)
#   HEALTH_URL   URL to poll for post-deploy readiness
#                (default http://localhost:8002/api/health/)

set -euo pipefail

COMPOSE="docker compose -f docker-compose.prod.yml"
BACKUP_DIR="${BACKUP_DIR:-/root/fsbo-backups}"
HEALTH_URL="${HEALTH_URL:-http://localhost:8002/api/health/}"
# Tiered retention: daily snapshots for 30 days, a selection of older ones
# (dated YYYYMMDD-000000 — add a cron to trim to weekly if desired) are kept
# for up to 90 days. Delete anything older than 90 days outright.
DAILY_RETENTION_DAYS=${DAILY_RETENTION_DAYS:-30}
EXTENDED_RETENTION_DAYS=${EXTENDED_RETENTION_DAYS:-90}

# DB credentials live inside the running db container's environment (docker-
# compose passes them in from .env). The pg_* commands below always use
# `sh -c` so $POSTGRES_USER / $POSTGRES_DB are expanded inside the container,
# which means we don't need to source .env on the host or duplicate defaults.

# ── Helpers ──────────────────────────────────────────────────────
die() { echo "❌ $*" >&2; exit 1; }

wait_for_db() {
  echo "⏳ Waiting for database to be healthy..."
  for _ in $(seq 1 30); do
    # pg_isready uses $POSTGRES_USER from inside the db container so it works
    # regardless of what role name .env actually configured.
    if $COMPOSE exec -T db sh -c 'pg_isready -U "$POSTGRES_USER"' >/dev/null 2>&1; then
      echo "✓ Database is ready."
      return 0
    fi
    sleep 1
  done
  die "Database did not become ready within 30s."
}

wait_for_web() {
  echo "⏳ Waiting for web to respond to $HEALTH_URL..."
  for _ in $(seq 1 30); do
    if curl -fs "$HEALTH_URL" >/dev/null 2>&1; then
      echo "✓ Web is responding."
      return 0
    fi
    sleep 2
  done
  echo "⚠️  Web did not respond within 60s — investigate with '$COMPOSE logs web'."
  return 1
}

wait_for_celery() {
  echo "⏳ Waiting for Celery worker to respond to ping..."
  for _ in $(seq 1 15); do
    if $COMPOSE exec -T celery sh -c 'celery -A fsbo_backend inspect ping -t 3' \
        >/dev/null 2>&1; then
      echo "✓ Celery is responding."
      return 0
    fi
    sleep 2
  done
  echo "⚠️  Celery did not respond within 30s — investigate with '$COMPOSE logs celery'."
  return 1
}

backup_database() {
  mkdir -p "$BACKUP_DIR"
  local ts
  ts=$(date +%Y%m%d-%H%M%S)
  local backup_file="$BACKUP_DIR/fsbo-${ts}.sql.gz"
  echo "💾 Backing up database to $backup_file..."
  # Use the container's own POSTGRES_USER / POSTGRES_DB so the role and db
  # name match what the postgres container was actually initialised with.
  $COMPOSE exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' \
    | gzip > "$backup_file"
  # Tiered retention:
  #   - Keep everything younger than $DAILY_RETENTION_DAYS (default 30d).
  #   - Between that and $EXTENDED_RETENTION_DAYS (default 90d), keep only
  #     Monday snapshots so we have weekly points.
  #   - Delete anything older than $EXTENDED_RETENTION_DAYS.
  find "$BACKUP_DIR" -name 'fsbo-*.sql.gz' -mtime "+$EXTENDED_RETENTION_DAYS" -delete 2>/dev/null || true
  find "$BACKUP_DIR" -name 'fsbo-*.sql.gz' -mtime "+$DAILY_RETENTION_DAYS" \
    ! -mtime "+$EXTENDED_RETENTION_DAYS" 2>/dev/null \
    | while read -r f; do
        # Strip 'fsbo-' prefix, take YYYYMMDD, use `date` to check weekday (1 = Monday).
        stamp=$(basename "$f" | sed -E 's/^fsbo-([0-9]{8})-.*/\1/')
        if [[ -n "$stamp" ]]; then
          dow=$(date -d "$stamp" +%u 2>/dev/null || echo 0)
          [[ "$dow" != "1" ]] && rm -f "$f"
        fi
      done
  echo "$backup_file" > "$BACKUP_DIR/latest-backup.path"
}

# Failure trap: if anything after the backup fails, point the operator at the
# snapshot so they can roll back the database. The code rollback is their call.
_deploy_stage="startup"
on_failure() {
  local rc=$?
  [[ $rc -eq 0 ]] && return
  echo ""
  echo "❌ Deploy failed during: $_deploy_stage (exit $rc)"
  if [[ -f "$BACKUP_DIR/latest-backup.path" ]]; then
    echo "   The pre-deploy DB snapshot is at:"
    echo "   $(cat "$BACKUP_DIR/latest-backup.path")"
    echo "   Restore with: ./deploy.sh --rollback"
  fi
}
trap on_failure EXIT

# ── Rollback path ─────────────────────────────────────────────────
if [[ "${1:-}" == "--rollback" ]]; then
  latest_backup=$(cat "$BACKUP_DIR/latest-backup.path" 2>/dev/null || true)
  [[ -f "$latest_backup" ]] || die "No backup found in $BACKUP_DIR."

  echo "⚠️  About to RESTORE the database from:"
  echo "   $latest_backup"
  echo "This will OVERWRITE the current database."
  read -r -p "Type 'yes' to continue: " confirm
  [[ "$confirm" == "yes" ]] || die "Aborted."

  echo "⏸  Stopping web and workers so writes pause..."
  $COMPOSE stop web celery celery-beat

  echo "⏪ Restoring from snapshot..."
  gunzip -c "$latest_backup" \
    | $COMPOSE exec -T db sh -c 'psql -U "$POSTGRES_USER" "$POSTGRES_DB"' \
      >/dev/null

  echo "▶️  Starting services back up..."
  $COMPOSE up -d web celery celery-beat
  wait_for_web || true

  echo ""
  echo "✅ Database restore complete."
  echo "   If the code is also rolled back, you're done."
  echo "   Otherwise: git reset --hard <sha> && ./deploy.sh"
  exit 0
fi

# ── Forward deploy path ───────────────────────────────────────────

# Confirm the branch we're pulling onto — git pull with no args uses the
# currently checked-out branch, which historically has caused surprises.
current_branch=$(git rev-parse --abbrev-ref HEAD)
echo "🌿 Currently on branch: $current_branch"
if [[ "$current_branch" != "main" && "$current_branch" != "development" ]]; then
  read -r -p "Not on main/development — continue? (yes/NO) " confirm
  [[ "$confirm" == "yes" ]] || die "Aborted."
fi

sha_before=$(git rev-parse --short HEAD)
echo "🔄 Pulling latest on $current_branch..."
git pull --ff-only
sha_after=$(git rev-parse --short HEAD)
if [[ "$sha_before" == "$sha_after" ]]; then
  echo "ℹ️  No new commits to deploy ($sha_after). Continuing anyway."
else
  echo "   $sha_before → $sha_after"
fi

# Make sure db/redis are up before we try to back up and migrate.
_deploy_stage="starting db/redis"
$COMPOSE up -d db redis
wait_for_db

# Back up BEFORE migrating so rollback is possible.
_deploy_stage="database backup"
backup_database

# Build new image. Rely on Docker's layer cache — --no-cache is slow and
# rarely needed; if deps change, requirements-prod.txt's content hash
# invalidates the layer and pip reinstalls.
_deploy_stage="image build"
echo "📦 Building new image..."
$COMPOSE build web

# Migrate with the NEW image in a one-shot container, BEFORE rolling web.
# This avoids serving new code against the old schema (or vice versa).
_deploy_stage="migrations"
echo "🗄️  Applying migrations with new image..."
$COMPOSE run --rm --no-deps --entrypoint "" web \
  python manage.py migrate --noinput

# Now roll web / celery / celery-beat to pick up the new image.
_deploy_stage="rolling services"
echo "🚀 Rolling services..."
$COMPOSE up -d --no-deps web celery celery-beat

_deploy_stage="health checks"
wait_for_web || true
wait_for_celery || true

_deploy_stage="done"
trap - EXIT
echo ""
echo "✅ Deploy complete: $(git rev-parse --short HEAD) on $current_branch."
echo "   Rollback: ./deploy.sh --rollback"
$COMPOSE ps
