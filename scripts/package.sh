#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
FRIDGE_ARCH=universal ./scripts/build.sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
ZIP="Fridge-$VERSION-macOS-universal.zip"
ditto -c -k --sequesterRsrc --keepParent dist/Fridge.app "dist/$ZIP"
(cd dist && shasum -a 256 "$ZIP" > "$ZIP.sha256")
printf 'Packaged dist/%s (unnotarized beta).\n' "$ZIP"
