#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="$(cat Sources/BorrowCore/Resources/VERSION)"
archive="${1:-$PWD/dist/Borrow.zip}"
archive="$(cd "$(dirname "$archive")" && pwd -P)/$(basename "$archive")"
verify_dir="$(mktemp -d "${TMPDIR:-/tmp}/borrow-verify.XXXXXX")"
trap 'rm -rf "$verify_dir"' EXIT
ditto -x -k "$archive" "$verify_dir"
app="$verify_dir/Borrow.app"
helper="$app/Contents/Helpers/borrow"
test -x "$app/Contents/MacOS/BorrowApp"
test -x "$helper"
codesign --verify --deep --strict "$app"
plist_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
test "$plist_version" = "$version"
test "$("$helper" --version)" = "$version"
"$helper" --help > "$verify_dir/help.txt"
if ! /usr/bin/grep -Fq "Borrow $version" "$verify_dir/help.txt"; then
  echo "The packaged recorder help has an unexpected version." >&2
  exit 1
fi
app_arches="$(lipo -archs "$app/Contents/MacOS/BorrowApp")"
test "$app_arches" = "$(lipo -archs "$helper")"
case "$app_arches" in
  arm64) architecture="arm64" ;;
  x86_64) architecture="x86_64" ;;
  "arm64 x86_64"|"x86_64 arm64") architecture="universal" ;;
  *) echo "Unexpected package architecture." >&2; exit 1 ;;
esac
test "$architecture" = "$(/usr/libexec/PlistBuddy -c 'Print :BorrowBuildArchitecture' "$app/Contents/Info.plist")"
echo "Verified Borrow $version ($architecture): extracted signature, executables, version resource, and help."
echo "Signing is ad-hoc; this check does not establish notarization."
