# Validation findings and corrections

November 11, 2026 · Borrow 0.3.0 candidate

These findings record the corrections made to the 0.3.0 candidate and the verification performed on the corrected source and package. They are software checks: they establish neither a five-minute closed-lid agent run nor actual sleep, and physical behavior remains a separate result.

## Findings and corrections

| Finding | Correction |
| --- | --- |
| Unknown power or inventory readings were labelled as definite loss | An explicit unknown outcome stops conservatively without claiming an unplug or a lost assertion. |
| Cleanup could claim a release without any created resource | Cleanup distinguishes released, nothing held, and unconfirmed; no release timestamp or event is invented. |
| Stale exports and transient write failure | Shared freshness rules appear in the UI and Markdown export; one best-effort final save follows cleanup. |
| Partial journal boundaries | Historical tails retain bookkeeping without being counted as malformed or as fresh activity; unfinished new records prevent premature completion. |
| App-instance ownership and signal setup | View-only recorders are labelled; Quit/Stop wording identifies the controlled recorder, and CLI signal sources activate before ignored dispositions are installed. No unowned PID is adopted or signalled. |
| Actual late-exit reproduction | A recorder paused while its command exceeded the deadline previously returned success. Timeliness now requires observing completion before the limit; expired setup creates no task or hold. |
| First-run and CLI privacy | Initial guidance keeps the lid open; invalid options and unexpected errors use safe fixed descriptions. |
| Packaged deliverable and provenance | CI verifies the extracted signature, helper, version, and architecture. A nested source archive cannot inherit an enclosing repository's revision. |
| Documentation status | Completed rehearsal/export and prior checks are distinguished from missing physical footage and final corrected-build verification. |

One remaining test mismatch was found and corrected: a recorder cancelled before startup must acquire and release zero holds and report nothing held. No other concrete must-fix source findings were identified. That source pass did not run the test suite or certify physical behavior.

## Verification

The corrected source passed **70 tests with native integration enabled**, including the three native idle/experimental-AC checks. Test-first failures reproduced the historical-tail bookkeeping bug, the unknown/no-held/stale evidence problems, late completion, transient persistence errors, and expired setup. No production blocking sleep was added.

Coverage from the final run: `WakeLease.swift` 94.51% lines, `Recorder.swift` 92.33%, `Recording.swift` 92.31%, `CodexEvents.swift` 94.12%; all `BorrowCore` 90.71% lines and 85.35% regions. The toolchain emitted no branch coverage data.

The corrected package was built from a copied source archive inside another Git checkout. It correctly reported `source-archive` provenance and passed extracted signature, executable architecture, version-resource, and help verification. The November 11 artifacts are under `dist/preview-2026-11-11/`; their source manifest records the code, test, build-script, and workflow inputs.

Fresh CLI/OS results are recorded in [the validation record](wake-lease-validation.md). These source and package checks establish neither a five-minute closed-lid agent run nor actual sleep. Native UI control was unreliable at the time, so no new native video or corrected-build UI pass is claimed.

## Remaining evidence

The physical test, authentic video, final hosted checks, public visibility/publication, and the Ousel readiness gate remain separate results.
