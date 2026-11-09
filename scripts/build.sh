#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
FRIDGE_ARCH="${FRIDGE_ARCH:-$(uname -m)}"
FRIDGE_APP="dist/Fridge.app"
mkdir -p "$FRIDGE_APP/Contents/MacOS" "$FRIDGE_APP/Contents/Resources" .build/module-cache
cp LICENSE "$FRIDGE_APP/Contents/Resources/LICENSE"
cp Resources/Info.plist "$FRIDGE_APP/Contents/Info.plist"
build_arch() {
  xcrun swiftc -O -target "$1-apple-macos14.0" \
    -module-cache-path .build/module-cache \
    -framework Cocoa -framework QuartzCore -framework ImageIO \
    -o ".build/Fridge-$1" Source/main.swift
}
case "$FRIDGE_ARCH" in
  universal)
    build_arch arm64
    build_arch x86_64
    lipo -create .build/Fridge-arm64 .build/Fridge-x86_64 -output "$FRIDGE_APP/Contents/MacOS/Fridge"
    ;;
  arm64|x86_64)
    build_arch "$FRIDGE_ARCH"
    cp ".build/Fridge-$FRIDGE_ARCH" "$FRIDGE_APP/Contents/MacOS/Fridge"
    ;;
  *) printf 'Unsupported architecture: %s\n' "$FRIDGE_ARCH" >&2; exit 1 ;;
esac
codesign --force --sign - "$FRIDGE_APP"
codesign --verify --strict "$FRIDGE_APP"
if [ "$FRIDGE_ARCH" = universal ] || [ "$FRIDGE_ARCH" = "$(uname -m)" ]; then
  "$FRIDGE_APP/Contents/MacOS/Fridge" --self-test
  "$FRIDGE_APP/Contents/MacOS/Fridge" --watch-test
fi
printf 'Built %s (%s); locally signed, not notarized.\n' "$FRIDGE_APP" "$FRIDGE_ARCH"
