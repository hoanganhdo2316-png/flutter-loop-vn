#!/usr/bin/env bash
# Check the environment, auto-configure what is safe to automate,
# and clearly report what REQUIRES manual action by the user (no guessing, no forced runs).
set -uo pipefail

echo "== Preflight: checking project path =="
case "$(pwd)" in
  *[![:ascii:]]*)
    echo "❌ Current directory path contains non-ASCII characters (accented letters, etc.): $(pwd)"
    echo "   Android Gradle Plugin and CMake CANNOT build on paths like this — the build will fail partway through."
    echo "   Fix (Windows): map the path to a virtual drive using an ASCII letter BEFORE doing anything else, e.g.:"
    echo "     subst Q: \"$(pwd)\""
    echo "   Then reopen Claude Code at drive Q:\\ and re-run the skill command from there."
    exit 1
    ;;
esac
echo "✅ Path is valid."

MISSING_MANUAL=()
OK=()

check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    OK+=("$1")
    return 0
  fi
  return 1
}

echo "== Preflight: checking required tools =="

check_cmd flutter || MISSING_MANUAL+=("Flutter SDK not found in PATH. Install from https://docs.flutter.dev/get-started/install, then REOPEN the terminal/Claude Code (PATH changes only take effect in new sessions).")
check_cmd adb     || MISSING_MANUAL+=("adb (Android platform-tools) not found in PATH. Usually located at <Android SDK>/platform-tools — add that directory to PATH.")
check_cmd java    || MISSING_MANUAL+=("Java JDK not found in PATH — Flutter Android builds require JDK 17 or higher.")

if [ ${#MISSING_MANUAL[@]} -gt 0 ]; then
  echo "❌ The following tools require MANUAL installation and cannot be automated safely:"
  for m in "${MISSING_MANUAL[@]}"; do echo "  - $m"; done
  exit 1
fi
echo "✅ Core tools OK: ${OK[*]}"

echo "== Auto-configuring code-level settings (safe to automate) =="

if [ -f "pubspec.yaml" ]; then
  if [ ! -d "android" ]; then
    echo "⚙️  Missing android/ directory in existing project — creating it with 'flutter create . --platforms=android'"
    flutter create . --platforms=android || { echo "❌ Failed to create android platform. Manual inspection required."; exit 1; }
  fi
  echo "⚙️  Running flutter pub get..."
  flutter pub get || { echo "❌ pub get failed — check for dependency errors above."; exit 1; }
else
  echo "ℹ️  No pubspec.yaml found here — this is an empty project. SKILL.md handles 'flutter create' with a project name and org provided by the user; not auto-guessing those here."
fi

echo "⚙️  Accepting Android licenses (if any are still pending)..."
yes | flutter doctor --android-licenses >/dev/null 2>&1 || true

echo "== Checking connected Android devices =="
DEVICES=$(adb devices | tail -n +2 | awk '$2=="device"{print $1}')
COUNT=$(printf '%s\n' "$DEVICES" | grep -c . || true)

if [ "$COUNT" -eq 0 ]; then
  echo "❌ No Android device detected via adb."
  echo "   Connect your phone with a USB cable, enable 'USB debugging' in Developer Options, tap Allow when prompted on the phone, then try again."
  echo "   Note: manufacturer-specific USB drivers (Samsung/Xiaomi/Oppo/etc.) must be installed manually."
  exit 1
elif [ "$COUNT" -gt 1 ]; then
  echo "⚠️  Multiple devices connected — user must select one (pass -d <id> to all subsequent adb/flutter commands):"
  echo "$DEVICES"
  exit 2
fi

echo "✅ Device: $DEVICES"

echo "== Enabling Accessibility so uiautomator can read Flutter widget content =="
# Flutter only builds a semantics tree (which uiautomator needs to inspect widgets)
# when at least one accessibility service is running on the device. Without this,
# a uiautomator dump will see essentially nothing inside a Flutter app (just an empty block).
TALKBACK_SVC="com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService"
adb -s "$DEVICES" shell settings put secure enabled_accessibility_services "$TALKBACK_SVC" >/dev/null 2>&1 || true
adb -s "$DEVICES" shell settings put secure accessibility_enabled 1 >/dev/null 2>&1 || true
CHECK=$(adb -s "$DEVICES" shell settings get secure enabled_accessibility_services 2>/dev/null || echo "")
if echo "$CHECK" | grep -qi "talkback"; then
  echo "✅ Accessibility enabled — uiautomator dump will be able to read Flutter widget content."
else
  echo "⚠️  Could not confirm accessibility is enabled (TalkBack may not be installed on this device)."
  echo "   uiautomator dump in Step 5 may return empty — capture_ui.sh will report UIDUMP=FAILED clearly when this happens,"
  echo "   at which point coordinate estimation from the screenshot is used as a fallback."
fi

echo "DEVICE_ID=$DEVICES"
