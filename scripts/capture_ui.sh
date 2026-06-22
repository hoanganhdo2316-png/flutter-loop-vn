#!/usr/bin/env bash
# Capture a screenshot (for the agent to visually inspect the UI) and dump the UI hierarchy
# (to get exact widget coordinates for navigation taps instead of estimating from the image).
set -uo pipefail

DEVICE_ID="$1"
NAME="$2"              # e.g. S2.3 or S2.3.1 — matches the code used in memory.md
SCREEN_DIR="${3:-screen_cap}"

mkdir -p "$SCREEN_DIR"

PNG="$SCREEN_DIR/${NAME}.png"
adb -s "$DEVICE_ID" exec-out screencap -p > "$PNG"

SAFE_NAME="${NAME//./_}"
XML_DEVICE="/sdcard/window_dump_${SAFE_NAME}.xml"
XML_LOCAL="$SCREEN_DIR/${NAME}_uidump.xml"

adb -s "$DEVICE_ID" shell uiautomator dump "$XML_DEVICE" >/dev/null 2>&1 || true
adb -s "$DEVICE_ID" pull "$XML_DEVICE" "$XML_LOCAL" >/dev/null 2>&1 || true
adb -s "$DEVICE_ID" shell rm -f "$XML_DEVICE" >/dev/null 2>&1 || true

# Count real nodes in the dump — an empty file or one with only 1–2 nodes means
# uiautomator could not see inside the Flutter app (usually because accessibility
# is not enabled — see preflight.sh). Do not treat this as a valid UI dump.
NODE_COUNT=0
if [ -s "$XML_LOCAL" ]; then
  NODE_COUNT=$(grep -o '<node' "$XML_LOCAL" | wc -l)
fi

echo "SCREENSHOT=$PNG"
if [ "$NODE_COUNT" -gt 1 ]; then
  echo "UIDUMP=$XML_LOCAL"
  echo "UIDUMP_NODES=$NODE_COUNT"
else
  echo "UIDUMP=FAILED"
  echo "⚠️  uiautomator dump returned no meaningful nodes (NODE_COUNT=$NODE_COUNT)."
  echo "   Most common cause: accessibility is not enabled, so Flutter does not build a semantics tree."
  echo "   → Fallback: estimate tap coordinates from the screenshot ($PNG) for this iteration,"
  echo "     and note in the report that estimated coordinates are being used, not exact ones."
fi
