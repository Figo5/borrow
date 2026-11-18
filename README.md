# Borrow

**Borrow time for a task. Let go when the recording ends.**

Borrow is a native Swift macOS app that gives a local task a temporary wake hold and records what happened. Rehearse a lid-close setup, record a foreground command, or follow one selected Codex session. Keep the evidence in a local, exportable report.

**0.3.0 source-first preview.** [Read the case study](https://gfiore.com/borrow) · [Get the 0.3.0-preview source release](https://github.com/Figo5/borrow/releases/tag/v0.3.0-preview)

Build from the tagged source archive or Git checkout. The local build uses an ad-hoc signature. Supported idle-sleep prevention does not prevent lid-close sleep. The stronger AC-only mode is experimental and needs a real test on your Mac. Closed-lid compatibility, uninterrupted agent connections, and actual sleep after release are separate observations.

On November 18, Borrow recorded two closed-lid runs on one Mac14,9 on AC power, running macOS 27.0.1 with only the built-in display detected at preflight. Off recorded a 299-second sampling gap. Experimental AC sampled the lid closed for 7m 04s, and a clean build and test run finished during that span. macOS logged before-sleep and wake notifications in both runs. See the [hardware report](https://gfiore.com/projects/borrow-hardware-comparison.md).

## First run

Requires macOS 14+ and Swift 6 through Xcode or Command Line Tools. No external packages, Borrow account, or Borrow API key.

Quit an already-running Borrow before rebuilding the app bundle.

```sh
swift test --scratch-path "$(mktemp -d)"
bash scripts/build-app.sh
open dist/Borrow.app
```

1. Choose **30 seconds** and leave **Wake hold** off for your first open-lid rehearsal.
2. Press **Start rehearsal**. A separate worker writes a heartbeat and a run-specific final artifact.
3. Inspect the report. An open-lid run leaves closed-lid work **Unverified**.
4. Choose a wake mode, repeat, and confirm the hold state before attempting a lid-close test. Reopen the lid to review the result.

The report credits worker progress only between two samples that both observed the lid closed. It preserves power notifications and sampling gaps separately. A successful short trial establishes only that setup and interval.

The build is ad-hoc signed. A Developer ID signed, notarized download is not available. See [installation and removal](docs/installation.md) for the source-first preview and build details.

## Choose a wake hold

| Mode | Behavior |
| --- | --- |
| Off, the default | Record without requesting a wake hold. |
| Prevent idle sleep | Use a supported temporary assertion. The display may sleep and closing the lid may still cause system sleep. |
| Experimental AC hold | Use Apple's built-in `caffeinate` system hold, bound to Borrow's recorder and deadline. Requires confirmed AC power. Closed-lid behavior is experimental. |

Borrow confirms its own assertion before reporting an active hold. It releases only its own hold when recording finishes, fails, is stopped, or reaches its deadline. Experimental AC mode ends if AC is lost or unknown. Other applications' holds remain untouched.

**Release permits normal sleep.** It does not force sleep, reset your settings, establish that an agent's code is correct, or prove that the Mac actually slept. [The feasibility notes](docs/sleep-control-research.md) explain the supported API and experimental-mode limits.

Closing the window keeps this app instance's bounded recorder running. **Quit Borrow** stops that recorder and waits for cleanup. A recorder started from a terminal or a previous app instance is view-only here and keeps its own deadline; the app leaves it untouched. **Stop recording** ends this window's observation while leaving an externally observed Codex agent running.

## Record a command

To see how Borrow reports successful and failed command exits, build the CLI and run the demo. It prints paths to two reports from real foreground commands with wake holds and connectivity checks off.

```sh
swift build
bash scripts/demo-recording.sh "$(swift build --show-bin-path)/borrow"
```

Use the CLI directly to rehearse, record a command, or observe a Codex session.

```sh
.build/debug/borrow rehearse --duration 30 --wake idle
.build/debug/borrow run --timeout 600 --wake idle -- /usr/bin/make test
.build/debug/borrow observe-codex --session /path/to/selected-session.jsonl --timeout 600 --wake experimental-ac
```

`--wake` accepts `off`, `idle`, or `experimental-ac`. It defaults to `off` in every mode. Use an absolute executable path after `--` for foreground commands; Borrow preserves the agent's permissions.

Recording timeouts use wall-clock time, including sleep. Rehearsals are capped at ten minutes, command/session recordings at one hour. Cancellation and timeout request SIGTERM only for the foreground process Borrow launched. An uncooperative command or its descendants may remain; releasing the wake hold does not certify process-tree completion.

Completion must be observed before the recording deadline. After a delayed or suspended recorder resumes, finding an exited process does not establish timely completion; the recording can time out with the exit status left unverified.

The CLI exits nonzero if Borrow cannot confirm cleanup of a requested wake hold, even if the foreground command exited zero. Inspect the report to distinguish a task failure from a cleanup failure.

`--network` explicitly enables periodic requests to `https://captive.apple.com/hotspot-detect.html`. Checks are off by default. Success establishes only that this endpoint answered, not that an agent's model, VPN, SSH, or remote-control connection survived.

## Observe Codex

Choose **Observe Codex…** and select one local `.jsonl` session journal, normally under `~/.codex/sessions/`. Borrow attaches at the current end. Historical activity is excluded from recorded activity counts.

New turn starts, tool completions, turn ends, failures, and interruptions appear in the timeline. Observation ends at a logged terminal boundary only when the stream is complete and no other logged turn remains active. A requested wake hold is released when observation ends. A missing event does not mean an agent is stuck or waiting for approval.

The adapter persists fixed labels, counts, and timestamps, discarding prompts, reasoning, messages, tool arguments/output, session paths, and raw turn IDs. File replacement/truncation stops observation. Malformed or oversized records make lifecycle completeness unknown. Events appended while closed can have been delivered late; they do not prove continuous execution.

An unfinished journal record keeps the boundary pending. A partial historical line can finish internal bookkeeping after attachment without being credited as new activity or falsely labelled malformed.

Local journals are an experimental integration surface. The parser also supports [Codex exec lifecycle events](https://github.com/openai/codex/blob/main/codex-rs/exec/src/exec_events.rs). Logged completion and process exit remain distinct from acceptance-test verification. Borrow does not launch, configure, or terminate an externally observed agent.

## Read and share the evidence

| Finding | Meaning |
| --- | --- |
| Observed | The recording contains the specific evidence described. |
| Failed | A bounded check encountered a failure. |
| Unverified | Evidence is missing, insufficient, stale, or ambiguous. |
| Skipped | The check was disabled or was not performed. |

A delayed sample is an observation gap, not a sleep diagnosis. A macOS before-sleep notification does not measure an execution pause. If notifications and closed-lid worker progress coexist, the report preserves both and leaves uninterrupted operation unverified.

Recordings live under `~/Library/Application Support/Borrow/Runs/<run-id>/`. The app offers **Show files** and **Export report**; CLI `--output DIRECTORY` selects a different root. Reports contain machine/task metadata, including timestamps, OS version, process IDs, lid/power/thermal observations, and executable basename. Review them before sharing. [Privacy details](docs/privacy.md) explain what is kept and discarded.

Atomic snapshots refresh roughly every five seconds and on orderly completion. A crash can leave a stale recording; Borrow keeps its result unknown. An OS timeout and owner-lifetime bound backstop the wake hold, and normal cleanup is recorded separately.

## Validation and development

`BorrowCore` owns evidence, power probes, wake leases, and recording. `BorrowCLI` runs a foreground command or observes a journal. `BorrowApp` supplies native SwiftUI controls. The build script uses temporary scratch storage to avoid signing failures caused by synced-folder metadata.

- [Validation evidence](docs/validation.md) and [the first physical test](docs/physical-lid-close.md).
- [November 18 case study](https://gfiore.com/borrow) and [closed-lid hardware report](https://gfiore.com/projects/borrow-hardware-comparison.md).
- [Release notes](docs/release-notes.md) and [release checklist](docs/release-checklist.md).
- [Claude/OpenCode review and corrections](docs/claude-opencode-review.md).
- [November 12 software handoff (historical)](docs/software-handoff.md).
- [Real-agent test protocol and result status](docs/physical-agent-validation.md).
- [Demo plan and completion status](docs/demo.md).
- [Changelog](CHANGELOG.md).
- [Product brief](docs/product-brief.md), competitive boundaries, and Ousel replacement gate.

The November 18 comparison is the first closed-lid evidence for the experimental hold: one Mac, charger power, built-in display. It does not establish physical unplug, battery-only use, provider connectivity, or immediate sleep after release. The earlier 30-second test under an existing `caffeinate` hold remains separately documented and does not validate Borrow's experimental hold.

MIT licensed.
