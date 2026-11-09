# Publishing source and app releases

1. Run `./scripts/package.sh` on macOS. This compiles arm64 and x86_64, creates a universal app, verifies its ad-hoc signature, runs tests on the host architecture, and creates a ZIP plus SHA-256 file in `dist/`.
2. Test on actual Intel and Apple Silicon hardware before claiming full coverage of both.
3. Commit source, scripts, metadata, and docs. Keep binaries and credentials out of Git.
4. Create a version tag and GitHub prerelease; attach the universal ZIP and its SHA-256 file.
5. State clearly that beta downloads are not Developer ID signed or Apple notarized. Link Apple's first-open instructions. Never instruct users to disable Gatekeeper.
6. For a broadly distributed stable release, use Developer ID signing with hardened runtime, submit to Apple's notary service, staple and verify the ticket, and package and checksum that final app. Do not label an ad-hoc build notarized.
7. Add a live demo only after reviewing it for private content.

Native emoji are rendered with the system font. Do not bundle extracted Apple emoji artwork or fonts.

## Current limitations

Pins last for the current app session. No automatic updates or launch-at-login. Full-screen and multi-display behavior need broader manual coverage. Screenshots remain local, but the app is not sandboxed or independently security-audited.
