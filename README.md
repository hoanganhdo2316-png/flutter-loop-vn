# flutter-loop-vn

A Claude Code skill that autonomously codes, builds, and deploys Flutter changes to a real Android device — then inspects the result and fixes bugs on its own, without you lifting a finger.

---

## How it works

When you type `/flutter-loop-vn <your request>`, the skill enters a tight loop:

1. **Code** — the agent writes or edits the Dart/Flutter code to fulfil your request.
2. **Build & install** — the app is compiled and pushed to a real Android device over USB via `adb`.
3. **Screenshot + UI inspection** — `capture_ui.sh` takes a screenshot and dumps the full widget hierarchy via `uiautomator`. The agent opens the image visually, reads widget coordinates from the XML dump, and navigates to the exact screen it needs to inspect — no manual tapping required, no need for you to describe what you see.
4. **Diagnose** — the agent compares the live screenshot against your request and cross-references the `flutter run` log for exceptions or stack traces.
5. **Fix** — if a bug is found, the agent edits the source, hot-reloads into the running app (no full rebuild), and repeats from step 3.
6. **Stop** — the loop ends when the screen looks correct, or after 5 fix iterations, whichever comes first.

### memory.md

Every run appends one structured block to `memory.md` in your project root:

```
S2.1 (14:32 22/06/2026):
  Prompt: Add Zalo OAuth login screen
  Done: Created lib/screens/login_screen.dart, wired up ZaloKit SDK
  Skills used: /flutter-loop-vn
  Git version (before changes): a3f9c12
  Flutter run: Success
  Device: Samsung Galaxy A54
  Error (if any): —
  Improvement suggestions: Add error banner for network timeout case
```

This file is the agent's long-term memory for your project. Any future session — or a completely different agent — can open `memory.md` and immediately understand what has been built, what decisions were made, and what to tackle next. You never have to re-explain the project.

---

## Requirements

- [Claude Code](https://claude.ai/download) installed
- Flutter SDK in `PATH`
- Android SDK platform-tools (`adb`) in `PATH`
- Java JDK 17+ in `PATH`
- **Git Bash** (bundled with [Git for Windows](https://git-scm.com/download/win)) — required because all `.sh` scripts in this skill need `bash` to run
- 1 Android device with **USB debugging enabled**
- Windows 10 or 11 (macOS/Linux support coming soon)

---

## Installation

**Step 1** — Clone this repo:
```
git clone https://github.com/hoanganhdo2316-png/flutter-loop-vn
```

**Step 2** — Enter the directory:
```
cd flutter-loop-vn
```

**Step 3** — Run the installer:
```
powershell -ExecutionPolicy Bypass -File install.ps1
```

> If you see an "Untrusted script" warning, press **[R]** to Run once.

---

## Usage

Open Claude Code inside your Flutter project folder, then type:

```
/flutter-loop-vn <your request>
```

**Examples:**

```
/flutter-loop-vn Add Zalo OAuth login screen
/flutter-loop-vn Fix overflow bug on the student list screen
/flutter-loop-vn Replace the bottom nav bar with a drawer menu
```

The skill auto-reads `memory.md` if it exists in the project root — giving the agent full context from all previous sessions. On a brand-new project with no `memory.md`, the agent reads the `lib/` source structure directly before starting.

---

## Files created in your project

```
your-flutter-project/
├── memory.md           ← timestamped run history; any agent can resume from here instantly
├── screen_cap/         ← screenshots from each loop iteration (PNG)
│   ├── S1.0.png
│   ├── S1.1.png
│   └── ...
└── .flutter_loop/      ← temp files (FIFO pipe + flutter run log) — add to .gitignore
    ├── input.fifo
    └── run.log
```

Add `.flutter_loop/` to your project's `.gitignore`. The `screen_cap/` PNGs and `memory.md` are worth keeping — they're your audit trail.

---

## Known limitations

- **Android only.** iOS support (via `xcrun simctl`) is in development.
- **ASCII paths only.** Windows CMake cannot handle non-ASCII characters in project paths (Vietnamese folder names, accented characters, etc.). The skill detects this automatically at startup and tells you exactly how to fix it with `subst`.
- **Never auto-commits.** This is intentional — you decide when your changes are ready to commit.
- **Maximum 5 fix iterations** per invocation. If the bug is not resolved within 5 rounds, the skill stops and logs everything so you can review.

---

## License

MIT

---

Made with ❤️ for Vietnamese Flutter developers
