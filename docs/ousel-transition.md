# Conditional Ousel transition map

November 10, 2026 · read-only inventory and proposed handoff

**Status: proposed, not applied.** The user chose to archive Ousel once Borrow is ready. This document maps the existing public references so that transition can be reviewed without deleting or repurposing Ousel. No remote file, profile pin, repository visibility, release, or archive state was changed during this inventory.

## Observed targets

| Surface | Verified current state | Proposed change once ready |
| --- | --- | --- |
| [Ousel repository](https://github.com/Figo5/ousel) | Public, not archived, default branch `main` | Preserve the repository/history and archive only after the transition checks below |
| [Ousel README](https://github.com/Figo5/ousel/blob/main/README.md) | Opens with its active local agent-team workspace description; existing real walkthrough and historical AgentOps footage remain linked | Add an archive/maintenance notice at the top, with a link to Borrow and a clear explanation that it is a different project, not an Ousel API/data migration |
| Ousel repository homepage metadata | Still points to the old `Figo5/agentops#try-a-sample-workflow` URL | Use the canonical Ousel README/sample-workflow link if correcting metadata during archival; do not redirect old source to unrelated Borrow contents |
| [GitHub profile](https://github.com/Figo5) | Four public pins: SQLSage, Ousel, DiffGuard, Lab in a Box | Replace the Ousel pin with Borrow after Borrow has a working public destination; preserve the other pins and order |
| [Profile repository](https://github.com/Figo5/Figo5) | Public repository root is empty; the README endpoint returned not found | There is no existing profile README reference to edit. Do not create a new profile README solely for this swap |
| [Live portfolio](https://gfiore.com) | Ousel appears as the second featured project with GitHub link, screenshot poster, and walkthrough | Replace that featured slot with Borrow only when an authentic Borrow demo and public destination exist |
| [Curated portfolio data](https://github.com/Figo5/gfiore.com/blob/main/app/featured-projects/projects.ts) | The `Ousel` object supplies name, description, TypeScript stack, repository URL, video/poster, caption, and GitHub link | Replace that object with reviewed Borrow metadata and actual Borrow media dimensions/paths; preserve the rest of the carousel |
| [Portfolio media](https://github.com/Figo5/gfiore.com/tree/main/public/projects) | `ousel-demo.mp4` and `ousel.png` back the existing feature | Add separate Borrow media. Preserve the Ousel assets/history rather than overwrite them with Borrow files |
| [Portfolio fallback snapshot](https://github.com/Figo5/gfiore.com/blob/main/content/github-fallback.json) | Contains an active `ousel` repository entry and no `borrow` entry | Refresh through the existing public-data flow after publication/archival; retain Ousel with truthful archived status rather than inventing Borrow metadata |
| [Portfolio README](https://github.com/Figo5/gfiore.com/blob/main/README.md) | Layout table describes `public/projects/` as screenshots and the Ousel walkthrough | Update that narrow description if Borrow media becomes the current featured walkthrough |

The portfolio source is [Figo5/gfiore.com](https://github.com/Figo5/gfiore.com). It was resolved from the profile's public website field and verified against the live page and public source. No private-repository inventory was required.

## Proposed Borrow presentation

- **Name:** Borrow
- **Description:** Native macOS task recording with bounded wake holds and evidence for unattended work.
- **Stack:** Swift · macOS
- **Stage:** Preview, while the release remains a preview
- **Destination:** `https://github.com/Figo5/borrow`, only after the approved public destination is actually accessible
- **Media:** the authentic native demo and a reviewed still, with dimensions and accessible text taken from the final artifacts
- **Caption:** describe the exact demonstrated setup; distinguish idle prevention, experimental closed-lid behavior, hold release, and independently observed system sleep

Do not describe Borrow as a general closed-lid guarantee, an Ousel-compatible upgrade, or a verified agent-correctness tool. Do not publish a portfolio link whose only destination is still private or whose media has not been recorded.

## Ordered transition gate

1. Finish Borrow's native/core checks and review, real-agent physical evidence, and authentic demo. Preserve limitations and inconclusive results. The separate Ousel readiness gate in [the product brief](product-brief.md) remains authoritative.
2. Complete orchestration Gate 2 with the actual diff, validation, demo, release assets, and proposed commits. Obtain the applicable public-publication/visibility decision; release preparation itself does not make the repository public.
3. Verify Borrow's public source/README and chosen installation path. A source-first preview must still state that a Developer ID notarized download is unavailable.
4. Prepare and review the narrow portfolio change in `app/featured-projects/projects.ts`, new Borrow media, the media-layout wording, and a truthful fallback refresh. Do not replace Ousel files with unrelated source.
5. Add the reviewed Ousel archive notice while its repository is still writable. Suggested substance: maintenance has ended; source, history, and existing material remain available; Borrow is the current separate macOS project, with its own behavior and limitations.
6. Publish/verify the approved portfolio and profile-pin swap, checking the public Borrow link, media playback, accessible labels, and mobile/keyboard carousel behavior.
7. Archive `Figo5/ousel` without deleting its source, issues, releases, demos, history, or repository identity. Confirm the resulting archive state and that the archive notice and old links remain readable.
8. Refresh/verify public repository metadata after archival so the portfolio does not continue describing Ousel as active. Record the completed links and exact result instead of treating a requested change as completion.

## Still pending

The longer physical comparison is in progress or awaiting its final evidence, the native demo is not yet recorded, Gate 2 has not occurred, and public-release/portfolio/profile/archive changes have not been performed. The inventory establishes where the eventual changes belong; it does not make Ousel ready to archive.
