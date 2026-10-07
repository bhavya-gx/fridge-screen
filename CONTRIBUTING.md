# Contributing

Build with `./scripts/build.sh`, then exercise the checklist in `docs/TESTING.md`. Keep changes focused and include the macOS version and architecture in bug reports.

For interaction changes, cover the state transition with a headless test where possible, then verify it in the native app. Preserve original screenshot files, respect Reduce Motion, and avoid adding network calls to the capture flow.

Open a pull request describing the user-visible change, validation performed, and any limitations. Do not commit screenshot libraries, logs, certificates, signing keys, or local credentials.
