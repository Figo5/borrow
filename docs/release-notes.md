# Borrow 0.3.0 preview — draft release notes

**Draft only: not published.** Software revision `7e9b97a`; physical compatibility and the final demonstration remain pending.

Borrow records what happened to a local task and can request a bounded wake hold for its recording. Choose recording-only **Off**, supported **Idle**, or **Experimental AC** mode. Borrow releases its own hold when the recording ends or its deadline expires, retaining separate evidence about work, process/logged lifecycle, power notifications, and hold release.

Idle mode prevents automatic idle sleep; it does not guarantee execution with the lid closed. Experimental AC mode explores the system-sleep assertion used by Apple's `caffeinate` tool. Apple's current SDK deprecates that underlying assertion, so charger-only/no-display compatibility is experimental and must be physically validated for the setup. See the [research](sleep-control-research.md).

**Hold released** means Borrow stopped requesting its hold. Other applications, settings, or activity can keep the Mac awake. Borrow does not force sleep or independently certify the agent's work.

## Candidate contents

- Native SwiftUI app and bundled foreground recorder.
- Independent-worker rehearsal, foreground-command recording, and explicitly selected read-only Codex log observation.
- Bounded hold modes and reportable hold lifecycle evidence.
- Architecture-labelled ZIP, compatibility `Borrow.zip`, `SHA256SUMS`, and `BUILD-INFO.txt`.

The review bundle contains separately labelled `Borrow-0.3.0-macOS-arm64.zip` and `Borrow-0.3.0-macOS-x86_64.zip`, `Borrow-0.3.0-source.zip`, architecture-specific build metadata, source-input hashes and combined SHA-256 checksums. See [artifact provenance and review status](preview-artifacts.md). The compatibility `Borrow.zip` remains in each individual build's output; it is omitted from the combined bundle to avoid an ambiguous architecture.

Build from source using the [installation guide](installation.md). This preview is ad-hoc signed, not Developer ID signed or notarized. A local Apple Silicon package and a hosted Intel package are distinct builds; availability of one does not imply both were validated.

## Validation to fill before publication

| Evidence | Candidate status |
| --- | --- |
| Automated/native tests and owned hold cleanup | Final revision: 73 local tests passed with native power integration enabled on November 12. Earlier 17 release-binary OS smoke cases and late-exit/privacy/startup regressions passed. |
| Build and packaging | Clean Apple Silicon build and extraction verification passed November 12. [Hosted Intel checks](https://github.com/Figo5/borrow/actions/runs/43086166624) passed on the same revision, including default tests, extraction verification and artifact upload. |
| Five-to-ten-minute real-agent closed-lid run | Deferred by the operator on November 11 |
| Actual post-task sleep | Unverified until separately observed |
| Native software UI | Fresh Apple Silicon build verified all modes, hold state/deadline, Stop, Quit cleanup, export and external-recorder ownership. Live Codex observation recorded three new tool completions and released its idle hold on Stop; agent continued. Zero closed-lid samples. |
| End-to-end demonstration | Software flow rehearsed; operator deferred capture November 12. Physical chapter awaits the hardware test. |
| GitHub release/tag/public visibility | Private unpublished draft `v0.3.0-preview` prepared with review assets; no tag reference created and repository remains private |

The earlier 30-second rehearsal observed 15 worker ticks while sampled closed and a matching final artifact. An existing `caffeinate` hold and DarkWake were present, so that run does not establish Borrow-only keep-awake behavior or long-run agent connectivity.

Please report the exact mode, Mac/OS, power/display setup, and the specific finding that was unexpected. Review exported reports before sharing; do not attach raw agent journals or prompts. See [privacy](privacy.md) and the [release checklist](release-checklist.md).
