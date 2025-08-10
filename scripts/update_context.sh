#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Generate single-file CONTEXT.md via the CLI
python3 consciousness/consciousness_cli.py context

# Print path for convenience
echo "Context updated at: $REPO_ROOT/CONTEXT.md"
