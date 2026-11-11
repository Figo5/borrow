# Build and try the preview

Borrow is currently a source-first macOS preview. It requires macOS 14 or later and Swift 6 through Xcode or Command Line Tools. It has no third-party package dependencies. Build the version you intend to inspect; a preview package is not a Developer ID signed or notarized distribution.

## Build from a checkout

Quit an already-running Borrow before rebuilding its app bundle. From the repository directory:

```sh
swift --version
swift test --scratch-path "$(mktemp -d)"
bash scripts/build-app.sh
open dist/Borrow.app
```

Maintainers can verify the extracted archive after building with `bash scripts/verify-package.sh`. It checks the unpacked signature, executable architecture, helper version/help, and version metadata. CI performs this step before retaining an artifact. It does not establish notarization or physical compatibility.

The temporary test path avoids signing failures caused by Finder metadata in some synced folders. The packaging script already builds and ad-hoc signs in a temporary directory.

The build produces:

- `dist/Borrow.app`: the native app, including its recorder helper.
- `dist/Borrow-0.3.0-macOS-arm64.zip` on Apple Silicon, or `dist/Borrow-0.3.0-macOS-x86_64.zip` on Intel. The label describes the binaries actually built; one architecture does not imply a universal build.
- `dist/Borrow.zip`: a compatibility copy of the current architecture's ZIP.
- `dist/SHA256SUMS` and `dist/BUILD-INFO.txt`: archive integrity and version, build, architecture, source revision, and signing information. An uncommitted checkout is labelled `dirty`.

The version comes from `Sources/BorrowCore/Resources/VERSION`. Maintainers can set an integer `BORROW_BUILD_NUMBER` from 1 through 9999 when packaging. The default preview build number is 4.

To check the packaged files against their checksums:

```sh
cd dist
shasum -a 256 -c SHA256SUMS
```

A matching checksum detects archive changes relative to that checksum file; it is not a Developer ID identity check. GitHub Actions artifacts contain a labelled ZIP, its compatibility copy, checksums, and build metadata. The workflow's Intel build is labelled `x86_64`; it does not replace an Apple Silicon validation run.

## First recording

Start with a short open-lid rehearsal in **Off** mode. Review work, final result, sampling, and hold findings independently. Then choose a bounded hold mode deliberately:

| Mode | Scope |
| --- | --- |
| Off | Record without requesting a Borrow wake hold. |
| Idle | Request temporary prevention of idle system sleep; lid-close sleep is still possible. |
| Experimental AC | Try a bounded system-sleep hold on AC power. Charger-only/no-display behavior requires physical validation on that exact setup. |

The app releases only its own hold. It does not change global sleep settings, end other applications' holds, force the Mac to sleep, or certify an agent's work. Review the [sleep-control research](sleep-control-research.md) and [privacy information](privacy.md) before a real-agent run.

The bundled recorder supports the same explicit mode names:

```sh
dist/Borrow.app/Contents/Helpers/borrow rehearse --duration 30 --wake off
dist/Borrow.app/Contents/Helpers/borrow run --timeout 600 --wake idle -- /usr/bin/make test
```

Use `--wake experimental-ac` only for a deliberately chosen AC-only compatibility test. The recorder caps the requested hold to its bounded recording deadline. Choose a disposable `--output DIRECTORY` for command-line verification if you do not want test recordings in the app's default list.

## Remove the preview

Stop active recordings first so Borrow can finish its reports and release its holds. Move the built app or extracted preview app to Trash using Finder. Source checkouts and local reports are separate from the app: recordings remain in `~/Library/Application Support/Borrow/Runs/` until you deliberately remove them. Borrow does not install a login daemon or privileged helper.
