#!/usr/bin/env bash
# Discover companion skills portably — no hardcoded paths, works on any OS / username.
# Mirrors the priority order Claude Code uses when resolving skill locations.
# If a skill is not found, Phase 2 attempts auto-install via git clone.
#
# Output (one line per companion):
#   SKILL_FOUND:<name>:<absolute_path_to_SKILL.md>     — found on first search
#   SKILL_INSTALLED:<name>:<absolute_path_to_SKILL.md> — not found, auto-installed successfully
#   SKILL_MISSING:<name>:<reason>                       — not found and could not install
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

auto_install() {
  local name="$1"
  local dest_dir="$HOME/.claude/skills/$name"

  case "$name" in

    design-taste-frontend)
      local tmp="/tmp/taste-skill-clone"
      echo "⏳ Auto-installing $name..." >&2
      set +e
      rm -rf "$tmp"
      git clone --depth=1 https://github.com/Leonxlnx/taste-skill "$tmp" >/dev/null 2>&1
      local clone_exit=$?
      set -e
      if [ $clone_exit -ne 0 ]; then
        echo "SKILL_MISSING:$name:git clone failed (network error or repo not found)"
        rm -rf "$tmp"
        return
      fi
      local src="$tmp/skills/taste-skill/SKILL.md"
      if [ ! -f "$src" ]; then
        echo "SKILL_MISSING:$name:install failed (SKILL.md not at expected path in repo)"
        rm -rf "$tmp"
        return
      fi
      mkdir -p "$dest_dir"
      cp "$src" "$dest_dir/SKILL.md"
      rm -rf "$tmp"
      ;;

    ui-animation)
      local tmp="/tmp/agent-skills-clone"
      echo "⏳ Auto-installing $name..." >&2
      set +e
      rm -rf "$tmp"
      git clone --depth=1 https://github.com/mblode/agent-skills "$tmp" >/dev/null 2>&1
      local clone_exit=$?
      set -e
      if [ $clone_exit -ne 0 ]; then
        echo "SKILL_MISSING:$name:git clone failed (network error or repo not found)"
        rm -rf "$tmp"
        return
      fi
      local src="$tmp/skills/ui-animation/SKILL.md"
      if [ ! -f "$src" ]; then
        echo "SKILL_MISSING:$name:install failed (SKILL.md not at expected path in repo)"
        rm -rf "$tmp"
        return
      fi
      mkdir -p "$dest_dir"
      cp "$src" "$dest_dir/SKILL.md"
      rm -rf "$tmp"
      ;;

    mobile)
      echo "SKILL_MISSING:$name:no confirmed install source"
      echo "ℹ️  Install manually: https://mcpmarket.com/tools/skills/mobile-app-development" >&2
      return
      ;;

    *)
      echo "SKILL_MISSING:$name:no install source defined"
      return
      ;;
  esac

  # Re-run Phase 1 to confirm install succeeded
  local confirmed
  confirmed=$(find_skill "$name" 2>/dev/null) \
    && echo "SKILL_INSTALLED:$name:$confirmed" \
    || echo "SKILL_MISSING:$name:install failed"
}

# Check git availability once — needed for all clone operations
GIT_OK=false
command -v git >/dev/null 2>&1 && GIT_OK=true

for skill in "${COMPANIONS[@]}"; do
  if path=$(find_skill "$skill" 2>/dev/null); then
    echo "SKILL_FOUND:$skill:$path"
  else
    # Phase 2 — attempt auto-install
    if [ "$GIT_OK" = false ]; then
      echo "SKILL_MISSING:$skill:git not available"
    else
      auto_install "$skill"
    fi
  fi
done
