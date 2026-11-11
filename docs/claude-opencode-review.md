# Claude and OpenCode collaboration

November 11, 2026 · Borrow 0.3.0 candidate · source remains uncommitted

The user requested both tools for the resumed work. Claude Code 2.1.321 reviewed the current source, then implemented core fixes with regression tests. OpenCode 2.0.29 reviewed a copied source snapshot for release readiness, then independently reviewed the corrected candidate. Codex checked the findings, integrated the app/CLI/parser/packaging changes, and ran final verification.

OpenCode's default provider returned insufficient balance. The successful reviews used its existing OpenAI connection with a per-run `openai/gpt-6.1-sol` selection. No billing action or saved provider-default change was made. Review roles were read-only. Claude's implementation role was limited to the core recording/lease files and their tests; no agent was authorized to commit, publish, change global power settings, or stop unrelated processes.

## Findings and corrections

| Contribution | Correction |
| --- | --- |
| Claude: unknown power/inventory readings were labelled definite loss | An explicit unknown outcome stops conservatively without claiming an unplug or lost assertion. |
| Claude: cleanup could claim release without any created resource | Cleanup distinguishes released, nothing held, and unconfirmed; no invented release timestamp/event. |
| Claude: stale exports and transient write failure | Shared freshness rules appear in UI/Markdown; one best-effort final save follows cleanup. |
| Claude: partial journal boundaries | Historical tails retain bookkeeping without being counted as malformed or fresh activity; unfinished new records prevent premature completion. |
| Claude: app-instance ownership and signal setup | View-only recorders are labelled; Quit/Stop wording identifies the controlled recorder, and CLI signal sources activate before ignored dispositions are installed. No unowned PID is adopted or signalled. |
| Codex: actual late-exit reproduction | A recorder paused while its command exceeded the deadline previously returned success. Timeliness now requires observing completion before the limit; expired setup creates no task/hold. |
| OpenCode: first-run and CLI privacy | Initial guidance keeps the lid open; invalid options and unexpected errors use safe fixed descriptions. |
| OpenCode: packaged deliverable and provenance | CI verifies the extracted signature/helper/version/architecture. A nested source archive cannot inherit an enclosing repository's revision. |
| OpenCode: documentation status | Completed rehearsal/export and prior checks are distinguished from missing physical footage and final corrected-build verification. |

The second OpenCode source review identified one remaining test mismatch: a recorder cancelled before startup must acquire/release zero holds and report nothing held. That expectation was corrected. OpenCode reported no other concrete must-fix source findings; it did not execute the tests or certify physical behavior.

## Verification

The corrected source passed **70 tests with native integration enabled**, including the three native idle/experimental-AC checks. Test-first failures reproduced the historical-tail bookkeeping bug, unknown/no-held/stale evidence problems, late completion, transient persistence errors, and expired setup. No production blocking sleep was added.

Coverage from the final run: `WakeLease.swift` 94.51% lines, `Recorder.swift` 92.33%, `Recording.swift` 92.31%, `CodexEvents.swift` 94.12%; all `BorrowCore` 90.71% lines and 85.35% regions. The toolchain emitted no branch coverage data.

The corrected package was built from a copied source archive inside another Git checkout. It correctly reported `source-archive` provenance and passed extracted signature, executable architecture, version-resource, and help verification. Current review artifacts are under `dist/preview-2026-11-11/`; their source manifest records the code, test, build-script, and workflow inputs.

Fresh CLI/OS results are recorded in [the validation record](wake-lease-validation.md). These source/package checks establish neither a five-minute closed-lid agent run nor actual sleep. Native UI control was unreliable during the resumed session, so no new native video or corrected-build UI pass is claimed.

The physical test, authentic video, final hosted checks, orchestration commit confirmation, public visibility/publication, and Ousel readiness gate remain separate.
