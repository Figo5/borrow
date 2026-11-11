# Preview release checklist

Target: **0.3.0 preview**. This is a preparation checklist, not a statement that a public release has happened.

## Candidate verification

- [ ] The final source resource version, app footer/CLI version, plist version, ZIP label, and release notes agree. The November 10 package matched 0.3.0/build 4; verify again after the November 11 corrections.
- [x] Meaningful evidence/lifecycle tests pass on corrected source, including backward-readable older recordings: 70 tests with native integration enabled; see [current review evidence](claude-opencode-review.md).
- [ ] Final native UI verifies Off, Idle, and Experimental AC selection, active hold state, cancellation, report inspection, and export. Prior candidate: Off-mode Codex observation, experimental acquisition/Quit, and idle completion/export were observed; repeat affected flows after fixes.
- [x] Prior-candidate owned-process checks verified creation/release after success, nonzero exit, cancellation, timeout, launch failure, and crash: 17 cases, including bounded experimental-helper cleanup. Final corrected-build checks are tracked separately below.
- [ ] AC removal is handled explicitly by experimental mode; no global power setting, privileged helper, unrelated process termination, or automatic forced sleep is introduced.
- [x] `bash scripts/build-app.sh` succeeds; the extracted Apple Silicon archive preserves executable permissions and passes `codesign --verify --deep --strict` before any synced-folder metadata is added.
- [x] The extracted recorder reports `0.3.0` without access to the removed temporary build directory.
- [x] `SHA256SUMS` verifies the version/architecture ZIP and `Borrow.zip`; `BUILD-INFO.txt` identifies source and ad-hoc signing accurately.
- [ ] Final GitHub checks pass. Hosted Intel results and local Apple Silicon results are named separately.
- [x] The corrected November 11 build passes targeted regressions, 70 full/native tests, 17 fresh OS cases, and extracted-package verification. CI includes the extracted-package step, but has not run the uncommitted workflow.

The November 11 [software handoff](software-handoff.md) records the corrected archive location and the operator-deferred physical/video work. Native UI control was unreliable, so the corrected archive has not received a fresh visual UI pass. Old and new verification evidence are kept separate.

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
- [x] Review candidate public files and chosen reports for private material; inspect history filenames. A targeted scan of 45 candidate text files found no apparent credential material or specific private journal paths. Five commits contain 24 unique history filenames, with no credential/journal/session-directory filenames. This is a targeted source scan and history filename inventory, not a guarantee about every historical blob. Local recordings are excluded from package/artifact paths.
- [x] Review final diff and proposed commits at orchestration Gate 2. The user approved committing/pushing the private software preview on November 11; physical and public-release gates remain separate.
- [ ] Review release notes and assets before any repository visibility change, tag, release publication, or announcement. Preparation is not publication authorization.
- [ ] Revisit Ousel only after Borrow's original readiness gates are met, including a useful real-agent run and honest demo. Preserve Ousel's history; then update portfolio/profile links and archive notice before archiving it.

Developer ID signing/notarization is a separate distribution milestone. The source-first preview can be reviewed without disabling operating-system security protections or claiming that signing milestone is complete.

## Documentation and privacy review

The November 10 documentation pass inspected 21 Markdown files and resolved all 28 local Markdown targets without a missing file or anchor; 19 external links were outside that check. Later files and corrections receive a separate handoff link check. The packaged recorder's `--help` returned exit zero and identified version 0.3.0. README duration limits, opt-in wake/network behavior, absolute foreground-executable requirement, cancellation ownership, cleanup-failure exit, and experimental-mode limitations agree with the reviewed source.

Both issue forms ask for bounded setup/observation details, separate hold release from system sleep and task correctness, and explicitly discourage raw journals, prompts, credentials, private source, and tool output. The optional evidence field requests only reviewed excerpts. The third YAML file configures blank-issue availability rather than a data-collection form.

The earlier local-link review found no missing targets. The November 11 OpenCode review identified stale demo/checklist wording, which has been reconciled with the actual prior evidence. The five-to-ten-minute physical comparison, actual post-task sleep, native demo, final corrected-build/GitHub checks, Gate 2, and publication retain their separate pending status. Recheck links and claims when new artifacts change the documents.
