# Wake-control preview security review

November 10, 2026 · independent review of the uncommitted 0.3.0 candidate

**Result:** no critical or high security findings identified in the reviewed changes. This is a source review, not a claim that physical closed-lid operation or public distribution is validated. Subsequent code changes and runtime results must be checked separately before Gate 2.

## Scope and method

Read the actual tracked diff and new Swift sources, tests, packaging script, CI workflow, issue templates, and privacy/release documents. Reviewed subprocess ownership, assertion confirmation and lifetime, cancellation/error cleanup, selected-journal handling, persisted data, native Quit, and packaging inputs. A targeted local source scan found no apparent credential material; test privacy sentinels were inspected in context. No third-party JavaScript packages are present, so npm-oriented checks are inapplicable.

No real agent was launched, no private journal contents were read, no broad process-argument inventory was collected, and no system settings or unrelated processes were changed for this review.

## Boundaries verified in source

- `WakeLease.swift` launches only the absolute system `caffeinate` executable with separate typed arguments. The experimental helper is bounded by the recorder PID and finite timeout. There is no shell expansion, global sleep-setting command, root helper, or service installation.
- An experimental helper is not treated as active solely because its process launched. The backend queries OS assertions for the owned helper PID and expected assertion type/level. Native idle assertions likewise require an OS inventory entry for the recorder PID, run-specific assertion name, expected type, and active level. Inventory failure remains unknown rather than confirmed absence.
- Release and termination target only held assertion identifiers and owned `Process` instances. No process-name sweep or unrelated keep-awake termination is introduced. The maximum lifetime remains bounded if normal cleanup cannot be confirmed.
- Recorder paths release the requested hold before writing a final release claim, with a fallback for thrown errors. The late-acquisition cancellation check prevents a cancelled recording from then launching a foreground task. The launch-failure path now writes sanitized JSON and Markdown after cleanup.
- Recorder and journal errors use fixed descriptions that exclude selected session paths, executable paths, arguments, prompt content, and raw tool/model errors. Selected journal data passes through the existing lifecycle whitelist; it is not used as executable instructions.
- The native app launches only its own rehearsal worker or read-only observer. Its recorder log receives fixed recorder output and sanitized errors, not an external agent's prompt or output stream. Remaining filesystem errors are displayed in the UI rather than intentionally persisted into run evidence.
- Native Quit requests cancellation of the owned recorder and independently waits for exit/readable release evidence. It does not depend solely on the window's refresh task. Run selection also matches the owned recorder PID, avoiding another concurrently created run as cleanup evidence. An unconfirmed cleanup result keeps the application open instead of fabricating confirmation.
- Packaging allowlists version, build number, architecture, and revision values before using them in XML, filenames, and metadata. Temporary build paths and output operations are quoted. Only built application files enter archives.
- CI uses read-only repository permissions, checkout without persisted credentials, a finite job timeout, and explicit package/metadata artifact paths. It introduces no release token, signing secret, automatic publication, or visibility change.

## Resolved follow-up

**Medium, automation semantics — resolved in source:** the CLI now exits 1 if a wake hold has `releaseUnconfirmed`, after preserving any existing nonzero cancellation, timeout, agent, or foreground-command result. A successful foreground task therefore no longer turns an unconfirmed cleanup into an overall CLI success. The README documents this distinction; reports still retain the cleanup failure and actual sleep remains unverified. The release-failure path is exercised through an injected backend in unit tests; a genuine OS release failure has not been deliberately manufactured for this review.

## Release responsiveness recheck

Stop handling is cooperative: the recorder checks its cancellation flag after the current sample, including an optional connectivity request configured with three-second request/resource timeouts. Its normal sampling sleep is one second. Experimental cleanup polls for owned helper exit and assertion absence for up to twenty 50-millisecond intervals. Native Quit independently waits for the recorder for up to twelve seconds and declines the quit if cleanup cannot be read/confirmed.

These source-level intervals are not hard real-time guarantees under scheduling delay, stalled I/O, or sleep. The separate finite OS lease deadline and owner-death bound remain the backstop. Idle assertion timeouts now round remaining seconds upward to avoid expiring before the recording's fractional deadline. No instantaneous-release or exact post-task sleep promise is made.

## Runtime evidence still required

- Confirm actual owned assertion acquisition/disappearance, including crash and helper-failure cases, on the installed OS.
- Verify native Quit, window-close behavior, and exported report agreement using the built app.
- Inspect final packaging outside the temporary build directory, including version resources, signature, architecture, and checksums.
- Complete the operator-assisted real-agent physical comparison and review the actual demo for private content and unsupported claims.
- Re-review material changes after this source snapshot; complete the independent code review and final test checks before Gate 2.

Nothing in this review authorizes committing, publishing, changing repository visibility, or archiving Ousel ahead of the existing gates.
