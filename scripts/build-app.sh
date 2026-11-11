#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="$(cat Sources/BorrowCore/Resources/VERSION)"
if [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo "Sources/BorrowCore/Resources/VERSION must contain a numeric major.minor.patch version." >&2
  exit 1
fi
build_number="${BORROW_BUILD_NUMBER:-4}"
if [[ ! "$build_number" =~ ^[1-9][0-9]{0,3}$ ]]; then
  echo "BORROW_BUILD_NUMBER must be an integer from 1 through 9999." >&2
  exit 1
fi
source_root="$(pwd -P)"
source_commit="source-archive"
if git_root="$(git rev-parse --show-toplevel 2>/dev/null)" && [[ "$(cd "$git_root" && pwd -P)" == "$source_root" ]]; then
  revision="$(git rev-parse --verify HEAD 2>/dev/null || true)"
  if [[ "$revision" =~ ^[0-9a-f]{40}$ ]]; then
    source_commit="$revision"
    if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
      source_commit="${source_commit}-dirty"
    fi
  fi
fi
build_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/borrow-package.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
swift build -c release --scratch-path "$build_dir/build"
bin_dir="$(swift build -c release --scratch-path "$build_dir/build" --show-bin-path)"
app="$build_dir/Borrow.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers" "$app/Contents/Resources"
cp "$bin_dir/BorrowApp" "$app/Contents/MacOS/BorrowApp"
cp "$bin_dir/borrow" "$app/Contents/Helpers/borrow"
resource_bundle="$bin_dir/Borrow_BorrowCore.bundle"
if [[ ! -d "$resource_bundle" ]]; then
  echo "The BorrowCore version resource bundle is missing." >&2
  exit 1
fi
ditto --norsrc "$resource_bundle" "$app/Contents/Resources/Borrow_BorrowCore.bundle"
app_arches="$(lipo -archs "$app/Contents/MacOS/BorrowApp")"
helper_arches="$(lipo -archs "$app/Contents/Helpers/borrow")"
if [[ "$app_arches" != "$helper_arches" ]]; then
  echo "App and CLI architectures do not match." >&2
  exit 1
fi
case "$app_arches" in
  arm64) architecture="arm64" ;;
  x86_64) architecture="x86_64" ;;
  "arm64 x86_64"|"x86_64 arm64") architecture="universal" ;;
  *) echo "Unexpected build architecture: $app_arches" >&2; exit 1 ;;
esac
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Borrow</string>
<key>CFBundleDisplayName</key><string>Borrow</string>
<key>CFBundleIdentifier</key><string>com.figo5.borrow</string>
<key>CFBundleExecutable</key><string>BorrowApp</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>$build_number</string>
<key>BorrowSourceCommit</key><string>$source_commit</string>
<key>BorrowBuildArchitecture</key><string>$architecture</string>
<key>BorrowBuildDate</key><string>$build_time</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app/Contents/Helpers/borrow"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
mkdir -p "$PWD/dist"
archive_name="Borrow-${version}-macOS-${architecture}.zip"
ditto -c -k --norsrc --keepParent "$app" "$PWD/dist/$archive_name"
cp "$PWD/dist/$archive_name" "$PWD/dist/Borrow.zip"
rm -rf "$PWD/dist/Borrow.app"
ditto --norsrc "$app" "$PWD/dist/Borrow.app"
cat > "$PWD/dist/BUILD-INFO.txt" <<INFO
Borrow $version preview
Build: $build_number
Architecture: $architecture
Source: $source_commit
Built: $build_time
Signing: ad-hoc; not Developer ID signed or notarized
INFO
(
  cd "$PWD/dist"
  shasum -a 256 "$archive_name" Borrow.zip > SHA256SUMS
  shasum -a 256 -c SHA256SUMS
)
echo "Built $PWD/dist/Borrow.app"
echo "Packaged $PWD/dist/$archive_name"
echo "Compatibility archive: $PWD/dist/Borrow.zip"
echo "Checksums: $PWD/dist/SHA256SUMS"
