#!/bin/sh
# Espial start script for Railway.
#  1. creates or migrates the SQLite database on the volume (/app/data)
#  2. creates the owner account from ESPIAL_USERNAME / ESPIAL_PASSWORD before the port opens
#  3. keeps a session key on the volume so logins survive redeploys
#  4. sizes the Haskell runtime to the CPUs Railway gives the service
#  5. runs Espial and exits non-zero if it stops, so Railway restarts it
set -eu

log() { echo "[espial-railway] $*"; }
die() { echo "[espial-railway] ERROR: $*" >&2; exit 1; }

DATA_DIR=/app/data
export SQLITE_DATABASE="${SQLITE_DATABASE:-$DATA_DIR/espial.sqlite3}"
mkdir -p "$(dirname "$SQLITE_DATABASE")"

# --- public URL ---------------------------------------------------------------
# Espial builds absolute links from APPROOT. Behind Railway's HTTPS proxy it would
# otherwise guess http://, which breaks the login form. Ignore an empty or bare
# "https://" value (a reference that resolved before the domain existed).
case "${APPROOT:-}" in
  http://?*|https://?*) ;;
  *)
    unset APPROOT
    if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
      export APPROOT="https://${RAILWAY_PUBLIC_DOMAIN}"
    fi
    ;;
esac
APPROOT="${APPROOT:-}"; APPROOT="${APPROOT%/}"
if [ -n "$APPROOT" ]; then export APPROOT; log "public URL: $APPROOT"; else unset APPROOT; log "no public domain yet: links follow the request host"; fi

# --- owner account ------------------------------------------------------------
USERNAME="${ESPIAL_USERNAME:-admin}"
PASSWORD="${ESPIAL_PASSWORD:-}"
[ -n "$USERNAME" ] || die "ESPIAL_USERNAME is empty"
case "$USERNAME" in *[!A-Za-z0-9_.-]*) die "ESPIAL_USERNAME may only use letters, digits, '.', '_' and '-'";; esac
[ "${#PASSWORD}" -ge 12 ] || die "ESPIAL_PASSWORD must be set and at least 12 characters long; refusing to start without an owner account"

log "migrating database $SQLITE_DATABASE"
./migration createdb --silent True >/tmp/migrate.log 2>&1 || { cat /tmp/migrate.log >&2; die "database migration failed"; }

user_exists() {
  # showuser prints '"<name> not found"' and exits 0 for a missing user; any other
  # failure (database error) must stop the start, not be read as "user exists".
  out="$(./migration showuser --userName "$USERNAME" 2>&1)" || { echo "$out" >&2; die "could not read the user table"; }
  case "$out" in *" not found"*) return 1;; esac
  return 0
}

if ! user_exists; then
  log "creating owner account '$USERNAME'"
  umask 077
  printf '%s' "$PASSWORD" > /tmp/.owner-pw
  ./migration createuser --userName "$USERNAME" --userPasswordFile /tmp/.owner-pw >/tmp/createuser.log 2>&1 \
    || { rm /tmp/.owner-pw; cat /tmp/createuser.log >&2; die "could not create the owner account"; }
  rm /tmp/.owner-pw
  user_exists || die "owner account '$USERNAME' is missing after createuser"
  log "owner account '$USERNAME' created"
else
  log "owner account '$USERNAME' already exists (its password is not changed on restart)"
fi

# --- session key --------------------------------------------------------------
if [ -z "${CLIENT_SESSION_KEY:-}" ]; then
  KEY_FILE="$DATA_DIR/client_session_key"
  if [ ! -s "$KEY_FILE" ]; then
    umask 077
    ./migration generatesessionkey | sed -n 's/^CLIENT_SESSION_KEY=//p' > "$KEY_FILE.tmp"
    [ -s "$KEY_FILE.tmp" ] || die "could not generate a session key"
    mv "$KEY_FILE.tmp" "$KEY_FILE"
    log "generated a session key in $KEY_FILE"
  fi
  CLIENT_SESSION_KEY="$(cat "$KEY_FILE")"
  export CLIENT_SESSION_KEY
fi

# --- runtime sizing -----------------------------------------------------------
# Railway shows the host's CPUs (32+) inside a 1 vCPU service; GHC's -N would start
# one capability per host CPU. Use the cgroup quota instead.
CPUS=2
if [ -r /sys/fs/cgroup/cpu.max ]; then
  read -r QUOTA PERIOD < /sys/fs/cgroup/cpu.max || true
  if [ "${QUOTA:-max}" != "max" ] && [ "${PERIOD:-0}" -gt 0 ] 2>/dev/null; then
    CPUS=$(( (QUOTA + PERIOD - 1) / PERIOD ))
  fi
fi
[ "$CPUS" -ge 1 ] || CPUS=1
[ "$CPUS" -le 4 ] || CPUS=4
CPUS="${ESPIAL_RTS_CPUS:-$CPUS}"
export SQLITE_POOLSIZE="${SQLITE_POOLSIZE:-5}"
log "starting Espial 0.0.42 on port ${PORT:-3000} with $CPUS runtime threads"

# Espial runs as a child so a crash or OOM kill makes this script exit non-zero
# (Railway's ON_FAILURE policy then restarts it), and SIGTERM is forwarded.
./espial +RTS -T "-N$CPUS" -A1m -RTS &
CHILD=$!
trap 'kill -TERM "$CHILD" 2>/dev/null' TERM INT
set +e
wait "$CHILD"; RC=$?
# A trapped signal interrupts the first wait; wait again for the real exit code.
if kill -0 "$CHILD" 2>/dev/null; then wait "$CHILD"; RC=$?; fi
log "Espial exited with code $RC"
[ "$RC" -eq 0 ] && RC=1
exit "$RC"
