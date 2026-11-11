# Borrow 0.3.0 preview — draft release notes

**Draft only: not published.** Fill in the final validation and artifact details after the candidate is tested.

Borrow records what happened to a local task and can request a bounded wake hold for its recording. Choose recording-only **Off**, supported **Idle**, or **Experimental AC** mode. Borrow releases its own hold when the recording ends or its deadline expires, retaining separate evidence about work, process/logged lifecycle, power notifications, and hold release.

Idle mode prevents automatic idle sleep; it does not guarantee execution with the lid closed. Experimental AC mode explores the system-sleep assertion used by Apple's `caffeinate` tool. Apple's current SDK deprecates that underlying assertion, so charger-only/no-display compatibility is experimental and must be physically validated for the setup. See the [research](sleep-control-research.md).

**Hold released** means Borrow stopped requesting its hold. Other applications, settings, or activity can keep the Mac awake. Borrow does not force sleep or independently certify the agent's work.

## Candidate contents

- Native SwiftUI app and bundled foreground recorder.
- Independent-worker rehearsal, foreground-command recording, and explicitly selected read-only Codex log observation.
- Bounded hold modes and reportable hold lifecycle evidence.
- Architecture-labelled ZIP, compatibility `Borrow.zip`, `SHA256SUMS`, and `BUILD-INFO.txt`.

Build from source using the [installation guide](installation.md). This preview is ad-hoc signed, not Developer ID signed or notarized. A local Apple Silicon package and a hosted Intel package are distinct builds; availability of one does not imply both were validated.

## Validation to fill before publication

| Evidence | Candidate status |
| --- | --- |
| Automated/native tests and owned hold cleanup | November 11 corrected candidate: 70 tests, 17 release-binary OS smoke cases, late-exit/privacy/startup regressions and extracted-package verification passed; hosted checks pending |
| Five-to-ten-minute real-agent closed-lid run | Deferred by the operator on November 11 |
| Actual post-task sleep | Unverified until separately observed |
| End-to-end demonstration | Pending capture |
| GitHub release/tag/public visibility | Not changed by release preparation |

The earlier 30-second rehearsal observed 15 worker ticks while sampled closed and a matching final artifact. An existing `caffeinate` hold and DarkWake were present, so that run does not establish Borrow-only keep-awake behavior or long-run agent connectivity.

Please report the exact mode, Mac/OS, power/display setup, and the specific finding that was unexpected. Review exported reports before sharing; do not attach raw agent journals or prompts. See [privacy](privacy.md) and the [release checklist](release-checklist.md).
