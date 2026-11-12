# Borrow recording

Closed-lid rehearsal

Status: cancelled
Started: 11/12/2026, 8:14 AM
System: Version 27.0.1 (Build 26A434)
Run: 6E2B6DFA-6A11-448C-B819-72F57C8FE148

## Observations

### Work while closed — unverified

Need at least 3 worker ticks between samples with the lid closed. An open-lid run does not establish this.

### Expected result — failed

Requires a zero exit and a matching, complete worker artifact. Recording activity alone is insufficient.

### Sleep and sampling — unverified

Insufficient closed-lid samples to assess this interval.

### Connectivity probe — skipped

Off. Enable the optional Apple connectivity check before starting.

### Borrow wake hold — observed

Borrow confirmed its own prevent idle sleep assertion. This does not establish uninterrupted execution or closed-lid compatibility. Last recorded state: released.

### Borrow wake hold released — observed

Borrow confirmed release of its own hold. Reason: cancelled. No global sleep settings were changed.

### Actual post-task sleep — unverified

Releasing Borrow's hold only permits sleep. Other assertions, user activity and macOS policy may keep the Mac awake. Actual sleep was not established.

### Power source samples — observed

9 AC, 0 battery, and 0 unknown sample(s). These describe sampled conditions only.

## Timeline

- 8:14:13 AM: Recorder started. A bounded Borrow-owned wake hold was explicitly requested; no global power settings changed.
- 8:14:13 AM: Confirmed the explicitly requested Borrow-owned wake assertion. Closed-lid operation remains unverified.
- 8:14:13 AM: Started owned foreground process 23987.
- 8:14:13 AM: Lid sampled open.
- 8:14:21 AM: Recording cancelled. Sent termination only to the owned foreground process; descendants are not managed.
- 8:14:21 AM: Confirmed release of Borrow's own wake hold. Actual system sleep remains unverified.

This recording covers one setup and one interval. It does not certify future runs or physical safety.
