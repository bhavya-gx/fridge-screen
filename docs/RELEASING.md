# Releasing

Fridge is distributed as source code only. There is no prebuilt app, DMG, App Store release, or notarization.

1. Run `./scripts/build.sh`, then work through [TESTING.md](TESTING.md) on the minimum supported macOS version.
2. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
3. Commit source, resources, scripts, and documentation only. `.gitignore` excludes build output and credentials.
4. Tag the release, for example `v0.3.0`. GitHub provides the source archives; do not attach compiled apps.
