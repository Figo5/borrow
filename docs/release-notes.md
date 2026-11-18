# Borrow 0.3.0 preview — source-first prerelease notes

Prepared November 18, 2026 · `v0.3.0-preview` · [Case study](https://gfiore.com/borrow) · [Hardware report](https://gfiore.com/projects/borrow-hardware-comparison.md)

Borrow records a local task and can request a bounded wake hold for the recording. Choose recording-only **Off**, supported **Idle**, or **Experimental AC**. Borrow releases only its own hold and keeps work, process or logged lifecycle, power notifications, sampling gaps, and hold release as separate findings.

**Source-first.** Build locally from the tagged source ZIP, tarball, or Git checkout. The local build uses an ad-hoc signature.

## Build from source

Requires macOS 14 or later and Swift 6 through Xcode or Command Line Tools. No third-party dependencies.

```sh
git clone --branch v0.3.0-preview https://github.com/Figo5/borrow.git
cd borrow
swift test --scratch-path "$(mktemp -d)"
bash scripts/build-app.sh
open dist/Borrow.app
```

You can also download the source ZIP or tarball from the [release tag](https://github.com/Figo5/borrow/releases/tag/v0.3.0-preview). The build is ad-hoc signed; it is not Developer ID signed or notarized. See [installation](installation.md).

## Demo script and command report

```sh
swift build
bash scripts/demo-recording.sh "$(swift build --show-bin-path)/borrow"
```

The script records two real foreground commands with wake holds and connectivity checks off, then prints one report path per case.

The corrected native command report uses the command findings: the title is the foreground executable's basename, and `Command exit` records `/usr/bin/true` as observed with exit 0 and `/usr/bin/false` as failed with exit 1. `recording.json` stores the run kind as `command`. If no exit is observed before cancellation or timeout, it remains unverified rather than failed. Process exit does not establish task correctness or child-process completion.

## Validation

| Evidence | Result |
| --- | --- |
| Local tests with native power checks (November 18) | **73 passed**, including native idle assertion acquisition, expiry, and release, plus Experimental AC acquisition and release |
| Build run during the November 18 hardware experiment | **70 passed and three opt-in tests skipped**; the clean Swift build and test run finished with the lid closed |
| Off, closed lid | 5m49s sampled span, **299-second** longest sampling gap, **zero** Codex events between closed samples, macOS logged before-sleep and wake; no hold requested |
| Experimental AC, closed lid | **7m04s** sampled span, **10** Codex events between closed samples, clean build and test completed, macOS logged before-sleep and wake; Borrow hold release confirmed |

Observed setup: **one Mac14,9 on AC power, macOS 27.0.1, with only the built-in display detected at preflight.**

Unverified: physical unplug, battery-only operation, provider connectivity, and immediate sleep after release. Hold release permits normal sleep; it does not establish that sleep occurred.

The [November 12 preview artifacts](preview-artifacts.md) and [software handoff](software-handoff.md) are preserved as historical reports for the older build and are not current release guidance.

Report the exact mode, Mac and OS, power and display setup, and the finding that was unexpected. Review exported reports before sharing; do not attach raw agent journals or prompts. See [privacy](privacy.md) and the [release checklist](release-checklist.md).
