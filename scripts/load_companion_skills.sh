#!/usr/bin/env bash
# Discover companion skills portably — no hardcoded paths, works on any OS / username.
# Mirrors the priority order Claude Code uses when resolving skill locations.
#
# Output (one line per companion):
#   SKILL_FOUND:<name>:<absolute_path_to_SKILL.md>
#   SKILL_MISSING:<name>
set -uo pipefail

COMPANIONS=(mobile ui-animation design-taste-frontend)

find_skill() {
  local name="$1"

  # Priority 1 — project-local install
  local p="$PWD/.claude/skills/$name/SKILL.md"
  [ -f "$p" ] && echo "$p" && return 0

  # Priority 2 — user global skills dir
  p="$HOME/.claude/skills/$name/SKILL.md"
  [ -f "$p" ] && echo "$p" && return 0

  # Priorities 3-5 — anywhere inside ~/.claude/plugins (any depth, any structure)
  # Covers:
  #   plugins/*/skills/<name>/SKILL.md
  #   plugins/*/**/skills/<name>/SKILL.md
  #   plugins/**/plugins/<name>/skills/<name>/SKILL.md
  local plugins_dir="$HOME/.claude/plugins"
  if [ -d "$plugins_dir" ]; then
    local found
    found=$(find "$plugins_dir" -type f -name "SKILL.md" \
      \( -path "*/skills/$name/SKILL.md" \
         -o -path "*/plugins/$name/skills/$name/SKILL.md" \) \
      2>/dev/null | sort | head -1)
    if [ -n "${found:-}" ]; then
      echo "$found"
      return 0
    fi
  fi

  return 1
}

for skill in "${COMPANIONS[@]}"; do
  path=$(find_skill "$skill" 2>/dev/null) \
    && echo "SKILL_FOUND:$skill:$path" \
    || echo "SKILL_MISSING:$skill"
done
