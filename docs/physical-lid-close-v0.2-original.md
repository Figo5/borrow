# Borrow recording

Closed-lid rehearsal

Status: completed
Started: 11/10/2026, 11:27 AM
System: Version 27.0.1 (Build 26A434)
Run: F4879A7C-AEBF-4C58-8F13-943956BAD767

## Observations

### Work while closed — observed

Independent worker advanced 15 ticks between closed-lid samples. This covers those sampled intervals only.

### Expected result — observed

Worker exited zero and its run-specific final artifact contains the expected heartbeat count.

### Sleep and sampling — failed

macOS announced sleep 1 time(s) during this recording.

### Connectivity probe — skipped

Off. Enable the optional Apple connectivity check before starting.

### Sleep settings restored — skipped

Borrow made no sleep-setting changes and holds no wake assertion. Restoration and actual post-task sleep are not tested in this prototype.

## Timeline

- 11:27:26 AM: Recorder started. No sleep overrides or wake assertions requested.
- 11:27:26 AM: Started owned foreground process 79429.
- 11:27:26 AM: Lid sampled open.
- 11:27:30 AM: macOS announced system sleep.
- 11:27:30 AM: Lid sampled closed.
- 11:27:46 AM: macOS announced system wake.
- 11:27:47 AM: Lid sampled open.
- 11:27:58 AM: Foreground process exited 0.

This recording covers one setup and one interval. It does not certify future runs or physical safety.
