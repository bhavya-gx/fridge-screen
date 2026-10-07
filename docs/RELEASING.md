# Publishing the source

Publish this repository as `magnet` under the maintainer's GitHub account. This release is source-only: no prebuilt `.app`, app ZIP, DMG, signing certificates, or notarization setup is required for publishing the repository.

1. Run `./scripts/build.sh` and follow `TESTING.md`.
2. Commit only source, resource metadata, scripts, documentation, and the MIT license. `.gitignore` excludes local build output and credentials.
3. Push to the public repository. CI builds and tests but does not upload binaries.
4. Review the finished live screen recording for private content, then add it to the README through a GitHub-hosted video attachment or a public video link.
5. Optionally tag `v0.2.0`. GitHub can supply source archives automatically; do not attach compiled app assets.

## Suggested announcement

Fridge turns screenshots into little fridge magnets on your Mac. Previews disappear after five seconds; click the magnet to keep one, and click again to release it. Hover to preview and drag into another app to share.

Open source under the MIT license. Build instructions are in the README. macOS 14 or newer; pins last for the current app session.
