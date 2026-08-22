#!/bin/bash
# =====================================================
# Stupix Boot-Init Script
# Clones the Stupix repo and runs auto.sh
# =====================================================

REPO="https://github.com/Maxsander123/stupix"
TARGET="/opt/stupix"
LOG_DIR="/var/log/stupix"
LOG="$LOG_DIR/init.log"

mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [init] $*" | tee -a "$LOG"
}

log "=== Stupix Init started ==="
log "Log directory: $LOG_DIR"

# Wait for network interface
log "Waiting for network interface..."
for i in $(seq 1 30); do
    if ip addr show | grep -q "inet [0-9]" 2>/dev/null; then
        log "Network interface is up."
        break
    fi
    sleep 2
done

# Wait for internet connectivity
log "Waiting for internet connectivity (github.com)..."
for i in $(seq 1 20); do
    if curl -s --max-time 5 https://github.com > /dev/null 2>&1; then
        log "Internet reachable."
        break
    fi
    log "Attempt $i/20 - retrying in 3s..."
    sleep 3
done

# Log current IP addresses
log "Current IP addresses:"
ip -4 addr show | grep "inet " | tee -a "$LOG"

# Git clone
log "Cloning repository: $REPO"
if git clone --depth=1 "$REPO" "$TARGET" >> "$LOG" 2>&1; then
    log "Repository cloned to $TARGET"
else
    log "ERROR: git clone failed. Check $LOG for details."
    exit 1
fi

# Run auto.sh
if [ -f "$TARGET/auto.sh" ]; then
    log "Running auto.sh..."
    chmod +x "$TARGET/auto.sh"
    bash "$TARGET/auto.sh"
    log "auto.sh finished."
else
    log "WARNING: auto.sh not found in repository."
fi

log "=== Stupix Init complete ==="
