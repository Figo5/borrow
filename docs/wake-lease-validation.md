# Wake-lease lifecycle validation

Initial evidence: November 10, 2026. Corrected candidate: November 11, 2026. Borrow 0.3.0 · Apple Silicon.

These checks validate Borrow-owned assertion lifecycle and reporting. They were performed with the lid open and do not establish closed-lid compatibility, uninterrupted agent execution, or actual post-task sleep. The experimental AC hold remains experimental; see [the source-based feasibility findings](sleep-control-research.md).

## November 10 automated checks

The complete Swift Testing run passed **48 tests**, including the three explicitly enabled native power-integration tests. Default tests leave those native tests disabled and use injected lease backends for deterministic lifecycle checks.

```sh
BORROW_POWER_INTEGRATION=1 swift test --scratch-path /private/tmp/borrow-core-tdd-20261110 --enable-code-coverage
```

The native tests acquired and released only their own supported idle assertion and experimental AC helper assertion. They confirmed actual assertion state rather than treating a running helper as protection. An idle assertion was also allowed to expire through its OS timeout before cleanup checked that it was absent. The experimental native test requires known AC power and is disabled otherwise.

New deterministic checks cover default-off behavior, acquisition failure without task launch, confirmed release before final persistence, nonzero foreground exit, cancellation, timeout, launch/storage failure, release failure, assertion loss, expiration, AC loss/unknown AC, helper launch/early exit, idempotent cleanup, cancellation during acquisition, and Codex terminal/source-loss/malformed-stream paths. Older recordings still decode, and content sentinels remain absent from reports. Observation tests never launch or terminate an agent.

Two regressions were observed failing before correction:

- Cancellation arriving during acquisition could still launch the foreground task. A pre-launch cancellation guard now prevents that launch and releases the acquired hold.
- Passing a fractional idle timeout could let the OS assertion expire before the recording deadline. Both hold backstops now round remaining timeout seconds upward. The real expiry test verifies cleanup can confirm an already expired assertion's absence without treating an unknown inventory result as absence.

The initial test-first build also failed because the new lease API did not exist yet. The subsequent implementation brought the new behavior to green.

## November 10 coverage snapshot

Coverage was collected from the complete 48-test run, including native integration, using `llvm-cov`. Generated resource accessors and tests were excluded from this summary.

| Source | Line coverage | Region coverage | Function coverage |
| --- | ---: | ---: | ---: |
| `WakeLease.swift` | 93.21% | 82.61% | 86.49% |
| `Recorder.swift` | 90.08% | 82.78% | 73.68% |
| `Recording.swift` | 89.84% | 85.82% | 83.72% |
| Entire `BorrowCore` | 88.72% | 81.92% | 83.97% |

The toolchain did not emit branch coverage data. These figures are not a claim of branch coverage or physical compatibility. Notification callbacks and some hardware/error paths remain unexercised.

## Actual CLI and OS smoke checks

Seventeen open-lid process checks passed. The table groups repeated modes while preserving the observed outcomes.

The [sanitized smoke summary](evidence/wake-lease-smoke-summary.json) preserves each case. A null external-absence field means that additional external check was not performed.

| Case | Modes | CLI result | Recorded status and hold evidence |
| --- | --- | --- | --- |
| Successful foreground command | Off, idle, experimental AC | `0` | Recording completed; off has no power evidence; requested holds released |
| Nonzero foreground command | Off, idle, experimental AC | `1` | Recording completed with nonzero command exit; requested holds released |
| Missing executable | Idle, experimental AC | `1` | Interrupted; hold released with `launchFailed` reason |
| Three-second timeout | Idle, experimental AC | `124` | Timed out; hold released with `timedOut` reason |
| Cancellation | Idle, experimental AC | `130` | Cancelled; hold released with `cancelled` reason |
| Recorder force-killed | Idle, experimental AC | Process terminated by signal 9 | Last snapshot remains running/active; independent OS check found the owned assertion gone |
| Recorder stopped until hold expiry, then continued | Idle, experimental AC | `124` | Timed out; owned assertion absent and final release confirmed |
| Owned experimental helper terminated early | Experimental AC | `1` | Interrupted; hold loss retained as an issue; cleanup released with `holdLost` reason |

The seven cancellation/crash/stopped-recorder/helper-exit cases additionally checked Borrow-owned assertion absence externally through a read-only OS inventory. The other cases relied on the lease backend's confirmation recorded in the result; they did not receive a separate external absence check. A missing external check is not a failed check or an additional verification claim.

A force-killed recorder cannot write a truthful final release record. Its stale JSON deliberately still says running/active. The independent absence check establishes OS cleanup for that attempt, not that the recorder observed its own release. The app must treat stale snapshots and passed deadlines conservatively.

Read-only `pmset -g custom` output was byte-for-byte identical before and after the lifecycle checks. No global sleep-setting change was made. Only explicitly owned disposable recorder/task/helper processes were signalled; no other application's hold was stopped.

## CLI validation and native Quit

Five additional CLI validation cases—invalid wake mode, a missing wake-mode value, rehearsal duration above the 600-second limit, a relative executable path, and an unavailable selected source—all returned `1`. The selected source path remained redacted. The CLI can print Borrow's requested output directory before source validation; that output path is distinct from the selected session path. Launch and source errors use fixed labels instead of persisting raw source paths or arguments.

In the native 0.3.0 candidate, a fresh thirty-second experimental AC rehearsal confirmed acquisition. Quitting after approximately eight seconds stopped the owned recorder; its result was cancelled with release confirmed. Reopening showed version 0.3.0 and the default-off wake mode. This is an actual native cleanup check, not a lid-close test.

Two network-disabled cancellation measurements finished in **1.141 seconds** for idle mode and **1.197 seconds** for experimental AC mode on this host. These are observations, not a guaranteed upper bound. The sampling loop, optional connectivity request, assertion confirmation, helper shutdown, scheduling, and storage can add latency. Borrow does not promise instantaneous release.

## Source-first installation check

A separate copy of the source, fixtures, version resource, build script, and license was tested and packaged outside the checkout, with no Git metadata or shared build cache. The default suite passed 45 tests, with the three opt-in native power tests disabled. The generated package correctly identified its source as `source-archive`. After deleting the source/build paths, a freshly extracted helper returned `0.3.0`; its architecture, ad-hoc signature, and ZIP checksums verified. This checks the source-first installation path, separately from the native-integration run above.

## November 11 corrected candidate

After the [Claude/OpenCode reviews](claude-opencode-review.md), the complete corrected suite passed **70 tests with native integration enabled**, including all three real power tests. Unknown readings remain unknown, no-created-resource cleanup does not invent a release, stale exports are labelled, and partial log records cannot prematurely end an observation. Startup cancellation or an already-passed deadline creates no hold or foreground task. Completion first observed after the deadline is not reported as timely completion.

| Source | Line coverage | Region coverage |
| --- | ---: | ---: |
| `WakeLease.swift` | 94.51% | 84.13% |
| `Recorder.swift` | 92.33% | 85.19% |
| `Recording.swift` | 92.31% | 90.80% |
| `CodexEvents.swift` | 94.12% | 93.33% |
| All `BorrowCore` | 90.71% | 85.35% |

Branch data was not emitted. These are software coverage figures, not physical compatibility evidence.

The corrected **release** binary passed the [17 OS smoke cases again](evidence/wake-lease-smoke-2026-11-11.json). Further [CLI regressions](evidence/cli-regressions-2026-11-11.json) established:

- A four-second foreground command under a three-second recording limit, with the owned recorder stopped for five seconds and resumed, now exits `124` with `timedOut` and no invented timely exit result. The old package reproduced exit `0`/completed for this sequence.
- Two deliberately private-looking invalid input sentinels were absent from stdout/stderr; both calls exited `1`.
- Fifteen immediate startup cancellations ended promptly: six by default SIGTERM before handler setup and nine through cancellation exit `130`. No full-length run was observed.
- Read-only global power-setting output was unchanged before and after the checks.

A copied source archive nested inside another Git repository built successfully and correctly reported `source-archive`, rather than the enclosing revision. Its extracted ad-hoc signature, architecture, helper version/help, and resource lookup passed `scripts/verify-package.sh`. CI now contains this extraction check; the uncommitted workflow has not run on GitHub.

The final archive is under `dist/preview-2026-11-11/`. It was built separately because native UI control was unreliable; no fresh corrected-build UI pass or video is claimed. The user deferred the physical trial on November 11. Release of a hold still does not establish actual system sleep.

## Remaining evidence

- A new five-to-ten-minute real-agent closed-lid comparison was deferred by the user on November 11. The previous short worker test was confounded by an existing `caffeinate` hold and is preserved in [its original notes](physical-lid-close.md).
- Actual AC unplug behavior is covered through an injected backend; a physical unplug test has not been performed here.
- No check establishes battery-only experimental support, thermal/battery cutoffs, provider connection continuity, or another Mac/macOS version.
- Release permits sleep; actual post-task sleep remains unverified. Borrow neither forces sleep nor removes other applications' assertions.
- Public installation signing/notarization and the physical demo remain separate release requirements. This validation does not satisfy Ousel's replacement gate by itself.
