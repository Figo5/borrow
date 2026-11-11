# Task-scoped sleep control: feasibility

Research date: November 10, 2026. Planning evidence only; no new wake assertion, system setting, or physical test was performed for this research.

## Decision

A supported, temporary **idle-sleep hold** is feasible. A general promise that a charger-only Mac with no external display will keep a local agent running after lid close is **not established by the supported idle assertion**.

There is a plausible **experimental AC-only path using Apple's built-in `caffeinate -s`**, backed by Apple implementation source and this Mac's earlier mixed-signal rehearsal. It must be validated separately and labelled experimental. The present SDK expressly deprecates its underlying assertion. Do not silently replace the user's closed-lid requirement with idle-sleep prevention.

Releasing Borrow's hold means that Borrow stops preventing sleep. It does not establish that the Mac actually slept: user activity, system settings, other assertions, peripherals, and work outside Borrow can still affect that outcome. Do not force the whole computer to sleep when an agent exits.

## What the sources establish

| Mechanism | Evidence and consequence |
| --- | --- |
| `kIOPMAssertPreventUserIdleSystemSleep` | Apple's current [idle assertion documentation](https://developer.apple.com/documentation/iokit/kiopmassertiontypepreventuseridlesystemsleep) and the installed SDK explicitly allow sleep for lid close, the Apple menu, low battery, and other reasons. It allows the display to dim. Suitable for the supported default hold, not a clamshell guarantee. |
| `kIOPMAssertionTypePreventSystemSleep` | The installed SDK `IOPMLib.h` at lines 1014–1023 and [Apple's current open-source header](https://github.com/apple-oss-distributions/IOKitUser/blob/main/pwr_mgt.subproj/IOPMLib.h) say deprecated since 10.9, unsupported, and not to use it. This is a material public-API limitation. |
| Built-in `caffeinate -s` | The installed `man caffeinate` still documents a system-sleep assertion valid on AC power only. [Apple's caffeinate source](https://github.com/apple-oss-distributions/PowerManagement/blob/main/caffeinate/caffeinate.c) maps `-s` to the deprecated assertion; [Apple's power daemon source](https://github.com/apple-oss-distributions/PowerManagement/blob/main/pmconfigd/PMAssertions.c) still handles it with an AC-only flag. These are implementation evidence, not a cross-version compatibility guarantee. |
| Forced sleep callbacks | Apple's archived [QA1340](https://developer.apple.com/library/archive/qa/qa1340/_index.html) distinguishes idle sleep from lid-close/other forced sleep, and explains that callbacks cannot veto forced sleep. It is an older document, not proof that the experimental AC-only implementation cannot work. Repeatedly delaying notifications is not a viable implementation. |
| Supported closed-display use | Apple's current [external-display guidance](https://support.apple.com/en-us/102501) describes closed-lid use with an external display, power, and external keyboard/mouse. It does not establish the user's charger-only/no-display arrangement. |
| Network-client assertion | The current header reserves `kIOPMAssertNetworkClientActive` for active remote clients; it is a suggestion and may yield to power/thermal/user conditions. Borrow should not mislabel a local agent as a served network client to obtain different sleep behavior. |

The apparent contradiction is real: current public headers reject the system-sleep assertion while Apple ships a tool and daemon implementation that use it. Preserve that distinction. Do not present older documentation, source behavior, or a successful assertion-create return as proof of uninterrupted task execution.

## Lifecycle and implementation recommendation

Keep power ownership in the existing recorder process, whose lifetime already has a bounded wall-clock timeout. The SwiftUI process should request a recording mode; it should not hold a second, unbounded assertion.

For a supported idle hold, use a small injectable IOKit backend with a constant human-readable reason, an explicit timeout, and `kIOPMAssertionTimeoutActionRelease`. Apple's [creation API](https://developer.apple.com/documentation/iokit/1557082-iopmassertioncreatewithpropertie) accepts assertion properties; the installed header describes the timeout as an outer bound even if an application hangs. Release exactly once on completion, failure, cancellation, timeout, launch failure, and orderly shutdown. A failed create must be visible, not reported as an active hold.

For the experimental AC-only spike, prefer reusing `/usr/bin/caffeinate` over copying Apple's implementation or adding a package. The candidate arguments are `-s -w <owned-recorder-pid> -t <bounded-seconds>`, **without a utility argument**. The manual says `-t` is ignored when a utility is supplied. Waiting for the recorder PID also bounds a surviving helper after a recorder crash; terminate only Borrow's own helper on normal cleanup. Confirm helper/assertion creation and record errors rather than assuming launch means protection. Require AC before starting this mode and release on unplug; no `SleepDisabled`, root helper, private battery override, or global power-setting change.

[Apple's daemon source](https://github.com/apple-oss-distributions/PowerManagement/blob/main/pmconfigd/PMAssertions.c) registers process-exit handling and releases assertions belonging to the dead PID. That supports a process-owned design, but crash/timeout behavior on the installed OS still needs an actual owned-process check. An assertion release, helper exit, and absence of Borrow's assertion are separate evidence from actual sleep.

For selected Codex-log observation, release a requested hold only at an unambiguous logged terminal boundary, cancellation, or maximum lease deadline. Stream loss, malformed lifecycle data, or silence must not become inferred task success. Foreground command exit remains exit evidence, not a correctness certificate. Do not terminate an observed external agent to release a hold.

## Validation before a closed-lid claim

1. After implementation approval, verify the hold and disappearance using Borrow-owned assertion identity/PID; cover normal exit, nonzero exit, cancellation, timeout, recorder crash, helper failure, and AC removal. Automated evidence tests must distinguish released, failed, and unknown states.
2. Prepare a disposable real-agent task with useful work throughout a five-to-ten-minute recording. Record the exact Mac, OS, power, external-display/peripheral configuration, network, and hold mode. Keep prompt/output private under the existing reporting rules.
3. The operator must explicitly stop any existing ambient keep-awake tool before a clean attribution test. Borrow must not kill it. The earlier [physical rehearsal](physical-lid-close.md) found an existing `caffeinate` hold and therefore cannot establish Borrow-only behavior.
4. Have the operator close/reopen the lid; compare real agent progress, heartbeat/conditions, final exit or logged lifecycle, and Borrow's hold release. No synthetic fixture or open-lid automation can satisfy this step.
5. For actual post-task sleep, use a separate operator-coordinated observation after Borrow releases its hold. A missing wake notification or ended sampling is insufficient proof. If another hold remains, report that release was verified and actual sleep remains unverified.

If the experimental charger-only path fails, retain the supported idle mode and require an independently supported closed-display setup for the demo. Do not advertise the original no-display promise as complete. A public release can explain the limitation; Ousel's readiness gate remains unmet until the real test/demo are finished.

## Research and reuse record

Read-only local checks used macOS 27.0.1 (26A434), the installed Xcode SDK header, Swift 6.4 version output, and `man caffeinate`. They are documentation/toolchain inspection, not runtime power validation.

GitHub reuse searches ran `gh search repos 'IOPMAssertion Swift'` (no repository hits) and `gh search code 'kIOPMAssertionTimeoutActionRelease language:Swift'` (wrappers in OpenClaw, XUCore, and other projects). No third-party implementation was copied, installed, or treated as authoritative Apple behavior. The narrow native API wrapper plus Apple's installed `caffeinate` provides the needed mechanisms without an external dependency.
