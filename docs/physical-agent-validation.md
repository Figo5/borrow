# Real-agent power validation protocol

**Status: physical interval pending.** The wake-control integration checks are complete in [the lifecycle validation record](wake-lease-validation.md). One live-agent observation remained open-lid and is preserved below. No five-to-ten-minute real-agent closed-lid run or post-task sleep result is claimed here.

On November 11 the user chose to finish the software handoff and perform the physical trial later. Ask for fresh operator readiness before starting any new bounded comparison.

The earlier [30-second rehearsal](physical-lid-close.md) is separate evidence: a disposable worker advanced 15 ticks during a short closed-lid interval, with an existing `caffeinate` hold and DarkWake notifications. It does not validate Borrow's new hold or a real agent connection.

## Test boundary

Borrow may acquire and release only its own requested lease. Use temporary output directories for CLI checks. Never change global power settings, install a service, terminate an unrelated keep-awake process, or change agent permissions to make a test pass.

Capture only fixed labels, timestamps, counts, owned process/assertion identifiers, and bounded machine conditions. Do not attach full power inventories, session paths, prompts, arguments, model responses, tool output, environment data, or source code to the evidence. Inspect evidence before copying it into the repository or a release.

## Open-lid integration prerequisite

Run this matrix after core tests pass and before asking the operator to close the lid. Resolve actual option names from the built CLI help rather than copying a stale command from a planning document. Set a short finite lease and use the packaged recorder or a temporary scratch build.

For each case, capture the recorder/helper process handles at creation. Query the OS read-only assertion inventory, filtering by the owned PID/assertion identity before saving. A live helper is not proof that its assertion exists. Recheck disappearance after cleanup; requesting release is not confirmation. Do not use process-name sweeps or signal a PID found only by a broad search.

| Case | Stimulus | Required evidence |
| --- | --- | --- |
| Off by default | Run a short foreground command without selecting a hold | No Borrow-owned assertion; no acquired/released claim; normal command outcome |
| Idle success | Request idle hold; run a bounded command that exits zero | Assertion confirmed during recording; foreground exit zero; release confirmed before final report |
| Nonzero exit | Request a hold; run `/usr/bin/false` | Exit 1 remains a failed command check; Borrow's assertion disappears |
| Launch failure | Request a hold; select a nonexistent absolute executable | Launch failure without persisted path/argument contents; any acquired assertion is released |
| Cancel | Signal only the disposable recorder created by the test | Cancelled status and CLI cancellation result; owned hold disappears; no unrelated process signalled |
| Timeout | Use a short recording limit with an owned bounded command that outlasts it | Timeout is distinct from completion; owned hold disappears; descendants are not claimed stopped |
| Experimental AC | On charger, request experimental AC hold | Confirm actual owned system assertion, not merely `caffeinate` launch; confirm release after recording |
| Experimental source unavailable | Use an injected unavailable/unknown AC source in automated tests | Refusal or interruption rather than protection claimed; no task launch under failed requested protection |
| Owned helper fails | Terminate only the helper spawned by this disposable test | Protection ceases to display as active; failure/unknown is retained; bounded cleanup follows |
| Recorder crash | Force-kill only a new disposable recorder whose child work is independently short and bounded | OS/helper owner-death cleanup observed, or disappearance by the documented timeout; stale recording does not claim release |
| Persistence failure | Use an injected store failure or a disposable controlled path fault | Hold cleanup still occurs; report absence or incomplete evidence stays explicit |
| Read-only observer cancel | Attach one deliberately selected live session, then stop observation | Agent continues; only Borrow's recorder/hold ends |
| Source loss | Replace/truncate only a synthetic disposable journal fixture | Observation ends without inferred agent success; hold releases; real session remains untouched |

Compare the relevant read-only power-setting snapshot before and after the test batch. Store only the fact that no change was observed, rather than publishing a machine-wide configuration dump. Measure cancellation-to-release latency, including an enabled connectivity request's timeout; do not promise instantaneous cleanup.

For native Quit, verify normal quit and Command-Q while recording. The application must wait for the owned recorder's exit/cleanup independently of the window refresh task. Closing the window and quitting the application are distinct actions; neither action proves an external agent stopped.

### Integration results template for a new candidate

The completed November 10 candidate results are recorded in [wake-lease validation](wake-lease-validation.md); this blank table is for a subsequent run and does not erase that evidence.

| Field | Result |
| --- | --- |
| Tested revision/build and architecture | Pending |
| Date/time and timezone | Pending |
| Test cases performed | Pending |
| Actual acquisition/release observations | Pending |
| Crash cleanup bound observed | Pending |
| Maximum measured stop-to-release latency | Pending |
| Global settings comparison | Pending |
| Privacy review | Pending |
| Failures or unperformed cases | Pending |

## Physical real-agent comparison

1. Select a genuinely useful task that can provide evidence during the interval. The active Borrow implementation/review/validation chat is a suitable candidate while real work continues. Observe its deliberately selected local journal without publishing its path or contents. Do not pad a task with dummy sleep and call that agent progress.
2. Confirm core tests and the integration prerequisite above. Set a bounded 5–10-minute observation window and choose the intended hold mode explicitly. Keep connectivity probing off unless the operator selects it.
3. Record the setup using the template below. Inspect the existing keep-awake environment read-only. Ask the operator to stop their own existing keep-awake tool through its normal controls if they can identify it. Borrow must not kill the unrelated long-running `caffeinate` process. If isolation is unavailable, continue only with a clearly confounded result.
4. First capture a Borrow-Off comparison on the same setup. Then attempt the experimental AC mode. For each run, confirm the selected mode and actual owned assertion before requesting lid close.
5. The operator closes the lid on a ventilated desk, leaves it closed for the agreed 5–10 minutes, reopens, and reports anything connected or changed during the interval. Computer automation cannot supply this physical action.
6. Inspect the run and its timeline. Distinguish event timestamps from when events were appended between sampled lid states. Delayed log delivery is possible: append-while-closed is not automatically execution-while-closed. Review power notifications, observation gaps, event counts, logged turn outcome, and independent task checks separately.
7. Verify Borrow's lease release when observation ends. A turn outcome is a logged boundary, not acceptance of the generated work. A timeout or cancellation releases Borrow's hold while leaving the observed agent running.
8. If possible, arrange a separate operator-observed post-release sleep interval without changing idle timers or forcing sleep. Otherwise leave actual sleep unverified. A missing sample, helper exit, released assertion, or sleeping display is insufficient evidence of system sleep.
9. Export sanitized reports and preserve success, failure, or ambiguity. Do not discard the Off result or replace an inconclusive experiment with an open-lid fixture.

### Open-lid observation collected while preparing the comparison

On November 10, 2026, from 1:49:07 to 1:56:05 p.m. America/New_York, Borrow 0.3.0 observed the live Codex implementation/release-validation task in **Off** mode. It recorded 15 new tool completions, 399 AC-powered samples, and no closed-lid samples. Observation was stopped; the Codex task continued. The [unaltered exported report](evidence/real-agent-open-lid-baseline.md) preserves that result.

The operator had confirmed charger-only use without an external display. Read-only inspection still found the earlier long-running `caffeinate` system hold; its original parent application could not be identified, and it was left alone. Any future comparison under that environment is confounded. This open-lid recording does not satisfy the requested physical trial and is not a failed closed-lid test.

### Physical setup and results template

| Field | Borrow-Off comparison | Experimental AC attempt |
| --- | --- | --- |
| Run ID and tested revision/build | Pending | Pending |
| Date/time and timezone | Pending | Pending |
| Hardware identifier and macOS build | Pending | Pending |
| Charger, external display, other peripherals | Pending | Pending |
| Network and optional probe state | Pending | Pending |
| Existing keep-awake environment | Pending | Pending |
| Attribution isolated or confounded | Pending | Pending |
| Operator-reported close/reopen interval | Pending | Pending |
| Sampled closed-lid interval | Pending | Pending |
| Requested hold / OS-confirmed assertion | Pending | Pending |
| New lifecycle events between closed samples | Pending | Pending |
| Event timestamp/delivery caveats | Pending | Pending |
| Power notifications and observation gaps | Pending | Pending |
| Logged outcome and independent acceptance checks | Pending | Pending |
| Borrow-owned release evidence | Pending | Pending |
| Actual system sleep independently observed | Unverified | Unverified |
| Sanitized report/evidence links | Pending | Pending |
| Result and remaining uncertainty | Pending | Pending |

## Claim allowed after the test

Describe the exact measured setup and interval. An observed assertion does not establish uninterrupted execution; lifecycle events do not establish provider connection health or task correctness. Even a successful isolated run would not establish battery-only behavior, all-night operation, other Macs, macOS versions, thermal limits, or future compatibility.

If experimental AC fails, document that failure and demonstrate the useful evidence Borrow preserved. Do not advertise charger-only/no-display operation as delivered. Ousel's readiness gate remains in force.
