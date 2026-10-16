#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/MDView.app/Contents/{MacOS,Resources} build/module-cache
APP=build/MDView.app
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/index.html Resources/viewer.css "$APP/Contents/Resources/"
if [ ! -f Resources/viewer.js ]; then echo 'Run npm ci --ignore-scripts && npm run bundle first.' >&2; exit 1; fi
cp Resources/viewer.js "$APP/Contents/Resources/"
[ ! -f Resources/AppIcon.icns ] || cp Resources/AppIcon.icns "$APP/Contents/Resources/"
[ ! -f Resources/viewer.js.LEGAL.txt ] || cp Resources/viewer.js.LEGAL.txt "$APP/Contents/Resources/"
if [ "${1:-}" = "test" ]; then
    xcrun swiftc -swift-version 5 -D TESTING -target "${TEST_ARCH:-arm64}-apple-macos13.0" -module-cache-path build/module-cache -O Sources/*.swift Tests/Integration.swift -o "$APP/Contents/MacOS/MDView" -framework AppKit -framework WebKit -framework ImageIO
else
    for arch in arm64 x86_64; do
        xcrun swiftc -swift-version 5 -target "$arch-apple-macos13.0" -module-cache-path build/module-cache -O Sources/*.swift -o "build/MDView-$arch" -framework AppKit -framework WebKit -framework ImageIO
    done
    lipo -create build/MDView-arm64 build/MDView-x86_64 -output "$APP/Contents/MacOS/MDView"
fi
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
echo "Built $APP"
