# Preview artifacts and provenance

Prepared November 12, 2026 for **0.3.0 preview**, build 4. A private, unpublished draft named `v0.3.0-preview` is prepared under [GitHub Releases](https://github.com/Figo5/borrow/releases) with ten assets. The repository remains private and no tag reference was created. This draft does not validate closed-lid behavior or publish the preview.

The combined review folder is `dist/preview-2026-11-12/`:

| File | Origin and scope |
| --- | --- |
| `Borrow-0.3.0-macOS-arm64.zip` | Clean local build of software revision `7e9b97a0d2121b7b123c8e8b963d8f64fea62cc6`; extracted-package and native UI checks passed on Apple Silicon |
| `Borrow-0.3.0-macOS-x86_64.zip` | Retained from [successful hosted Intel run 43086166624](https://github.com/Figo5/borrow/actions/runs/43086166624), same revision; tested and extracted there, not locally UI-tested |
| `Borrow-0.3.0-source.zip` | Source, tests, scripts, workflow and current reviewed documentation; code/build inputs match the binary revision; documentation includes the November 12 follow-up |
| `BUILD-INFO-arm64.txt`, `BUILD-INFO-x86_64.txt` | Original architecture-specific build metadata |
| `SOURCE-MANIFEST.json` | SHA-256 for all source, test, package, workflow and issue-form inputs used by these builds |
| `PREVIEW-STATUS.md`, `RELEASE-NOTES.md` | Review snapshot, validation scope and remaining work |
| `SHA256SUMS`, `HANDOFF-SHA256SUMS` | Combined integrity checks; the latter is a compatibility copy of the former |

Check integrity from inside that folder:

```sh
shasum -a 256 -c SHA256SUMS
```

Both app ZIPs are **ad-hoc signed, not Developer ID signed or notarized**. Matching checksums establish consistency with this checksum file, not an Apple distribution identity. The source-first route is described in [installation](installation.md); no operating-system security bypass is part of this handoff.

The source archive excludes Git history, build output, local recordings, raw agent journals, work logs, credentials and model transcripts. Its documentation can be newer than the binary commit without implying changed executable inputs. `SOURCE-MANIFEST.json` makes that boundary checkable. Existing committed sanitized evidence remains included.

All 73 local tests passed with native integration enabled; the hosted default suite passed 70 and skipped three opt-in native checks. Fresh native UI checks and [their evidence](wake-lease-validation.md#november-12-final-software-check) are complete. Closed-lid real-agent behavior, physical unplug handling, actual post-task sleep, the final video and wider compatibility remain unverified. The operator deferred video capture on November 12.

Keep the repository private and the release draft unpublished until the outstanding evidence and final release review are complete. Ousel's readiness conditions remain separate; no archive or portfolio change is part of this artifact refresh.
