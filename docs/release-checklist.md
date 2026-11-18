# 0.3.0-preview source-first release checklist

Validation for the public source-first **0.3.0 preview**. The build from source is ad-hoc signed.

## Source and software

- [x] Source, tests, version resource, and build script agree on 0.3.0.
- [x] **73 local tests passed** on November 18 with native power checks enabled, including native idle assertion acquisition, expiry, and release, plus Experimental AC acquisition and release.
- [x] A clean build and test run during the November 18 experiment completed with the lid closed: **70 default tests passed and three opt-in tests were skipped**.
- [x] `bash scripts/build-app.sh` produces an ad-hoc signed app and helper. No Developer ID or notarization claim.
- [x] README and release notes use the source-first route and the public case study and release links.

## November 18 physical evidence

- [x] One closed-lid comparison on **Mac14,9, macOS 27.0.1, AC power, built-in display only**; connectivity probes off; the existing keep-awake service was paused for the trials and restored afterward.
- [x] Off: 5m49s sampled span, **299-second** longest sampling gap, **zero** Codex events between closed samples; macOS logged sleep and wake. No Borrow hold was requested.
- [x] Experimental AC repeat: **7m04s** sampled span, **10** Codex events between closed samples; macOS logged sleep and wake. Borrow hold release was confirmed.
- [x] A clean Swift build and test run completed inside the closed-lid AC window (70 passed, three skipped).
- [x] The [published case study](https://gfiore.com/borrow) and [hardware report](https://gfiore.com/projects/borrow-hardware-comparison.md) record the setup, measurements, and limits.

## Native video

- [x] Native walkthrough captured and published with the case study; it presents the open-lid rehearsal and the separate saved closed-lid report.
- [x] Video linked from the release-facing documentation.

## Release materials

- [x] Release notes and README state the source-first build route and the tagged source archives.
- [x] No notarized, Developer ID, universal-build, or general-compatibility claim.
- [x] November 12 prebuilt assets and the software handoff are marked historical and are not advertised as this release's downloads.
- [x] Remaining limits stated: physical unplug, battery-only operation, provider connectivity, and immediate post-release sleep.
- [x] Ousel is archived and its README points to the published Borrow case study.
- [x] Review reachable source history and available GitHub Actions logs before changing visibility.
- [ ] **Physical unplug and battery-only test. Not performed; no unplug claim.**

The November 12 prebuilt archives remain internal review history only. They are not rewritten or reissued by this source-first preview.
