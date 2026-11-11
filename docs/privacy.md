# Local data and privacy

Borrow records evidence on your Mac. It does not require a Borrow account or upload recordings automatically. The optional connectivity probe contacts `https://captive.apple.com/hotspot-detect.html`; it is off by default and does not send your code or prompts. Your chosen agent's own network traffic remains outside Borrow's control.

## Reports contain

- Run identifiers, timestamps, OS version, process IDs, executable basename, recording status, and exit status.
- Sampled lid state, battery/thermal conditions, observation gaps, sleep/wake notifications, and optional probe results.
- Fixed agent lifecycle labels and event counts when observing a selected Codex log.
- Borrow's selected hold mode and available evidence about its own hold lifecycle. Releasing a hold is not a claim that the whole computer slept.

Reports are normally stored under `~/Library/Application Support/Borrow/Runs/<run-id>/`. The native export action creates a Markdown copy in the destination you choose. CLI recordings can use a separately chosen output root. There is no automatic cloud destination; an operating-system sync service may sync a folder you choose independently.

Borrow intentionally excludes prompts, reasoning, messages, tool arguments/output, environment contents, source code, screenshots, and selected session-file paths from persisted reports. Command output passes through to the invoking terminal rather than becoming report content. Supplying command arguments still exposes them to normal operating-system process inspection while that command runs.

## Selected Codex logs

You explicitly select one local session log. The read-only adapter attaches at its current end and parses whitelisted lifecycle events. Historical data is used for internal bookkeeping, not credited as new progress. Raw turn IDs and message content are discarded instead of copied into reports. Malformed, oversized, replaced, or truncated streams reduce confidence or stop observation; quiet logs are not labelled stuck or awaiting approval.

Stopping observation leaves the external agent running. Borrow's observation and power hold are separate from the agent's permissions, configuration, and model connection.

## Before sharing

Export the report you intend to share and read it first. Timestamps, process IDs, OS version, executable names, and machine conditions can reveal details about your setup even when prompts are absent. Share only the evidence needed for a bug report. Do not attach raw session journals, agent transcripts, credentials, or terminal histories.

CI packages contain built application files, checksums, and build metadata. They must not include your `Runs` directory or private agent sessions. Manual demo capture should show a disposable task and a reviewed report; a screen recording is not part of Borrow's automatic recording behavior.
