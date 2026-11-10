# Prototype validation

November 10, 2026 · Apple Silicon · macOS 27.0.1 (26A434) · Swift 6.4

## Automated and process checks

- Swift build: debug app and CLI compiled.
- Swift Testing: 13 tests passed, including actual nonzero process exit, cancellation, timeout, mismatched-run artifact rejection, evidence rules, and local persistence.
- CLI open-lid rehearsal: independent worker completed and the final artifact matched. Closed-lid work correctly remained unverified.
- Optional real network probe: six samples successfully reached the Apple endpoint during a five-second rehearsal. This is not provider health evidence.
- CLI nonzero command: `/usr/bin/false` produced recorded exit 1 and CLI exit 1.
- CLI cancellation: SIGTERM to the owned recorder produced cancelled status and CLI exit 130.
- Recorder interruption: SIGSTOP/SIGCONT to the disposable recorder, with a nine-second pause, produced an observation-gap event and no invented system-sleep event. This was not a physical sleep test.
- Native UI: started a 30-second open-lid rehearsal, observed completion and correct unverified closed-lid findings, and exported the report through the native Save panel. The real export is in `open-lid-rehearsal.md`.

Swift's default test-bundle signing failed inside this synced Documents folder because file-provider metadata was added to the generated bundle. Building/testing in a temporary scratch directory passed. App packaging signs and verifies in a temporary directory and creates a ZIP before copying into the synced output folder.

## Codex adapter validation

- 23 Swift tests pass after adding the adapter. New checks cover content filtering, real exec JSONL shapes, historical-event exclusion, multiple logged turns, partial lines, truncation/replacement, oversized records, stream incompleteness, privacy sentinels, and older recording compatibility.
- Live CLI observation of this active Codex Desktop chat: seven new tool-completion events in a 90-second recording. The observation reached its timeout and left the agent running. No new turn-start or end event was observed, so the turn outcome remained unverified.
- Native UI observation of the same live chat: four new tool completions. Stop recording ended observation while the chat continued; no agent process was terminated. The exported report is `live-codex-observation.md`.
- Neither live check involved closing the lid. Their activity is real; their closed-lid results remain unverified.
- The first GitHub macOS ARM job failed before execution because a runner was not acquired. Switching to `macos-15-intel` produced a successful hosted test and app-package build for the initial prototype. The adapter receives its own subsequent CI run.

## Physical validation still required

No physical lid close, system sleep/wake, thermal limit, battery cutoff, or provider-connection continuity has been validated. The prototype does not implement sleep control or those cutoffs. An open-lid pass must not be used as closed-lid evidence. Logged agent events do not independently establish task correctness or an approval-wait state.

Record future physical tests with hardware, OS, power source, network, keep-awake configuration, duration, and the exported report. Retest after relevant configuration changes.
