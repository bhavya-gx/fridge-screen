# Contributing

Build and run automated tests with `./scripts/build.sh`. Keep changes focused and include the macOS version and architecture in bug reports.

For interaction changes, cover the state transition with a headless test where possible, then verify it in the native app. Preserve original screenshot files, respect Reduce Motion, and avoid adding network calls to the capture flow.

Open a pull request describing the user-visible change, validation performed, and any limitations. Do not commit screenshot libraries, logs, certificates, signing keys, or local credentials.

## Maintainer review
Contributions are proposals, not automatic additions. The maintainer decides whether they fit the project's purpose: a small, local screenshot utility.

Before merging, review the actual diff as well as the test results. Check file access, networking, permissions, dependencies, build scripts, and GitHub Actions changes. Never run untrusted contribution code with credentials or private screenshots available. Do not add secrets to pull-request workflows or use pull_request_target to execute contributor code.

Main requires a pull request, a passing macos check, and resolved review conversations. No additional approval is required while the project has one maintainer, so the maintainer can merge their own changes. External contributors have no merge permission.

Release new versions from reviewed commits. Prepare assets in a draft before publishing when immutable releases are enabled. Existing downloads are not automatically updated.
