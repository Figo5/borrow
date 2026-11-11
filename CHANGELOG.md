# Changelog

## 0.3.0 preview — release candidate in preparation

This entry describes the preview candidate. The release checklist, physical validation, and demo must be completed before publication.

- Adds an explicit choice between recording without a wake hold, a bounded idle-sleep hold, and an experimental AC-only hold.
- Ties Borrow's hold to the recording lifecycle, with release evidence on terminal paths and a maximum lease deadline.
- Keeps observed work, logged agent lifecycle, hold release, and actual system sleep as separate findings.
- Adds architecture-labelled packages, SHA-256 checksums, build metadata, installation/privacy documentation, and issue templates.
- Corrects unknown/no-held cleanup evidence, stale exports, partial journal boundaries, and completion first observed after a deadline.
- Clarifies app-instance ownership and first-run guidance; redacts invalid CLI inputs and verifies extracted CI packages.

The experimental mode is not a universal closed-lid guarantee. Releasing Borrow's hold permits normal sleep policy; it does not force or certify system sleep. Longer real-agent closed-lid validation and the end-to-end demonstration remain pending until their evidence is recorded.

## 0.2.1 — November 10, 2026

- Preserved actual worker progress when before-sleep notifications also occur; uninterrupted operation remains unverified.
- Added a regression fixture from the first physical lid-close rehearsal: 15 worker ticks while sampled closed, expected final artifact observed, charger connected, no external display, and an existing `caffeinate` hold.

## 0.2.0 — November 10, 2026

- Added read-only observation of a deliberately selected Codex session log, with bounded parsing and fixed lifecycle labels instead of conversation content.
- Added native selection and report export for the Codex adapter.

## Initial prototype — November 10, 2026

- Added a native SwiftUI app, independent-worker rehearsal, foreground command recording, machine conditions, optional connectivity checks, and local JSON/Markdown reports.
