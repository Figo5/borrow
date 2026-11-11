# Exploration: task-scoped power control and release preparation

November 10, 2026. Phase 0–1 investigation for the orchestration plan. This document records code inspection and read-only local inventory; no new power control, physical validation, or release was performed.

## Entry points and execution flow

- Native rehearsal: `BorrowModel.start()` in `Sources/BorrowApp/BorrowApp.swift:42` launches the bundled recorder through `launch()` at line 61.
- Native Codex observation: `observeCodex()` at line 46 selects exactly one journal, then launches the same helper. `cancel()` at line 89 sends SIGTERM to that helper.
- CLI: `BorrowCLI.execute()` in `Sources/BorrowCLI/main.swift:20` validates options, creates a run and recorder, and installs SIGINT/SIGTERM handlers that set `Recorder.cancelled`.
- Core: `Recorder.capture()` in `Sources/BorrowCore/Recorder.swift:23` attaches an optional read-only journal, saves a starting snapshot, creates an optional foreground child, registers workspace notifications, then samples until cancellation, child exit, logged turn outcome, source loss, or timeout.
- Normal stop paths converge at lines 161–164 for the final JSON/Markdown save. A `defer` at line 54 removes notification observers and sends SIGTERM only to the owned foreground child if it is still running. Throws during periodic/final persistence also pass through that cleanup.
- The app polls snapshots every second. Recorder snapshots refresh roughly every five seconds. Closing the app does not currently terminate the independent helper; timeout bounds it.

## Architecture and privacy boundaries

`BorrowCore` is the reusable boundary for an opt-in lease owner and evidence policy. The recorder process must own any assertion so closing the window cannot orphan a UI-owned hold while the task recorder continues. The UI should only request the mode and display its evidence.

`RunRecord` in `Sources/BorrowCore/Recording.swift:52` has schema version 2 and optional agent evidence. An optional power-evidence field with explicit acquired/released/failed/unknown states can preserve decoding of existing recordings. Existing `Sleep settings restored` is always skipped at lines 157–158; replace it with precise lease findings when applicable. Releasing Borrow's own assertion does not establish actual sleep, restoration of global settings, or absence of another app's assertion.

The Codex reader tracks turn IDs only in memory and persists fixed labels/counts. Its source is explicitly selected, and malformed/oversized data makes lifecycle completeness unknown. Release at an observed terminal outcome must retain those conservative rules: no idle-log or quiet-CPU completion inference. Incomplete/ambiguous streams can end only by explicit stop, source-loss handling, or the hard deadline. Source loss should release the hold but leave the agent untouched.

Arguments, environment, prompts, reasoning, code, tool output, session paths, and raw turn IDs must remain absent from persisted records. New assertion names and event labels should contain a fixed application name and run UUID only, avoiding task titles or executable arguments. Errors persisted via `localizedDescription` need review for incidental path disclosure.

No external packages are used. Framework dependencies are Foundation/AppKit/IOKit, with SwiftUI/Observation in the app. Keep any power adapter behind an injectable small protocol so evidence transitions and terminal-path cleanup can be tested independently of real system sleep.

## Lifecycle risks to resolve in the implementation plan

1. **Release before a durable final claim.** A `defer` alone runs after the final save/return expression. Explicitly release and update evidence before writing the final report, with an idempotent deferred fallback for every error path. A failed release cannot become `released` in the report.
2. **Crash/force-kill protection.** Native process-owned assertions should rely on documented owner-death cleanup and a bounded OS assertion timeout as a backstop. A Swift `defer` cannot execute after SIGKILL. Do not introduce a detached, unbounded keep-awake process.
3. **Launch and persistence failures.** Acquisition failure must prevent advertising protection. Launch errors, periodic save errors, and report-write errors must still release a previously acquired hold.
4. **Cancellation semantics.** Current cleanup requests foreground-child termination without waiting or proving exit. The recorder may return while a SIGTERM-ignoring child or descendants remain. Releasing its hold is still bounded, but must be described as release on recording end rather than proof all agent processes stopped. Do not sweep descendants or kill by process name.
5. **Observation does not own an agent.** Completion/cancellation/timeout/source loss must not terminate an observed Codex process. A logged end is a lifecycle signal, not semantic acceptance.
6. **Quit UX.** The native app currently allows a helper recording to outlive quitting. Either retain that behavior with an explicit visible lease deadline and explanation, or arrange a deliberate stop on app termination. Do not silently claim the hold ended merely because the window closed.
7. **Deadline and signal responsiveness.** Loop stop checks follow an optional connectivity request with a three-second timeout and a one-second sleep. This affects release latency; document and test a bound rather than promising instantaneous release.
8. **Closed-lid behavior is a separate feasibility result.** An acquired assertion only proves its API call succeeded. It must not turn charger-only/no-display clamshell operation into a compatibility guarantee. The separate Apple-source research determines the allowed product promise.

## Test and demonstration gaps

Existing tests cover foreground nonzero exit, cancellation, timeout, wrong-run proof rejection, report persistence, Codex source loss/completeness/privacy, old-schema decoding, and bounded physical-fixture evidence. They do not cover assertion acquisition/release, failure cleanup, crash cleanup, lease expiry, or post-release actual sleep.

Add meaningful tests using an injected lease adapter for normal child exit, nonzero exit, launch failure, cancellation, timeout, agent terminal outcomes, source loss, malformed stream timeout, and persistence throws. Require exactly-once release where a hold exists, no release where acquisition failed, and no unrelated-process termination. Preserve old recordings and privacy sentinels. Add an opt-in integration smoke test that observes only Borrow's own assertion in the power assertions inventory and verifies it disappears after exit/termination; this is not a physical lid test.

The only physical closed-lid evidence so far is 15 worker ticks during a short charger-connected interval under an existing `caffeinate` environment. The live Codex observations were open-lid. A new real-agent test must use one deliberately selected session, last 5–10 minutes, and record power/display/network/keep-awake conditions plus events in the closed interval. The operator must physically close and reopen the lid. An unrelated existing `caffeinate` process cannot be stopped automatically to create a cleaner baseline.

A native demo should show actual launch, requested protection state and deadline, real lifecycle events, observed release, and the exported report. Capture only the Borrow window; do not show the coding journal or terminal prompts/output. Mark shortened or edited footage clearly and keep unverified clamshell/sleep claims visible. The web-only `ui-demo` skill is not a suitable native capture method. Local native capture tooling exists, but actual screen access/capture should use the approved computer-use route and a deliberately framed Borrow window.

## Local inventory and release gaps

- Apple Silicon host with Swift 6.4 and Xcode selected; the selected Swift compiler passed strict code-signature verification.
- Codex CLI launcher is available through its installed npm script; Claude CLI is also present and its native binary passed strict code-signature verification. Neither agent was launched in this investigation, and no authentication/configuration or session content was read.
- A development signing identity exists. No Developer ID Application identity was found. Do not present the current ad-hoc build as notarized or ready for frictionless public installation.
- `scripts/build-app.sh` builds and ad-hoc signs in a temporary directory, packages `Borrow.app` plus helper, verifies signatures, and copies to ignored `dist/`. It produces the build host's architecture; the Apple Silicon local package and Intel CI package are different binaries.
- GitHub repository `Figo5/borrow` remains private and has no release entries. The current main workflow tests and builds on an Intel macOS runner, but does not upload artifacts or publish releases.

Release preparation should define a version source, architecture-labeled ZIPs (or a verified universal build), checksums, build metadata, installation/uninstallation instructions, a changelog, issue templates, a privacy statement, and a release checklist tied to actual results. Add CI artifact retention/build packaging if useful, without automatic public publishing. A draft prerelease can be prepared after implementation review; making the private repository public is a distinct visibility change and must not be bundled silently with release preparation.

The Ousel readiness gate remains in force. No archive/profile change should precede documented physical validation, a useful real-agent observation, and an honest demo.

## Recommended thin slices

1. Settle the documented power-control promise and report semantics first.
2. Add an opt-in bounded recorder-owned lease with testable cleanup and evidence, CLI control, and native UI state.
3. Prove API acquisition/release and all stop paths locally; retain clamshell and actual-sleep unknowns.
4. Prepare the real-agent physical test and native demo, then collect only the evidence the operator can actually produce.
5. Package a reviewable prerelease and public-facing documentation, preserving repository visibility until explicitly changed.

Implementation and commits wait for the orchestration approval gates.
