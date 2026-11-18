# Borrow software handoff

> **Historical report — November 12, 2026.** Preserved as written. Its deferred video and physical-trial statements are historical; see the [release notes](release-notes.md) and [release checklist](release-checklist.md) for the November 18 source-first preview.

Updated November 12, 2026 · 0.3.0 preview · software revision `7e9b97a`

The user deferred the physical trial, reviewed the software handoff, and approved committing and pushing the private preview on November 11. Borrow remains private and Ousel remains unarchived. Tags, public releases, and visibility changes are outside this approval.

## What changed

- Bounded, opt-in recorder-owned wake holds: Off, supported idle prevention, and experimental AC-only operation.
- Accurate acquisition/cleanup evidence, including unknown readings, nothing created, stale snapshots, and transient persistence errors.
- Strict recording deadlines, safe cancellation, and partial-journal handling that preserves historical bookkeeping without ending a live observation prematurely.
- Native controls, app-instance ownership labels, first-run guidance, and redacted CLI error boundaries.
- Architecture-labelled packaging, checksums, source provenance, extracted-package verification in CI, documentation, and issue forms.

Core corrections and their verification are recorded in [the validation findings](validation-findings.md).

## Verified

- 70 tests passed with all three native power checks enabled.
- The release binary passed 17 OS smoke cases, the actual paused-recorder deadline regression, two private-input sentinel checks, and 15 startup cancellation cases.
- Global power-setting output was unchanged around the runtime checks.
- A source copy inside an enclosing Git checkout retained `source-archive` provenance and passed extracted signature, architecture, version-resource, and help checks.
- Current code/test/build/workflow inputs match the archive's source manifest. The build is ad-hoc signed, not notarized.

Hosted extraction subsequently caught a version-resource search-path difference. A focused loader fix and three regression tests were added; the follow-up suite discovered 73 tests, with 70 passing and three opt-in native tests skipped. Package verification was repeated after the fix. GitHub records the final hosted result; this fix does not alter the power-lifecycle behavior validated above.

On November 12, the final revision passed all **73 tests with native power integration enabled**, including actual idle acquisition/expiry/release and experimental AC assertion acquisition/release. The clean-checkout Apple Silicon build and extracted-package verification also passed. No lid-close or unplug stimulus was used.

[GitHub Actions run 43086166624](https://github.com/Figo5/borrow/actions/runs/43086166624) passed on `7e9b97a`, including default tests, Intel app build, extracted-package verification, and artifact upload. The hosted default suite passed 70 tests and skipped three opt-in native checks; these are distinct from the local 73-test native-enabled run. Full details and historical coverage are in [the validation record](wake-lease-validation.md).

## Local delivery

The current delivery folder is `dist/preview-2026-11-12/`:

- `Borrow-0.3.0-macOS-arm64.zip`: the corrected Apple Silicon app and helper.
- `Borrow-0.3.0-macOS-x86_64.zip`: the Intel package retained from the successful hosted run; no local Intel UI test is implied.
- `Borrow-0.3.0-source.zip`: source, tests, build scripts, workflow, and current documentation; no Git history, local recordings, agent transcripts, or credentials.
- `SOURCE-MANIFEST.json`: SHA-256 values for code, test, build, and workflow inputs used by the binary build.
- `HANDOFF-SHA256SUMS`: integrity checks for the delivered archives and metadata.
- Architecture-specific `BUILD-INFO` files and `PREVIEW-STATUS.md`: provenance, signing, verification, and deferred work.

See [artifact provenance and review status](preview-artifacts.md) for the exact asset map and checksum command.

A private, unpublished `v0.3.0-preview` draft is prepared under [GitHub Releases](https://github.com/Figo5/borrow/releases), with ten review assets. It targets software revision `7e9b97a`. No tag reference was created and repository visibility remains private. The draft does not satisfy the remaining physical or publication gates.

The obsolete default `dist/Borrow.app` was replaced with the clean `7e9b97a` build after the operator closed the old instance. The November 11 delivery remains historical; use the November 12 folder for the current source and release materials. Quit an old Borrow instance before opening another build.

For the source archive, enter its top-level directory and follow [installation](installation.md). The [demo plan](demo.md) records completed rehearsal/export and the unresolved capture observations.

## Remaining work

The fresh native UI pass verified all modes, hold/deadline display, Stop, Quit cleanup, restart defaults, report export and external-recorder ownership. A native live Codex observation recorded three new tool completions and confirmed idle-hold release on Stop while the agent continued running. [The evidence](wake-lease-validation.md#november-12-final-software-check) records zero closed-lid samples. Native capture was deferred by the operator on November 12 after rehearsal; no video is claimed.

The five-minute real-agent closed-lid trial and physical unplug test remain deferred. An existing unrelated keep-awake hold must be left alone unless the operator manages it; any resulting confounding must remain explicit. Actual post-task sleep, a finished native demo, and wider compatibility are unverified.

The user approved these commits:

1. `feat: add bounded wake holds and reliable task recording`
2. `docs: prepare Borrow preview and validation handoff`

Those commits were pushed, followed by `fix: resolve packaged resources across Swift toolchains`; the final hosted checks passed. The November 12 documentation refresh is a separate reviewable change. Public publication and Ousel's transition remain subject to their separate readiness conditions.
