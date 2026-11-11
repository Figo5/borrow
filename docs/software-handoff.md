# Borrow software handoff

November 11, 2026 · 0.3.0 preview · commit and push approved

The user deferred the physical trial, reviewed the software handoff, and approved committing and pushing the private preview on November 11. Borrow remains private and Ousel remains unarchived. Tags, public releases, and visibility changes are outside this approval.

## What changed

- Bounded, opt-in recorder-owned wake holds: Off, supported idle prevention, and experimental AC-only operation.
- Accurate acquisition/cleanup evidence, including unknown readings, nothing created, stale snapshots, and transient persistence errors.
- Strict recording deadlines, safe cancellation, and partial-journal handling that preserves historical bookkeeping without ending a live observation prematurely.
- Native controls, app-instance ownership labels, first-run guidance, and redacted CLI error boundaries.
- Architecture-labelled packaging, checksums, source provenance, extracted-package verification in CI, documentation, and issue forms.

[Claude and OpenCode](claude-opencode-review.md) contributed independent reviews; Claude implemented core corrections and Codex integrated and verified the result.

## Verified

- 70 tests passed with all three native power checks enabled.
- The release binary passed 17 OS smoke cases, the actual paused-recorder deadline regression, two private-input sentinel checks, and 15 startup cancellation cases.
- Global power-setting output was unchanged around the runtime checks.
- A source copy inside an enclosing Git checkout retained `source-archive` provenance and passed extracted signature, architecture, version-resource, and help checks.
- Current code/test/build/workflow inputs match the archive's source manifest. The build is ad-hoc signed, not notarized.

Full details and coverage are in [the validation record](wake-lease-validation.md). Default hosted tests leave native power tests disabled; hosted checks for these uncommitted changes have not run.

## Local delivery

The corrected artifacts are in `dist/preview-2026-11-11/`:

- `Borrow-0.3.0-macOS-arm64.zip`: the corrected Apple Silicon app and helper.
- `Borrow-0.3.0-source.zip`: source, tests, build scripts, workflow, and current documentation; no Git history, local recordings, agent transcripts, or credentials.
- `SOURCE-MANIFEST.json`: SHA-256 values for code, test, build, and workflow inputs used by the binary build.
- `HANDOFF-SHA256SUMS`: integrity checks for the delivered archives and metadata.

Quit an old Borrow instance before opening the extracted corrected app. Native window control was unreliable during this session, so the already-open app bundle was not replaced with the new build and no new corrected-build UI verification is claimed. The delivered ZIP is the corrected artifact.

For the source archive, enter its top-level directory and follow [installation](installation.md). The [demo plan](demo.md) records completed rehearsal/export and the unresolved capture observations.

## Remaining work

The five-minute real-agent closed-lid trial is deferred. An existing unrelated keep-awake hold must be left alone unless the operator manages it; any resulting confounding must remain explicit. Actual post-task sleep, a finished native demo, and wider compatibility are unverified. Fresh UI verification is also pending.

At orchestration Gate 2, the user approved these commits:

1. `feat: add bounded wake holds and reliable task recording`
2. `docs: prepare Borrow preview and validation handoff`

Commit and push the reviewed changes and check hosted CI. The hosted result is recorded on the GitHub commit/checks; at the time of this handoff it has not run on the new commits. Public publication and Ousel's transition remain subject to their separate readiness conditions.
