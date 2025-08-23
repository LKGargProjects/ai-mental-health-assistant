#!/usr/bin/env bash
set -euo pipefail

# One-command Play Store AAB build for Flutter module at ai_buddy_web/
# Supports two signing modes:
#  1) File-based:  ai_buddy_web/android/key.properties (preferred for local)
#  2) Env-based:   STORE_FILE, STORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD
# Falls back to debug signing if none provided.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANDROID_DIR="$PROJECT_ROOT/ai_buddy_web/android"
FLUTTER_ROOT_DIR="$PROJECT_ROOT/ai_buddy_web"

# Optionally source signing env vars from scripts/android_signing.env
SIGNING_ENV_FILE="$PROJECT_ROOT/scripts/android_signing.env"
if [[ -f "$SIGNING_ENV_FILE" ]]; then
  echo "[release_android_aab] Sourcing signing env: $SIGNING_ENV_FILE"
  # shellcheck source=/dev/null
  source "$SIGNING_ENV_FILE"
fi

cd "$ANDROID_DIR"

MODE="debug-fallback"
if [[ -f "$ANDROID_DIR/key.properties" ]]; then
  MODE="key.properties"
elif [[ -n "${STORE_FILE:-}" || -n "${STORE_PASSWORD:-}" || -n "${KEY_ALIAS:-}" || -n "${KEY_PASSWORD:-}" ]]; then
  MODE="env-vars"
fi

echo "[release_android_aab] Using signing mode: $MODE"
if [[ "$MODE" == "debug-fallback" ]]; then
  echo "[release_android_aab] WARNING: No signing credentials found. Building with debug signing (installable, not Play-ready)."
fi

# Build the app bundle via Gradle (more robust on systems without Android cmdline-tools for Flutter)
./gradlew :app:bundleRelease --no-daemon

echo "[release_android_aab] Build finished. Locating AAB..."
# Try common locations
CANDIDATES=(
  "$FLUTTER_ROOT_DIR/build/app/outputs/bundle/release/app-release.aab"
  "$ANDROID_DIR/app/build/outputs/bundle/release/app-release.aab"
  "$FLUTTER_ROOT_DIR/build/outputs/bundle/release/app-release.aab"
)

FOUND=""
for p in "${CANDIDATES[@]}"; do
  if [[ -f "$p" ]]; then
    FOUND="$p"
    break
  fi
done

if [[ -z "$FOUND" ]]; then
  echo "[release_android_aab] AAB not found in common locations. Scanning..."
  FOUND=$(find "$PROJECT_ROOT/ai_buddy_web" -type f -name "*.aab" -print -quit || true)
fi

if [[ -n "$FOUND" && -f "$FOUND" ]]; then
  echo "[release_android_aab] AAB: $FOUND"
  ls -lh "$FOUND"
else
  echo "[release_android_aab] ERROR: app-release.aab not found. Check Gradle output above for details."
  exit 2
fi
