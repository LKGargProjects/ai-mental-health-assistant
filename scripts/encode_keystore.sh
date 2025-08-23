#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/encode_keystore.sh path/to/upload-keystore.jks
# Outputs base64 to stdout. Copy this into GitHub Secret ANDROID_KEYSTORE_BASE64.

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <keystore_path>" >&2
  exit 1
fi

KS="$1"
if [[ ! -f "$KS" ]]; then
  echo "File not found: $KS" >&2
  exit 2
fi

# macOS and Linux compatible
base64 "$KS"
