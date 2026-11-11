# Borrow recording

Closed-lid rehearsal

Status: completed
Started: 11/10/2026, 1:58 PM
System: Version 27.0.1 (Build 26A434)
Run: 475A7B30-96F9-46DA-8053-0D03212BE765

## Observations

### Work while closed — unverified

Need at least 3 worker ticks between samples with the lid closed. An open-lid run does not establish this.

### Expected result — observed

Worker exited zero and its run-specific final artifact contains the expected heartbeat count.

### Sleep and sampling — unverified

Insufficient closed-lid samples to assess this interval.

### Connectivity probe — skipped

Off. Enable the optional Apple connectivity check before starting.

### Borrow wake hold — observed

Borrow confirmed its own prevent idle sleep assertion. This does not establish uninterrupted execution or closed-lid compatibility. Last recorded state: released.

### Borrow wake hold released — observed

Borrow confirmed release of its own hold. Reason: completed. No global sleep settings were changed.

### Actual post-task sleep — unverified

Releasing Borrow's hold only permits sleep. Other assertions, user activity and macOS policy may keep the Mac awake. Actual sleep was not established.

### Power source samples — observed

32 AC, 0 battery, and 0 unknown sample(s). These describe sampled conditions only.

## Timeline

- 1:58:13 PM: Recorder started. A bounded Borrow-owned wake hold was explicitly requested; no global power settings changed.
- 1:58:13 PM: Confirmed the explicitly requested Borrow-owned wake assertion. Closed-lid operation remains unverified.
- 1:58:13 PM: Started owned foreground process 9453.
- 1:58:13 PM: Lid sampled open.
- 1:58:46 PM: Foreground process exited 0.
- 1:58:46 PM: Confirmed release of Borrow's own wake hold. Actual system sleep remains unverified.

This recording covers one setup and one interval. It does not certify future runs or physical safety.
