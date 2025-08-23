#!/usr/bin/env bash
set -euo pipefail

# One-command IPA build for Flutter module at ai_buddy_web/
# Signing modes supported:
#  - Automatic signing via Xcode (default). Provide APPLE_TEAM_ID to hint team.
#  - Optional explicit provisioning profile via IOS_PROVISIONING_PROFILE_SPECIFIER + IOS_BUNDLE_ID.
# Export method is controlled by IOS_EXPORT_METHOD (app-store | ad-hoc | development | enterprise).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IOS_DIR="$PROJECT_ROOT/ai_buddy_web/ios"
FLUTTER_ROOT_DIR="$PROJECT_ROOT/ai_buddy_web"

# Optionally source signing env vars from scripts/ios_signing.env
SIGNING_ENV_FILE="$PROJECT_ROOT/scripts/ios_signing.env"
if [[ -f "$SIGNING_ENV_FILE" ]]; then
  echo "[release_ios_ipa] Sourcing signing env: $SIGNING_ENV_FILE"
  # shellcheck source=/dev/null
  source "$SIGNING_ENV_FILE"
fi

cd "$FLUTTER_ROOT_DIR"

METHOD="${IOS_EXPORT_METHOD:-ad-hoc}"   # app-store | ad-hoc | development | enterprise
TEAM_ID="${APPLE_TEAM_ID:-}"
BUNDLE_ID="${IOS_BUNDLE_ID:-}"
PROV_SPEC="${IOS_PROVISIONING_PROFILE_SPECIFIER:-}"

TMP_PLIST="$(mktemp -t exportOptions.plist.XXXXXX)"
cat > "$TMP_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>${METHOD}</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>compileBitcode</key>
  <false/>
EOF
if [[ -n "$TEAM_ID" ]]; then
  echo "  <key>teamID</key>" >> "$TMP_PLIST"
  echo "  <string>$TEAM_ID</string>" >> "$TMP_PLIST"
fi
if [[ -n "$BUNDLE_ID" && -n "$PROV_SPEC" ]]; then
  cat >> "$TMP_PLIST" <<EOI
  <key>provisioningProfiles</key>
  <dict>
    <key>${BUNDLE_ID}</key>
    <string>${PROV_SPEC}</string>
  </dict>
EOI
fi
echo "</dict></plist>" >> "$TMP_PLIST"

echo "[release_ios_ipa] Using export method: $METHOD"

echo "[release_ios_ipa] Building IPA via Flutter..."
flutter build ipa --release --no-tree-shake-icons --export-options-plist "$TMP_PLIST"

echo "[release_ios_ipa] Build finished. Locating IPA..."
CANDIDATES=(
  "$FLUTTER_ROOT_DIR/build/ios/ipa"
  "$IOS_DIR/build/ipa"
)
FOUND=""
for d in "${CANDIDATES[@]}"; do
  if [[ -d "$d" ]]; then
    f=$(find "$d" -type f -name "*.ipa" -print -quit || true)
    if [[ -n "$f" ]]; then FOUND="$f"; break; fi
  fi
done
if [[ -z "$FOUND" ]]; then
  FOUND=$(find "$FLUTTER_ROOT_DIR" -type f -name "*.ipa" -print -quit || true)
fi

if [[ -n "$FOUND" && -f "$FOUND" ]]; then
  echo "[release_ios_ipa] IPA: $FOUND"
  ls -lh "$FOUND"
else
  echo "[release_ios_ipa] ERROR: IPA not found. Check Flutter/Xcode output above."
  exit 2
fi
