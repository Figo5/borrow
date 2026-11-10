# Physical lid-close rehearsal

November 10, 2026 · 11:27 a.m. America/New_York

## Setup

- Same development Mac, hardware identifier `Mac14,9`.
- macOS 27.0.1 (26A434), Borrow 0.2.
- Charger connected, no external display, confirmed by the operator.
- Battery samples: 100%; macOS thermal samples: nominal.
- Thirty-second independent-worker rehearsal; connectivity probing disabled.
- Existing environment: the power log includes a `caffeinate` PreventSystemSleep hold. Borrow did not create or change it. This is not a clean environment without keep-awake software.

## Observed result

The recording began at 11:27:26 and ended at 11:27:58. Lid state was sampled closed from 11:27:30 through 11:27:46, and open again at 11:27:47. Between consecutive closed-lid samples, the independent worker advanced from heartbeat 3 to 18: **15 ticks of observed progress**. It eventually exited zero with a matching 30-tick final artifact. There was no observation gap above Borrow's eight-second threshold.

The recorder also received one before-sleep notification at 11:27:30 and one wake notification at 11:27:46. The [relevant power-log excerpt](evidence/physical-lid-close-power-log.txt) identifies a 16-second DarkWake interval associated with clamshell sleep. The notifications and continued sampled progress are both retained as evidence. We do not infer that every process ran continuously or attribute the result to Borrow.

## Report correction

Borrow 0.2 classified the before-sleep notification as a failed sleep/sampling check. That was too strong: Apple's [willSleepNotification documentation](https://developer.apple.com/documentation/appkit/nsworkspace/willsleepnotification) describes a notification sent before sleep and notes that observers can delay sleep. It is not a measurement of how long task execution paused.

The corrected rule leaves uninterrupted operation **Unverified** when notifications or sampling gaps occur, while preserving **Observed** worker progress and the successful final artifact. A regression test uses the exact recording to require this combination. It also requires at least two closed-lid samples before reporting coverage without notifications or gaps.

The [original report](physical-lid-close-v0.2-original.md) is preserved unchanged. The raw recording is preserved in the test fixture `Tests/BorrowCoreTests/Fixtures/physical-lid-close-2026-11-10.json`.

## Limits

This establishes sampled worker progress during one short, charger-connected closed-lid interval under an existing sleep-prevention environment. It does not establish battery-only operation, long-duration compatibility, agent/provider connection continuity, post-task sleep restoration, or physical safety. Connectivity was not checked. The live Codex adapter checks so far were performed with the lid open.
