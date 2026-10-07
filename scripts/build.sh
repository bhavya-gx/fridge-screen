#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
FRIDGE_ARCH="${FRIDGE_ARCH:-$(uname -m)}"
FRIDGE_APP="dist/Fridge.app"
mkdir -p "$FRIDGE_APP/Contents/MacOS" "$FRIDGE_APP/Contents/Resources" .build/module-cache
cp LICENSE "$FRIDGE_APP/Contents/Resources/LICENSE"
cp Resources/Info.plist "$FRIDGE_APP/Contents/Info.plist"
xcrun swiftc -O -target "${FRIDGE_ARCH}-apple-macos14.0" \
  -module-cache-path .build/module-cache \
  -framework Cocoa -framework QuartzCore -framework ImageIO \
  -o "$FRIDGE_APP/Contents/MacOS/Fridge" Source/main.swift
codesign --force --sign - "$FRIDGE_APP"
codesign --verify --strict "$FRIDGE_APP"
if [ "$FRIDGE_ARCH" = "$(uname -m)" ]; then
  "$FRIDGE_APP/Contents/MacOS/Fridge" --self-test
  "$FRIDGE_APP/Contents/MacOS/Fridge" --watch-test
fi
printf 'Built %s (%s); locally signed, not notarized.\n' "$FRIDGE_APP" "$FRIDGE_ARCH"
