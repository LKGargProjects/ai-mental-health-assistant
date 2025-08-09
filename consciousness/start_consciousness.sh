#!/bin/bash
# Simple starter script for the consciousness system

# Configuration
CONSCIOUSNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$CONSCIOUSNESS_DIR/.consciousness"
LOG_DIR="$DATA_DIR/logs"
LOG_FILE="$LOG_DIR/consciousness_$(date +%Y%m%d_%H%M%S).log"

# Create necessary directories
mkdir -p "$DATA_DIR" "$LOG_DIR"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Start the system
log "Starting consciousness system..."
python3 "$CONSCIOUSNESS_DIR/bin/consciousness_cli.py" "$@" 2>&1 | tee -a "$LOG_FILE"

# Log completion
log "Consciousness system stopped."
