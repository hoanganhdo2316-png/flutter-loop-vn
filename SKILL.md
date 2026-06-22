---
name: flutter-loop-vn
description: Autonomous loop that codes, builds, and runs a Flutter app on a real Android device via adb (using flutter run + hot reload over a FIFO pipe — no full rebuild between iterations), auto-captures screenshots and reads the UI hierarchy to navigate to the correct screen, diagnoses bugs from images, auto-fixes code, and records the complete history into memory.md per session. Works with both empty Flutter projects and existing ones. Only activates when the user explicitly types /flutter-loop-vn — never triggers automatically.
disable-model-invocation: true
---

# Flutter Loop VN

> **Current scope: Android only (via adb).** The skill name is intentionally generic ("flutter-loop-vn") so an iOS branch (e.g., via `xcrun simctl` for Simulator) can be added later without renaming the skill — but at this point, every step below assumes an Android device.

Autonomous loop: receive coding request → write/fix code → run on a real Android device → inspect the result → fix bugs if any → repeat until correct or the iteration limit is reached. The full history is written to `memory.md` so a future session (or another agent) can resume with full context instantly — no need for the user to re-explain the project.

## Core Rules (never violate)
1. **Never `git commit` automatically.** Only record the current commit hash (before changes) in `memory.md` for tracking. The user decides when to commit.
2. **Maximum 5 fix iterations** per skill invocation. After 5 rounds with errors still present → stop, write a full log entry, do not loop further.
3. **Maximum 5 navigation taps** to reach the correct screen in one iteration. After 5 taps without reaching the target screen → stop, ask the user for navigation instructions, log `Flutter run: Fail` with reason "could not navigate to target screen".
4. **If the exact same error repeats in 2 consecutive iterations** → stop immediately (see rule #2 above — the agent is fixing in the wrong direction, do not waste the remaining iterations).
5. All fixed operations (build, install, screenshot, adb commands) use the scripts in `scripts/` — **do not re-type complex adb/flutter commands manually**; use the scripts to guarantee consistency.

## File & Naming Conventions

**`memory.md`** — session history log, format:
```
S{session}.{run} (HH:MM DD/MM/YYYY):
  Prompt: ...
  Done: ...
  Skills used: ...
  Git version (before changes): ...
  Flutter run: Success/Fail
  Device: ...
  Error (if any): ...
  Improvement suggestions: ...
```
- `session` = session number, computed by `scripts/init_memory.sh` (highest existing session in the file + 1).
- `run` = iteration index within this session, starting at 0, incremented each loop.

**`screen_cap/`** — screenshots, named by the exact code `S{session}.{run}`. If multiple shots are taken in one iteration (due to navigation), append an index: `S2.3.1.png`, `S2.3.2.png`… The final shot used for error evaluation carries the bare name `S2.3.png` (no suffix index).

## Step 0 — Load companion skills (always run first)

Run the discovery script to find companion skills on this machine:
```
bash "${CLAUDE_SKILL_DIR}/scripts/load_companion_skills.sh"
```
`CLAUDE_SKILL_DIR` is the directory containing this SKILL.md file. Resolve it dynamically — it is wherever the user installed the skill (varies per machine, OS, and username).

For each line in the output:

- **`SKILL_FOUND:<name>:<path>`** → read that SKILL.md file using the Read tool and extract the core rules/patterns from it (not the full text verbatim — distill the key principles that apply to Flutter work).
- **`SKILL_MISSING:<name>`** → print the following and continue (do not stop the session):
  ```
  ⚠ Companion skill '<name>' not found — install it to get [brief benefit]. Continuing without it.
  ```
  Benefit hint per skill:
  - `mobile`: native mobile UX patterns, platform conventions, accessibility
  - `ui-animation`: motion design rules, spring physics, transition timing
  - `design-taste-frontend`: visual quality bar — spacing, hierarchy, color consistency

After processing all companion skills, print a summary visible to the user:
```
Active companion skills: [comma-separated list of found ones]
Design & mobile rules in effect this session:
  • [rule 1 synthesized from loaded skills]
  • [rule 2]
  • [rule 3]
  • [up to 5 bullet points]
```

These rules stay active for the **entire session** and are applied when:
- Writing any Flutter widget code → apply mobile patterns
- Making any UI/layout/color decision → apply design-taste-frontend rules
- Adding any animation or transition → apply ui-animation patterns
- Inspecting screenshots → flag design regressions (bad spacing, misaligned elements, inconsistent colors) as bugs, not just functional errors

## Step 0b — Preflight (always run second)
```
bash "${CLAUDE_SKILL_DIR}/scripts/preflight.sh"
```

- If exit code is non-zero because a tool requires manual installation → stop, print the exact message the script outputs, **do not try to install it automatically**.
- If exit code is non-zero because multiple devices are connected → ask the user to pick one, then pass `-d <device_id>` to every subsequent script call.
- Extract `DEVICE_ID` from the script output.

## Step 1 — Branch: empty project or existing?

**If `pubspec.yaml` does NOT exist** (empty project):
1. Ask the user: project name (e.g., `my_app`) and package id / org (e.g., `com.example`).
2. `flutter create --org <org> --platforms=android <project_name>`
3. `cd <project_name>` — all subsequent steps run inside this directory.
4. Re-run `bash "${CLAUDE_SKILL_DIR}/scripts/preflight.sh"` once more (now that pubspec.yaml exists, so pub get and license acceptance run correctly inside the new project).

**If `pubspec.yaml` ALREADY EXISTS** (existing project):
1. If **`memory.md` does not exist** → this project has never used this skill. Read through the entire `lib/` structure (not every line of every file, but understand the overall architecture, main screens, and API call patterns) before coding, to avoid violating existing conventions.
2. If **`memory.md` exists** → read the entire file to understand history, prior decisions, and any pending improvement suggestions from the last run — prioritize this over re-reading all the code.

## Step 2 — Initialize memory & determine session
```
bash "${CLAUDE_SKILL_DIR}/scripts/init_memory.sh"
```
Read `NEXT_SESSION` from output. Set iteration counter `RUN=0` for this session.

## Step 3 — Implement the user's coding request
Write/fix code according to the user's request (taken from the skill invocation, e.g., `/flutter-loop-vn add phone number login screen`). Keep the original prompt text to log into `memory.md` later.

**Before building:** record the current git hash for the log:
```
git rev-parse HEAD
```

## Step 4 — Launch app on device (once per session, not once per iteration)
```
bash "${CLAUDE_SKILL_DIR}/scripts/start_flutter_run.sh" <DEVICE_ID> lib/main.dart
```
Read `RUN_PID`, `FIFO`, `LOG` from output — keep these throughout all iterations (do not restart unless hot reload keeps failing, see Step 7).

If the script reports an error (build fails immediately) → read the log, fix compile errors, re-run Step 4 (this does not count as a test-fix iteration, because the app has never launched yet).

## Step 5 — Test–fix loop (repeat up to 5 times, `RUN` incremented each round)

### 5.1 Navigate to the correct screen to inspect (max 5 taps)
```
bash "${CLAUDE_SKILL_DIR}/scripts/capture_ui.sh" <DEVICE_ID> S<session>.<RUN>.<shot_index> screen_cap
```
- Open the `.png` just captured using the image-read tool — determine whether this is the target screen.
- If not on the correct screen, a tap is needed to navigate. Two cases based on script output:
  - **`UIDUMP=<path>` (success):** open the `_uidump.xml` file, find the node with a `text` or `resource-id` matching the button to tap, read `bounds="[x1,y1][x2,y2]"`, compute center `((x1+x2)/2, (y1+y2)/2)`, tap at that exact coordinate.
  - **`UIDUMP=FAILED` (uiautomator cannot see Flutter content — usually accessibility is not enabled):** estimate coordinates directly from the `.png` image (e.g., FAB is typically at the bottom-right corner). This is a fallback and **less accurate** — if the same estimated position fails twice in a row, stop and tell the user that accessibility may not be correctly enabled, and suggest re-checking preflight.
  ```
  adb -s <DEVICE_ID> shell input tap <x> <y>
  ```
- Increment `shot_index`, capture again (Step 5.1), repeat until on the correct screen or 5 attempts have been used.
- After 5 attempts still not on the target screen → stop the loop, ask the user for specific navigation instructions, log `Flutter run: Fail` with reason "could not navigate to target screen".

### 5.2 Official evaluation screenshot for this iteration
The last image in the Step 5.1 navigation sequence (code `S<session>.<RUN>.<last_shot_index>`) is the official representative screenshot for iteration `RUN` — **no additional capture needed with an unsuffixed name.** If the first capture was already the target screen (no navigation needed), then `S<session>.<RUN>.0` is the official screenshot.

### 5.3 Diagnose bugs
Inspect the official screenshot for this iteration (the last image from Step 5.2):
- Is there a visible UI error (layout broken, overflow, does not match requirements, widget missing)?
- Cross-reference with `LOG` (the flutter run log file) for any new exceptions or stack traces (read only the newest log section, not from the beginning).
- **Also evaluate design quality against the active companion skill ruleset** (loaded in Step 0): check spacing, alignment, color consistency, and animation smoothness. Treat design regressions as bugs with the same priority as functional bugs — a misaligned element or inconsistent color is just as worth fixing as a crash.

**NO ERROR** → exit the loop, proceed to Step 6 (log success).

**ERROR FOUND** → identify the file:line causing the bug (prefer stack trace from the log), fix the code (Edit tool, minimal targeted change).

### 5.4 Apply changes — hot reload
```
bash "${CLAUDE_SKILL_DIR}/scripts/hot_reload.sh" <FIFO> <LOG>
```
- `RESULT=success` → increment `RUN` by 1, return to Step 5.1.
- `RESULT=fail_compile` → compile error in the code just edited; fix it immediately (does not count as a new iteration — fix then hot reload again) until it compiles, then increment `RUN` and return to 5.1.
- `RESULT=unknown` → treat as needing a hot RESTART to ensure a clean state (see Step 7), then return to 5.1.

### 5.5 Check for repeated errors
If the error in the current `RUN` is **identical** to the error in `RUN - 1` → stop immediately (see core rule #4), and log clearly: "stopped — same error in 2 consecutive iterations, agent may be fixing in the wrong direction, human review needed".

## Step 6 — After the loop ends (success or limit reached)
Append one block to `memory.md` (using the format from the "File Conventions" section):
```
S<session>.<RUN> (HH:MM DD/MM/YYYY):
  Prompt: <original user request>
  Done: <summary of changes made across iterations>
  Skills used: /flutter-loop-vn
  Git version (before changes): <hash from Step 3>
  Flutter run: Success or Fail
  Device: <model from 'adb shell getprop ro.product.model'>
  Error (if any): <description of remaining error>
  Improvement suggestions: <suggestions for the next session>
```

## Step 7 — Hot restart when needed (instead of hot reload)
When a full clean restart is required (modified files under `android/`, modified `pubspec.yaml`, or hot reload returned `unknown` / keeps failing):
```
kill <RUN_PID>
bash "${CLAUDE_SKILL_DIR}/scripts/start_flutter_run.sh" <DEVICE_ID> lib/main.dart
```
Read new `RUN_PID`/`FIFO`/`LOG`, continue the loop from Step 5.1.

## Finish — Cleanup
```
kill <RUN_PID>
```
Kill the `flutter run` process before ending the session to prevent it from lingering in the background and blocking the device for the next run.

## Output to the user
After completing, reply to the user with **exactly the block just appended to `memory.md`** in Step 6 — no lengthy extra explanation, as that block is already the canonical summary of this run.
