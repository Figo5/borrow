# Preview release checklist

Target: **0.3.0 preview**. This is a preparation checklist, not a statement that a public release has happened.

## Candidate verification

- [x] Final source resource, native footer, packaged helper, plist, ZIP label, and release notes agree on 0.3.0/build 4. The November 12 Apple Silicon build uses clean revision `7e9b97a`.
- [x] Meaningful evidence/lifecycle tests pass, including backward-readable older recordings: all 73 tests with native integration enabled on November 12; see [the validation record](wake-lease-validation.md).
- [x] Final native UI verifies Off, Idle, and Experimental AC selection, confirmed hold/deadline, Stop, Quit cleanup, report inspection/export, restart default and external-recorder ownership. See [November 12 evidence](wake-lease-validation.md#november-12-final-software-check).
- [x] Prior-candidate owned-process checks verified creation/release after success, nonzero exit, cancellation, timeout, launch failure, and crash: 17 cases, including bounded experimental-helper cleanup. Final corrected-build checks are tracked separately below.
- [ ] AC removal is handled explicitly by experimental mode; no global power setting, privileged helper, unrelated process termination, or automatic forced sleep is introduced.
- [x] `bash scripts/build-app.sh` succeeds; the extracted Apple Silicon archive preserves executable permissions and passes `codesign --verify --deep --strict` before any synced-folder metadata is added.
- [x] The extracted recorder reports `0.3.0` without access to the removed temporary build directory.
- [x] `SHA256SUMS` verifies the version/architecture ZIP and `Borrow.zip`; `BUILD-INFO.txt` identifies source and ad-hoc signing accurately.
- [x] [Final GitHub checks pass](https://github.com/Figo5/borrow/actions/runs/43086166624) on `7e9b97a`: default tests, Intel build, extracted-package verification, artifact upload. Hosted Intel and local Apple Silicon results remain separately labelled.
- [x] The corrected candidate passed targeted regressions, 17 OS cases, and extracted-package verification. The final revision also passed all 73 local/native tests and a clean Apple Silicon build on November 12.

The [software handoff](software-handoff.md) records the current archive location and operator-deferred physical/video work. The corrected candidate received a fresh visual UI pass on November 12 after the old app was closed. Historical and current verification evidence remain separately dated.

## Physical evidence and demo

- [ ] A real agent runs useful work for five-to-ten minutes with a physically closed lid; report exact hardware, OS, power, display/peripherals, network, duration, and hold mode.
- [ ] Existing keep-awake processes are identified; the operator manages them for clean attribution. Do not terminate them automatically.
- [ ] Real agent progress, command/logged lifecycle, Borrow hold release, and actual system sleep are reported separately.
- [ ] Any claim of actual post-task sleep has independent observed evidence. Ended sampling or assertion release alone is insufficient.
- [ ] Cancellation/failure and wake behavior are documented. Fixture tests remain labelled synthetic.
- [ ] A short demonstration shows the actual mode/setup, real task activity, resulting report, and limitations. No simulated physical result or reconstructed success is presented as captured evidence.

Longer real-agent closed-lid validation and the end-to-end demo are pending until their artifacts are recorded. The earlier 30-second test under an existing `caffeinate` hold does not satisfy these items.

## Public preview preparation

- [x] README gives a concrete example, source build/install instructions, privacy link, and mode/compatibility limits. All six documented public CLI options and all three modes match the source and packaged `--help` output.
- [x] Draft release notes state experimental status, artifact/architecture labels, and ad-hoc signing. No notarized or universal-build claim is implied; final physical/demo outcomes remain to be filled in.
- [x] Combined local review assets retain the clean Apple Silicon build, matching hosted Intel package, source archive, architecture-specific provenance and checksums. See [artifact status](preview-artifacts.md).
- [x] Private unpublished draft `v0.3.0-preview` prepared with ten assets. Repository visibility remains private and no tag reference was created. Publication is still pending.
- [x] Review candidate public files and chosen reports for private material; inspect history filenames. A targeted scan of 45 candidate text files found no apparent credential material or specific private journal paths. Five commits contain 24 unique history filenames, with no credential/journal/session-directory filenames. This is a targeted source scan and history filename inventory, not a guarantee about every historical blob. Local recordings are excluded from package/artifact paths.
- [x] November 12 targeted scan checked all 60 candidate text files, including new native and live Codex evidence, with no credential, private-key or private journal-path matches. All 57 local Markdown links/anchors resolve. This is a bounded scan, not an exhaustive historical secret audit.
- [x] Review final diff and proposed commits at orchestration Gate 2. The user approved committing/pushing the private software preview on November 11; physical and public-release gates remain separate.
- [ ] Review release notes and assets before any repository visibility change, tag, release publication, or announcement. Preparation is not publication authorization.
- [ ] Revisit Ousel only after Borrow's original readiness gates are met, including a useful real-agent run and honest demo. Preserve Ousel's history; then update portfolio/profile links and archive notice before archiving it.

Developer ID signing/notarization is a separate distribution milestone. The source-first preview can be reviewed without disabling operating-system security protections or claiming that signing milestone is complete.

## Documentation and privacy review

The November 10 documentation pass inspected 21 Markdown files and resolved all 28 local Markdown targets without a missing file or anchor; 19 external links were outside that check. Later files and corrections receive a separate handoff link check. The packaged recorder's `--help` returned exit zero and identified version 0.3.0. README duration limits, opt-in wake/network behavior, absolute foreground-executable requirement, cancellation ownership, cleanup-failure exit, and experimental-mode limitations agree with the reviewed source.

Both issue forms ask for bounded setup/observation details, separate hold release from system sleep and task correctness, and explicitly discourage raw journals, prompts, credentials, private source, and tool output. The optional evidence field requests only reviewed excerpts. The third YAML file configures blank-issue availability rather than a data-collection form.

The earlier local-link review found no missing targets. The November 12 pass reconciles previously stale hosted-check claims with the successful final run. The five-to-ten-minute physical comparison, actual post-task sleep, final native demo, and publication retain their separate pending status. The software commits were approved and pushed on November 11; this documentation refresh has its own commit review. Recheck links and claims when new artifacts change the documents.
