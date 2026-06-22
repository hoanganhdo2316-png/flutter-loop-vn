#!/usr/bin/env bash
# Start 'flutter run' in the background, using a named pipe (FIFO) as stdin
# so hot reload commands ('r') can be sent later without simulating real keypresses.
# 'flutter run' NEVER exits on its own — this script waits until the log shows
# the app has finished launching (ready to test), then hands control back to the agent.
#
# Requirements: a shell that supports mkfifo (Git Bash / WSL on Windows, standard bash on macOS/Linux).
set -uo pipefail

DEVICE_ID="$1"
ENTRY="${2:-lib/main.dart}"
WORKDIR="${3:-.flutter_loop}"

mkdir -p "$WORKDIR"
FIFO="$WORKDIR/input.fifo"
LOG="$WORKDIR/run.log"
PIDFILE="$WORKDIR/run.pid"

# Clean up any leftover process from a previous run
if [ -f "$PIDFILE" ]; then
  OLD_PID=$(cat "$PIDFILE" 2>/dev/null || echo "")
  [ -n "$OLD_PID" ] && kill "$OLD_PID" 2>/dev/null || true
fi
rm -f "$FIFO"
mkfifo "$FIFO" || { echo "❌ Could not create FIFO. The current shell may not support mkfifo (Git Bash or WSL is required on Windows)."; exit 1; }
: > "$LOG"

# Open the FIFO in read-write mode on fd 3 to keep it alive throughout the session
# (prevents flutter run from receiving EOF immediately when no other writer is present)
exec 3<>"$FIFO"

flutter run -d "$DEVICE_ID" -t "$ENTRY" <&3 > "$LOG" 2>&1 &
RUN_PID=$!
echo "$RUN_PID" > "$PIDFILE"

echo "⏳ Waiting for app to finish launching on device (up to 120s)..."
READY=0
for i in $(seq 1 120); do
  if grep -q "Flutter run key commands" "$LOG" 2>/dev/null; then
    READY=1
    break
  fi
  # If the process dies early (severe build error) stop waiting immediately
  if ! kill -0 "$RUN_PID" 2>/dev/null; then
    break
  fi
  sleep 1
done

if [ "$READY" -eq 1 ]; then
  echo "✅ App is ready for testing."
  echo "RUN_PID=$RUN_PID"
  echo "FIFO=$FIFO"
  echo "LOG=$LOG"
  exit 0
else
  echo "❌ App did not finish launching (timeout or build error). Last log lines:"
  tail -50 "$LOG"
  exit 1
fi
