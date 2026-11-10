#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/borrow-package.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
swift build -c release --scratch-path "$build_dir/build"
bin_dir="$(swift build -c release --scratch-path "$build_dir/build" --show-bin-path)"
app="$build_dir/Borrow.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers"
cp "$bin_dir/BorrowApp" "$app/Contents/MacOS/BorrowApp"
cp "$bin_dir/borrow" "$app/Contents/Helpers/borrow"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Borrow</string>
<key>CFBundleDisplayName</key><string>Borrow</string>
<key>CFBundleIdentifier</key><string>com.figo5.borrow</string>
<key>CFBundleExecutable</key><string>BorrowApp</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app/Contents/Helpers/borrow"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
mkdir -p "$PWD/dist"
ditto -c -k --norsrc --keepParent "$app" "$PWD/dist/Borrow.zip"
ditto --norsrc "$app" "$PWD/dist/Borrow.app"
echo "Built $PWD/dist/Borrow.app"
echo "Packaged $PWD/dist/Borrow.zip"
