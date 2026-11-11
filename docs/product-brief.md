# Borrow: first product decision

Date: November 10, 2026

## Promise

Give a local task a temporary, bounded wake hold and release Borrow's own hold when recording ends. Rehearse the setup before leaving it unattended, then inspect the observed power, connectivity, process, and logged-agent sequence. Supported idle prevention and experimental AC-only closed-lid behavior are distinct; physical evidence determines what can be claimed.

## Why this might earn attention

The most useful demonstration is one real failure made understandable: a Mac remains reachable but the task stops advancing, or an SSH route recovers while the app does not. A small native tool with an exportable report can help developers and maintainers reproduce those cases without replacing their terminal or coding agent.

This is a learning and portfolio project with a plausible user need. Search and issue reports do not establish product-market fit, an empty market, adoption, or willingness to pay. Start free and local; judge interest from real rehearsals and useful bug reports before adding accounts, subscriptions, or a broad dashboard.

## Competitive boundaries

- [Keepresso](https://keepresso.com/help/keep-mac-awake-ai-agents) already supplies detection, expiring keep-awake leases, MCP and scheduled wake. Those are not novel differentiators.
- [Agent Ground Control](https://devpost.com/software/agent-ground-control) documents resource ownership, conservative cleanup and receipts. It is a project submission; this research did not install it or establish broad availability.
- [TheVibeFather](https://thevibefather.com/features/safe) documents independent build/test execution. Command verification alone is not the gap.
- [Rucksack](https://github.com/noahnawara/rucksack) prepares the network transition and bounded wake state. Network preparation alone is covered.
- [Napless](https://napless.io/guides/mac-keep-awake-apps-compared/) has health checks. A status/doctor screen alone is covered.
- [StillOn's guide](https://stillon.dev/guides/monitor-a-lid-closed-mac-without-fooling-yourself) describes a manual end-to-end rehearsal and separates host reachability from actual task progress. Automating this measurement is the initial opportunity.

These are documented claims and positioning, not hands-on benchmarks. Absence from reviewed documentation does not prove a competitor lacks a feature.

## Problem evidence

- [Claude Code #34255](https://github.com/anthropics/claude-code/issues/34255): users report silent remote-control disconnects and missing recovery/health signals. An issue report is evidence of a reported problem, not universal behavior.
- [Codex #35943](https://github.com/openai/codex/issues/35943): reported SSH app connection remaining disconnected after the tunnel returns from sleep.
- [Orchestrator documentation](https://docs.orchestrator.inc/configuration/remote-access/): recommends a real closed-lid smoke test and limits its compatibility evidence.

## Prototype scope

Implemented: native window/menu, bounded independent-worker rehearsal, foreground command recording, opt-in read-only Codex session observation, lid polling, macOS sleep/wake notifications, battery and thermal observations, optional Apple connectivity probe, local JSON, Markdown export, and evidence rules.

The approved 0.3 development scope adds opt-in, bounded recorder-owned wake holds with acquisition/release evidence, native controls, and failure-path cleanup. [The task list](task_list.md) tracks implementation and validation. The AC-only path remains experimental until tested on the actual setup; releasing a hold does not prove the Mac slept.

Outside scope: global power-setting changes, provider-specific connection health, approval-state adapters, automatic recovery, recursive process cleanup, semantic acceptance criteria, and a general closed-lid compatibility promise. Developer ID distribution needs an identity not currently available locally. The Codex adapter records whitelisted log events; it does not establish task correctness or infer stuck/waiting states.

## Validate the opportunity

1. Perform one real closed-lid rehearsal with and without an existing keep-awake configuration. Preserve both reports.
2. Reproduce a network interruption and a foreground task failure. Borrow must distinguish observed facts from unknown causes.
3. Try at least three independent setups, including another Mac and a different network. This is an initial feedback target, not a statistically representative study.
4. Have users explain a failed run from the report. If it adds no information beyond the keep-awake app, revise the product before broadening it.

## Ousel replacement gate

The user chose: **Archive Ousel once Borrow is ready**. Preserve Ousel's source, history, releases, and links. Do not delete or reuse its repository for unrelated source.

Before archiving:

- Native build and recorder checks pass.
- Physical lid-close, wake, cancellation, and failure tests are documented.
- At least one live supported-agent run demonstrates useful observed progress/state.
- A short recording shows real behavior and limits.
- Borrow has its own GitHub repository and understandable README.
- Update the portfolio/profile links and add an Ousel archive notice, then archive its repository.

The current prototype is not yet through this gate.
