#!/bin/bash
# =====================================================
# Stupix Boot-Init Script
# Clones the Stupix script repo and runs auto.sh.
# Repo URL and credentials are read from
# /etc/stupix/repo.conf (written at ISO build time).
# =====================================================

TARGET="/opt/stupix"
LOG_DIR="/var/log/stupix"
LOG="$LOG_DIR/init.log"

mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [init] $*" | tee -a "$LOG"; }

log "=== Stupix Init started ==="
log "Log: $LOG"

# ---- load build-time repo config ----
CONF="/etc/stupix/repo.conf"
if [ -f "$CONF" ]; then
    # shellcheck source=/dev/null
    source "$CONF"
    log "Repo config loaded from $CONF"
else
    log "WARNING: $CONF not found — using built-in defaults"
fi

REPO="${STUPIX_REPO:-https://github.com/Maxsander123/stupix}"
REPO_USER="${STUPIX_REPO_USER:-}"
REPO_TOKEN="${STUPIX_REPO_TOKEN:-}"

log "Repo: $REPO"
[ -n "$REPO_USER"  ] && log "Auth: user=${REPO_USER}, token=<set>"
[ -z "$REPO_USER" ] && [ -n "$REPO_TOKEN" ] && log "Auth: token=<set>"

# Build authenticated clone URL (token never appears in logs)
if [ -n "$REPO_TOKEN" ] && [ -n "$REPO_USER" ]; then
    # Gitea / GitLab / Forgejo style: https://user:token@host/path
    PROTO="${REPO%%://*}://"
    REST="${REPO#*://}"
    CLONE_URL="${PROTO}${REPO_USER}:${REPO_TOKEN}@${REST}"
elif [ -n "$REPO_TOKEN" ]; then
    # GitHub PAT style: https://token@github.com/path
    PROTO="${REPO%%://*}://"
    REST="${REPO#*://}"
    CLONE_URL="${PROTO}${REPO_TOKEN}@${REST}"
else
    CLONE_URL="$REPO"
fi

# Derive the host for connectivity check
REPO_HOST=$(echo "$REPO" | sed -E 's|^[a-z+]+://([^/:@]+).*|\1|')

# ---- wait for network ----
log "Waiting for network interface..."
for i in $(seq 1 30); do
    ip addr show | grep -q "inet [0-9]" 2>/dev/null && break
    sleep 2
done
log "Network interface is up."

# ---- wait for connectivity to repo host ----
log "Waiting for connectivity to ${REPO_HOST}..."
for i in $(seq 1 20); do
    if curl -s --max-time 5 "https://${REPO_HOST}" > /dev/null 2>&1; then
        log "Host ${REPO_HOST} reachable."
        break
    fi
    log "Attempt $i/20 — retrying in 3s..."
    sleep 3
done

log "Current IP addresses:"
ip -4 addr show | grep "inet " | tee -a "$LOG"

# ---- clone ----
log "Cloning repository: $REPO"
# Pass clone URL via GIT_ASKPASS trick so token never lands in ps output or logs
if GIT_TERMINAL_PROMPT=0 git clone --depth=1 "$CLONE_URL" "$TARGET" >> "$LOG" 2>&1; then
    log "Repository cloned to $TARGET"
else
    log "ERROR: git clone failed — check $LOG for details"
    exit 1
fi

# Scrub any token from the remote URL stored by git (it's in .git/config)
if [ -n "$REPO_TOKEN" ]; then
    git -C "$TARGET" remote set-url origin "$REPO" 2>/dev/null || true
fi

# ---- run auto.sh ----
if [ -f "$TARGET/auto.sh" ]; then
    log "Running $TARGET/auto.sh..."
    chmod +x "$TARGET/auto.sh"
    bash "$TARGET/auto.sh"
    log "auto.sh finished."
else
    log "WARNING: auto.sh not found in $TARGET"
fi

log "=== Stupix Init complete ==="
