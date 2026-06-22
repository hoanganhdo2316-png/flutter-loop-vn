#!/usr/bin/env bash
# Create memory.md and screen_cap/ if they do not exist. Determine the next session
# number by reading the highest session already recorded in memory.md and adding 1.
set -uo pipefail

MEMORY_FILE="memory.md"
SCREEN_DIR="screen_cap"

mkdir -p "$SCREEN_DIR"

if [ ! -f "$MEMORY_FILE" ]; then
  cat > "$MEMORY_FILE" << 'EOF'
# Memory Log — Flutter Loop VN

This file records the history of every agent run on this project.
Each run must append exactly one block in the format below (do not alter this format):

S{session}.{run} (HH:MM DD/MM/YYYY):
  Prompt: <original user request>
  Done: <summary of changes made>
  Skills used: <slash-commands / skills called in this run>
  Git version (before changes): <commit hash>
  Flutter run: Success / Fail
  Device: <name of the test device>
  Error (if any): <description of any remaining error, if stopped due to iteration limit>
  Improvement suggestions: <suggestions for the next session>

---
EOF
  NEXT_SESSION=0
else
  LAST=$(grep -oE '^S[0-9]+\.' "$MEMORY_FILE" 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1)
  if [ -z "${LAST:-}" ]; then
    NEXT_SESSION=0
  else
    NEXT_SESSION=$((LAST + 1))
  fi
fi

echo "NEXT_SESSION=$NEXT_SESSION"
echo "MEMORY_FILE=$MEMORY_FILE"
echo "SCREEN_DIR=$SCREEN_DIR"
