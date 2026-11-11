# Swift and application review

November 10, 2026 · 0.3.0 preview candidate · uncommitted orchestration diff

**Verdict: approve the reviewed source.** No unresolved critical, high, or concrete medium findings remain in the core, native application, or CLI changes reviewed here. Packaging and physical validation are separate checks; this verdict does not establish a public release or closed-lid compatibility.

## Scope and method

Reviewed the complete changed Swift files and their callers/tests: `WakeLease.swift`, `Recorder.swift`, `Recording.swift`, `MachineProbe.swift`, `BorrowVersion.swift`, the CLI, the native application, and `WakeControls.swift`, including untracked new files. Applied ECC's Swift reviewer and code reviewer roles. SwiftLint is not installed; no lint pass is claimed.

Checked task/hold ownership, main-actor state, signal/cancellation handling, timeout and error cleanup, read-only external-agent behavior, report privacy, stale-state wording, and the distinction between assertion acquisition, hold release, sampled progress, and actual sleep. No reviewer code changes or commits were made.

## Findings resolved before approval

1. **Acquisition failure hid successful cleanup.** The original failure branch called release but retained only a failed hold state. It now uses the common release path, preserves `acquisitionFailed`, and records successful release and timestamp separately. The acquisition finding still fails while the release finding can be observed.
2. **Native selection could adopt another recorder's report.** Selecting the first new folder allowed a concurrent CLI run to become the native run used during Quit verification. Selection now requires the new recording's `recorderPID` to match the launched process before assigning its active run ID.

Rechecked both fixes in the final source. Cancellation during acquisition is checked before foreground launch. Final persistence follows release; failed/unconfirmed release remains visible, and the CLI returns failure for an unconfirmed release. Experimental helper launch is not treated as assertion evidence: its own PID's assertion is inspected. Idle inventory queries distinguish a successful absence result from unavailable inventory. Timeout rounding avoids whole-second truncation by the OS.

## Verification supplied by the implementer

The implementer reported **48 passing tests** with `BORROW_POWER_INTEGRATION=1`, including actual native idle acquisition/release, experimental AC helper acquisition/release, and native timeout expiry. The reviewer inspected those tests and relied on the shared green run rather than repeating the full suite.

| Scope | Line coverage | Region coverage |
| --- | --- | --- |
| WakeLease | 93.21% | 82.61% |
| Recorder | 90.08% | 82.78% |
| BorrowCore overall | 88.72% | 81.92% |

These native lease checks are runtime power-API evidence, not physical lid-close tests. Packaged resource lookup, native UI behavior, GitHub checks, the longer real-agent rehearsal, actual post-task sleep, and the demo must retain their own verification status.

## Packaged CLI verification

After the source review, the reviewer ran `bash scripts/build-app.sh` successfully on Apple Silicon. The packaging scratch directory was removed by the script before extracting the labelled ZIP into a fresh temporary directory. The extracted helper's `--version` returned exit zero and `0.3.0`, demonstrating resource lookup without access to the build directory. The plist reported version `0.3.0`, build `4`, and `arm64`; both app and helper were executable `arm64` binaries. The extracted app passed `codesign --verify --deep --strict`, and both entries in `SHA256SUMS` verified. This is ad-hoc signature/integrity evidence, not Developer ID signing or notarization. GUI verification remains separate.
