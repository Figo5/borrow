# Borrow recording

Closed-lid rehearsal

Status: completed
Started: 11/10/2026, 9:58 AM
System: Version 27.0.1 (Build 26A434)
Run: 9485EB4A-88DD-43F2-9D82-1E9C6E3490CD

## Observations

### Work while closed — unverified

Need at least 3 worker ticks between samples with the lid closed. An open-lid run does not establish this.

### Expected result — observed

Worker exited zero and its run-specific final artifact contains the expected heartbeat count.

### Sleep and sampling — unverified

No closed-lid interval was sampled.

### Connectivity probe — skipped

Off. Enable the optional Apple connectivity check before starting.

### Sleep settings restored — skipped

Borrow made no sleep-setting changes and holds no wake assertion. Restoration and actual post-task sleep are not tested in this prototype.

## Timeline

- 9:58:38 AM: Recorder started. No sleep overrides or wake assertions requested.
- 9:58:38 AM: Started owned foreground process 60289.
- 9:58:38 AM: Lid sampled open.
- 9:59:10 AM: Foreground process exited 0.

This recording covers one setup and one interval. It does not certify future runs or physical safety.
