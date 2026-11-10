# Borrow

**Rehearse a closed-lid task. See what actually happened.**

Borrow is a native Swift app and command recorder for investigating unattended work on a Mac. It records lid state, sleep/wake notifications, task activity and exit, and optional connectivity checks into a local, exportable report.

**Status: working prototype, not a keep-awake utility.** Borrow does not change power settings or prevent sleep. Use your existing keep-awake setup to test it. An experimental, read-only Codex adapter follows a session you select. This version does not detect agent approvals, restart agents, or establish that generated code is correct.

## Try it

Requires macOS 14+ and the Swift 6 toolchain (Xcode or Command Line Tools). No package dependencies, account, or API key.

```sh
swift test
bash scripts/build-app.sh
open dist/Borrow.app
```

In the app, choose a rehearsal length and press **Start rehearsal**. A separate worker writes one heartbeat per second and a run-specific final artifact. Close the lid on a ventilated desk, wait, and reopen to inspect the recording. First try an open-lid run so you know what the normal result looks like.

The app only credits worker progress between two samples that both observed the lid closed. A successful open-lid run leaves the closed-lid finding **Unverified**.

The locally built app is ad-hoc signed. It is not Developer ID signed or notarized for public distribution.

If a synced folder adds Finder metadata that prevents Swift's test-bundle signing, use `swift test --scratch-path "$(mktemp -d)"`. The app build script already uses a temporary build directory to avoid that problem.

## Record a command

```sh
swift build
.build/debug/borrow rehearse --duration 30
.build/debug/borrow run --timeout 600 -- /usr/bin/make test
.build/debug/borrow observe-codex --session /path/to/selected-session.jsonl --timeout 300
```

To record a coding CLI, supply its absolute executable path and normal arguments after `--`. The recorder does not change the agent's permissions. A zero foreground-process exit is recorded as an exit, not certified task completion. Background descendants are not supervised, and their completion is not established.

`--timeout` is wall-clock time, including sleep. This prototype caps command recordings at one hour and rehearsals at ten minutes. Cancellation and timeouts send SIGTERM only to the foreground process Borrow launched. Programs may ignore that signal or leave descendants; Borrow does not sweep the machine or kill processes by name.

Connectivity checks are off by default. `--network` explicitly enables periodic requests to `https://captive.apple.com/hotspot-detect.html`. Success establishes only that this endpoint answered. It does not establish provider health or that a live agent/SSH/remote-control connection survived.

## Observe a real Codex session

Choose **Observe Codex…** in the app and explicitly select one local `.jsonl` session log, normally under `~/.codex/sessions/`. The same mode is available through `observe-codex` above. Borrow attaches at the current end of the file. Existing events establish only internal turn bookkeeping; they do not inflate recorded activity.

New turn starts, completed tool items, turn ends, failures, and interruptions appear in the timeline. A logged turn end ends observation only when no other logged turn remains active and the stream is complete. **This observes a logged lifecycle; it does not independently verify the work.** No fresh events means no fresh evidence, not an inferred approval wait or a stuck agent.

The adapter reads the selected file locally. It persists fixed event labels, counts, and timestamps, discarding prompts, reasoning, messages, tool arguments/output, session paths, and turn IDs. Records over 1 MiB or malformed records make lifecycle completeness unknown. File replacement/truncation stops observation instead of silently replaying another source. Cancellation and timeout leave the observed agent untouched.

The parser supports the local journal shapes observed in Codex Desktop on this development machine, plus Codex `exec --json` lifecycle shapes. Local journals are an experimental integration surface and can change. Exec event shapes are documented in [OpenAI's source](https://github.com/openai/codex/blob/main/codex-rs/exec/src/exec_events.rs). This mode does not create or launch an agent, alter its permissions, install hooks, or change its configuration.

## Read the evidence

| Finding | What it means |
| --- | --- |
| Observed | The recording contains the specific evidence described beside the finding. |
| Failed | The bounded check encountered a failure, such as a nonzero command exit or a system sleep notification. |
| Unverified | Evidence is missing, insufficient, or ambiguous. |
| Skipped | The check was disabled or this prototype does not perform it. |

A delayed sample is an **observation gap**, not a sleep diagnosis. macOS sleep notifications are a separate signal. A recorded closed-lid interval does not prove uninterrupted operation across every instant or predict future compatibility. The rehearsal checks a disposable worker, not your agent's model connection or the quality of its work.

## Local data

Recordings are stored under `~/Library/Application Support/Borrow/Runs/<run-id>/`:

- `recording.json`: versioned observations, events, conditions, and exit status.
- `worker.json`: the independent rehearsal worker's latest heartbeat and final result.
- `report.md`: readable findings and timeline after a normal recorder shutdown.

The app's **Show files** and **Export report** buttons expose the results. CLI `--output DIRECTORY` uses another root; the app lists its default root only. No prompt text, command arguments, command output, environment variables, screenshots, or code are intentionally persisted. CLI command output passes through to the terminal. Reports do contain timestamps, OS version, process IDs, lid state, thermal state, battery percentage, and the executable's basename. Review before sharing.

The app and recorder are separate processes. Closing the window does not stop a recording. Use **Cancel** before quitting; a recorder left running is bounded by its timeout. Atomic snapshots refresh roughly every five seconds and at completion. A crash can lose the latest few samples and leave a snapshot marked running; the app shows stale samples as unknown rather than inventing a completed outcome.

## Project direction

The initial differentiation is a measurable rehearsal of the whole setup and evidence after an interrupted run. Keep-awake apps, cleanup utilities, and completion gates already exist. [The product brief](docs/product-brief.md) records the opportunity, limits, and release gates.

Planned next steps:

1. Physical closed-lid tests across machines, power sources, and macOS versions.
2. Broader validation of the read-only Codex adapter, and explicit approval signals where a provider exposes them.
3. Connection-specific probes and a small, reproducible interruption test suite.
4. A signed, notarized build and short real-world demonstration.

## Development

`BorrowCore` owns records, findings, machine probes, and recording. `BorrowCLI` owns a foreground process or disposable worker. `BorrowApp` is a SwiftUI window and menu bar front end. Tests exercise evidence classification and persistence; CLI smoke tests exercise actual processes. Physical lid-close results must be documented separately.

MIT licensed.
