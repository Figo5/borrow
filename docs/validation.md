# Prototype validation

November 10, 2026 · Apple Silicon · macOS 27.0.1 (26A434) · Swift 6.4

## Initial recorder checks

- Swift build: debug app and CLI compiled.
- Swift Testing: the initial recorder's 13 tests passed, including actual nonzero process exit, cancellation, timeout, mismatched-run artifact rejection, evidence rules, and local persistence.
- CLI open-lid rehearsal: independent worker completed and the final artifact matched. Closed-lid work correctly remained unverified.
- Optional real network probe: six samples successfully reached the Apple endpoint during a five-second rehearsal. This is not provider health evidence.
- CLI nonzero command: `/usr/bin/false` produced recorded exit 1 and CLI exit 1.
- CLI cancellation: SIGTERM to the owned recorder produced cancelled status and CLI exit 130.
- Recorder interruption: SIGSTOP/SIGCONT to the disposable recorder, with a nine-second pause, produced an observation-gap event and no invented system-sleep event. This was not a physical sleep test.
- Native UI: started a 30-second open-lid rehearsal, observed completion and correct unverified closed-lid findings, and exported the report through the native Save panel. The real export is in `open-lid-rehearsal.md`.

Swift's default test-bundle signing failed inside this synced Documents folder because file-provider metadata was added to the generated bundle. Building/testing in a temporary scratch directory passed. App packaging signs and verifies in a temporary directory and creates a ZIP before copying into the synced output folder.

## Codex adapter validation

- 23 Swift tests passed after adding the adapter. New checks cover content filtering, real exec JSONL shapes, historical-event exclusion, multiple logged turns, partial lines, truncation/replacement, oversized records, stream incompleteness, privacy sentinels, and older recording compatibility.
- Live CLI observation of this active Codex Desktop chat: seven new tool-completion events in a 90-second recording. The observation reached its timeout and left the agent running. No new turn-start or end event was observed, so the turn outcome remained unverified.
- Native UI observation of the same live chat: four new tool completions. Stop recording ended observation while the chat continued; no agent process was terminated. The exported report is `live-codex-observation.md`.
- Neither live check involved closing the lid. Their activity is real; their closed-lid results remain unverified.
- The first GitHub macOS ARM job failed before execution because a runner was not acquired. Switching to `macos-15-intel` produced successful hosted tests and app-package builds for the initial prototype and subsequent adapter/report-correction commits.

## First physical lid-close validation

The operator completed a real thirty-second rehearsal on charger with no external display. The worker advanced 15 ticks between closed-lid samples and produced the expected final artifact. macOS also posted before-sleep/wake notifications; the power log shows a 16-second DarkWake interval and an existing caffeinate hold. [Full notes and evidence](physical-lid-close.md) preserve the result and conditions. This exposed and corrected an overly aggressive failure classification for before-sleep notifications.

The 0.2.1 correction passed 25 tests, including a regression using the exact physical recording. It preserves observed worker progress while leaving uninterrupted operation unverified.

## Task-scoped wake control candidate

The 0.3.0 candidate passed 48 tests with its three opt-in native power-integration tests enabled. Coverage was 93.21% of lines for the wake lease, 90.08% for the recorder, and 88.72% across the core; branch data was unavailable. Default tests do not acquire real wake holds.

Seventeen actual open-lid CLI/OS smoke cases covered off/idle/experimental success and nonzero exit, missing executables, cancellation, timeout, recorder force-kill, stopped-recorder expiry, and owned-helper loss. All passed their bounded expectations. Native Quit cancelled an active experimental recording and confirmed release before exit. Five invalid-input/source CLI checks returned failure without exposing selected paths. Global power-setting output was unchanged.

[The detailed lifecycle validation](wake-lease-validation.md) distinguishes backend confirmation from the seven separately checked OS-absence results, preserves stale running/active crash snapshots honestly, and records cancellation timing and remaining limits. These are lifecycle checks, not new physical closed-lid evidence.

## Further physical validation required

Long-duration closed-lid behavior, battery-only behavior, actual execution suspension/resume, thermal limits, battery cutoffs, and provider-connection continuity remain unverified. The candidate implements bounded owned wake holds, including a clearly labeled experimental AC mode; it does not implement global power-setting changes, forced sleep, or thermal/battery cutoffs. Logged agent events do not independently establish task correctness or an approval-wait state.

Record future physical tests with hardware, OS, power source, network, keep-awake configuration, duration, and the exported report. Retest after relevant configuration changes.
