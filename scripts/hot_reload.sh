#!/usr/bin/env bash
# Send 'r' (hot reload) into the FIFO of the running flutter run process,
# then read only the NEW log lines (not the old ones) to determine the actual result.
set -uo pipefail

FIFO="$1"
LOG="$2"

LOG_LINES_BEFORE=$(wc -l < "$LOG" 2>/dev/null || echo 0)

echo "r" > "$FIFO"

echo "⏳ Waiting for hot reload result (up to 30s)..."
for i in $(seq 1 30); do
  NEW_LINES=$(tail -n "+$((LOG_LINES_BEFORE + 1))" "$LOG" 2>/dev/null || echo "")

  if echo "$NEW_LINES" | grep -qE "Reloaded [0-9]+ of [0-9]+"; then
    echo "✅ Hot reload succeeded."
    echo "RESULT=success"
    exit 0
  fi

  if echo "$NEW_LINES" | grep -qiE "Try again after fixing the above error|Hot reload was rejected"; then
    echo "❌ Hot reload failed due to a compile error in the code just edited."
    echo "RESULT=fail_compile"
    exit 1
  fi

  sleep 1
done

echo "⚠️  Could not determine reload result after 30s — recommend a hot RESTART (kill the process and re-run start_flutter_run.sh) to guarantee a clean state."
echo "RESULT=unknown"
exit 2
