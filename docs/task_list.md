# Borrow: task-scoped wake control, physical validation, demo, and release

November 10, 2026 · ECC `orch-add-feature` · size: **large**

**Gate 1: approved by the user on November 10, 2026.** The approved scope includes Off by default, supported idle-sleep prevention, and an explicitly experimental AC-only hold, plus real-agent physical validation, an authentic demo, and release preparation. Implementation may proceed through testing and review. Gate 2 still requires a reviewed diff and proposed commit messages before committing.

**November 11 handoff:** Claude Code and OpenCode reviewed the candidate; core and integration corrections pass 70 tests plus fresh CLI/OS/package verification. The user deferred the physical trial and approved Gate 2 for committing and pushing the private software preview. Native video and corrected-build UI verification remain pending because native controls were unreliable. Source and reviewable archives are prepared; hosted checks follow the push. Publication and Ousel archival are not complete. See [the collaboration record](claude-opencode-review.md).

## Intended outcome and feasibility decision

Give an explicitly selected task a bounded wake hold, release Borrow's own hold when observation ends, and retain evidence of what happened with the lid closed. Preserve the existing local rehearsal and read-only Codex observation modes.

The supported idle-sleep assertion does **not** prevent lid-close sleep. Apple's older system-sleep assertion remains implemented by its built-in `caffeinate -s` command on AC power, but the current SDK marks that assertion deprecated/unsupported. A charger-only Mac without an external display therefore requires a clearly labeled experiment, not a compatibility promise. See [sleep-control research](sleep-control-research.md).

Proposed modes are **Off** by default, **Prevent idle sleep**, and **Experimental AC hold**. The experimental mode uses only Apple's installed `caffeinate`, bounded to the recorder process and a timeout; it does not change `pmset` settings, install a service, or disable clamshell protections through private APIs. A physical test decides what can be claimed for this particular setup.

Releasing Borrow's hold means only that Borrow no longer requests wakefulness. Other applications, user activity, system policy, or hardware can keep the Mac awake. Borrow will not force sleep or describe release as proof that sleep occurred.

## Constraints carried forward

- No global power-setting, agent permission/configuration, or system-service changes.
- Never terminate or disable another application's wake hold. The operator controls their existing keep-awake setup during an isolated physical comparison.
- Preserve prompts, arguments, output, source paths, environment contents, and code outside persisted reports. Capture only fixed lifecycle/evidence labels and bounded machine observations.
- Own only explicitly launched foreground tasks and Borrow's own wake helper. Cancellation of read-only Codex observation leaves the agent running.
- No correctness inference from process exit, logged turn end, network reachability, or a quiet stream.
- A missing physical test remains missing. Open-lid integration tests cannot substitute for it.
- Ousel remains unarchived until its existing readiness gate is actually satisfied.

## Ordered task list

### 1. Add an owned, bounded wake lease

**Files:** new `Sources/BorrowCore/WakeLease.swift`, new `Tests/BorrowCoreTests/WakeLeaseTests.swift`, `Sources/BorrowCore/Recorder.swift`.

**Depends on:** Gate 1 approval. **Risk:** high; this is the power-control boundary.

- Write failing tests for explicit acquisition, release exactly once, acquisition failure, expiration, owner exit, cancellation, and unexpected helper exit.
- Put lease ownership in the recorder process, which already owns the recording lifecycle. The UI must not own a second independent hold.
- Use the supported IOPM idle-sleep assertion with an OS timeout that releases it; this mode does not keep a closed lid awake.
- For experimental AC mode, launch the absolute system `caffeinate` binary with its AC-only system assertion, recorder-PID lifetime bound, and finite timeout. Do not use a utility-command form that makes its timeout ineffective.
- A launched helper is only a requested/provisional hold. Confirm its actual Borrow-owned assertion in read-only OS assertion inventory, keyed to the owned process; monitor its lifetime. Show active protection only after confirmation, and never after the helper or assertion disappears unexpectedly.
- Reject experimental mode when AC is unavailable or unknown. If AC is lost during a run, end Borrow's lease and recording with an explicit reason; the observed agent remains untouched. An owned foreground command follows the existing cancellation boundary.
- Release on success, nonzero exit, launch failure, observation-source loss, cancel, timeout, thrown error, and normal helper shutdown. Explicitly update release evidence before final JSON/Markdown persistence, with an idempotent deferred cleanup fallback for errors. An OS-owned timeout/owner-death bound must remain even if the recorder crashes.

**Acceptance:** tests cover every exit branch; a disposable integration run shows only Borrow's own assertion appearing and disappearing. Existing global settings remain unchanged. A crash check shows the owned hold disappears or expires within its documented bound.

### 2. Expose control and report its actual lifecycle

**Files:** `Sources/BorrowCore/Recording.swift`, `Sources/BorrowCore/Recorder.swift`, `Sources/BorrowCLI/main.swift`, `Sources/BorrowApp/BorrowApp.swift`, `Tests/BorrowCoreTests/RecordingTests.swift`, `Tests/BorrowCoreTests/RecorderTests.swift`.

**Depends on:** task 1. **Risk:** medium; public CLI and report contracts change.

- Add a backward-compatible optional power-evidence field: requested mode, acquisition result, Borrow-owned release result/reason, and timestamps. Old recordings retain their original meaning.
- Add explicit CLI and native controls for the three modes. Preserve opt-in connectivity and the existing recording time limits; add a 10-minute native duration choice for validation.
- Clearly distinguish the supported idle mode from the experimental AC mode before starting. Show a live hold state and the deadline while it is active.
- Replace the unconditional “no wake assertion” copy with run-specific wording. Report an observed release separately from actual post-task sleep, which remains unverified unless independent evidence exists.
- For Codex observation, release when the existing complete-stream lifecycle rule ends observation; malformed streams do not invent completion. A cancelled/timed-out observation releases Borrow's hold while leaving Codex running.
- When quitting the native app with an active owned recorder, stop that recording and allow its cleanup to finish; do not leave an undisclosed hold behind. Keep plain window closing behavior explicit.

**Acceptance:** existing 25 tests still pass; new tests cover older JSON, all modes, no hold by default, misleading-copy regressions, acquisition/release failures, cancellation, timeout, and Codex source/lifecycle edge cases. Native rehearsal and native Codex observation display the same lease evidence as exported Markdown.

### 3. Verify the real lifecycle before a lid-close trial

**Files:** tests above, `docs/validation.md`, new `docs/wake-lease-validation.md`.

**Depends on:** tasks 1–2. **Risk:** medium.

- Run Swift tests in a temporary scratch directory and obtain coverage for the new power-control/lifecycle code; target at least 80% without tests that merely repeat implementation.
- Exercise actual open-lid success, nonzero exit, cancel, timeout, missing executable, unexpected owned-helper exit, and recorder interruption/crash in disposable directories.
- Compare read-only assertion snapshots before/during/after each relevant run. Filter to Borrow-owned identifiers in saved evidence rather than dumping unrelated processes or arguments.
- Verify privacy sentinels and release handling when persistence fails. Read-only observation must never terminate its agent.
- Measure the cancellation/release latency bound, including the optional connectivity request and sampling loop; avoid an instantaneous-release promise.
- Package and check the app, CLI help, version consistency, ZIP architecture, and ad-hoc signature. Run independent code and security reviews; resolve critical/high findings before Gate 2.

**Acceptance:** the report accurately reflects every lifecycle outcome and cleanup limitation. No test changes global power settings or kills another process. Existing rehearsal and Codex features remain working.

### 4. Perform a 5–10-minute real-agent closed-lid comparison

**Files:** new `docs/physical-agent-validation.md`, sanitized evidence under `docs/evidence/`, exported reports under the project output directory.

**Depends on:** task 3 and operator participation. **Risk:** high uncertainty; this is a feasibility experiment.

- Use an actual useful Codex task, such as implementation review and validation of Borrow, through an explicitly selected live session. Observe genuine lifecycle events; do not insert dummy sleeping work and call it agent progress.
- Record hardware, OS, AC/no-display setup, network conditions, selected mode, start/end times, and known ambient wake assertions without preserving prompts or session paths.
- Ask the operator to stop their existing keep-awake tool themselves when they can identify it. Borrow must not terminate the existing long-lived `caffeinate` process. If the environment cannot be isolated, label the result confounded.
- Compare Borrow off with Borrow's experimental AC hold on the same setup. Keep recording long enough for a 5–10-minute closed-lid interval, then reopen and inspect both event delivery and system-power evidence.
- Establish what is observed: events appended between closed-lid samples, logged outcome, lease release, gaps, power notifications, and independent task acceptance checks. Compare logged event timestamps with the sampled append interval; append-while-closed is not automatically execution-while-closed because delivery can be delayed. Preserve that distinction and any unrelated assertions as caveats.
- Observe post-task power behavior without forcing sleep or changing global idle timers. If actual sleep is not independently observed, report only the verified release.
- Preserve a failed or inconclusive run as evidence. If experimental mode fails, ship no charger-only/no-display success claim; document the supported idle mode and the measured limitation.

**Acceptance:** a real report exists for the attempted physical setup and honestly states success, failure, or uncertainty. The original 30-second confounded heartbeat run is preserved. Wider compatibility remains unverified until other setups are tested.

### 5. Record an authentic native demo

**Files:** new `docs/demo.md`, user-facing `Borrow-demo` video under the output directory, a still/preview only if useful.

**Depends on:** tasks 2–4. **Risk:** medium; screen capture must preserve privacy.

- Discover the current native UI, rehearse the flow through computer-use controls, then record the real Borrow window using a supported native recording route.
- Show mode selection, a live task/observation, the deadline/hold state, the real report after reopening, and release of Borrow's own hold. Include the measured limitations in the demo.
- Use an explicit elapsed-time cut for the lid-close interval rather than presenting an edited interval as continuous screen evidence. If the experiment fails, demonstrate that useful failure honestly.
- Keep prompts, terminal output, other apps, notifications, and unrelated recordings outside the capture. Inspect the completed video before including it in release materials.

**Acceptance:** the demo is a playable native recording with real evidence and no fabricated task/sleep states. If screen-recording permission is unavailable, leave the video incomplete and provide the rehearsed shot list until the operator enables capture.

### 6. Prepare a public preview people can install and understand

**Files:** `README.md`, `docs/product-brief.md`, new `docs/release-checklist.md`, new `CHANGELOG.md`, `scripts/build-app.sh`, `.github/workflows/swift.yml`, relevant issue templates.

**Depends on:** tasks 3–5; copy follows measured physical results. **Risk:** medium.

- Rewrite the main promise around actual behavior: temporary owned wake control plus evidence, supported idle prevention, and the exact status of experimental closed-lid operation.
- Give a short first-run flow, source-build instructions, mode requirements, cancellation/quit semantics, privacy details, compatibility limits, and links to the authentic demo/reports.
- Prepare reproducible per-architecture packaging, explicit macOS/architecture labels, version metadata, and checksums. Add CI validation/artifact generation without embedding signing secrets.
- Prepare a source-first preview because the local machine has no Developer ID Application identity. Do not describe an ad-hoc ZIP as notarized or instruct users to bypass OS security protections. A notarized binary remains blocked until a suitable identity and notarization access are supplied.
- Prepare release notes and a reviewable draft release/assets. Keep the currently private repository private during preparation; public visibility and publication are distinct final actions after readiness and review.
- Recheck Ousel's readiness list. Only if all gates genuinely pass should the existing archive authorization be used for its notice, portfolio/profile link update, and archival; otherwise name the missing items.

**Acceptance:** a new user can understand what Borrow does, build it, perform a first run, stop it, and interpret its report. Packaging and CI checks pass on the reviewed commit. Publication and Ousel archival never substitute for unfinished physical validation or distribution work.

## Review and commit gate

Implementation delegates to the TDD phase, followed by independent Swift/code review and security review (paths, subprocesses, external probes, and release workflow inputs are in scope). Resolve critical/high findings and material test failures before presenting the final diff.

At Gate 2, present the actual diff, validation results, physical-test outcome, demo, release assets, remaining blockers, and proposed logical commits, for example:

- `feat: add bounded task-owned wake leases`
- `feat: expose wake controls and lease evidence`
- `test: document real-agent power lifecycle validation`
- `docs: prepare Borrow public preview and demo`

The user approved implementation commits and their push on November 11. Release publication, repository-visibility change, and Ousel archival still require their applicable readiness conditions.
