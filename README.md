# Fridge

**Screenshots that stick.** A tiny native macOS utility that turns screenshot previews into fridge magnets. The GitHub repository is named `fridge-screen`.

Take a screenshot. Ignore it and the preview slides away after five seconds. Click its magnet and it stays within reach.

## Download the app

**[Download Fridge 0.3.0 beta for Mac](https://github.com/bhavya-in-sf/fridge-screen/releases/tag/v0.3.0-beta.1)**

Choose **Fridge-0.3.0-macOS-universal.zip** under Assets. It includes a ready-built app for Apple Silicon and Intel Macs running macOS 14 or newer. No developer tools are needed to use the download. GitHub's separate “Source code” archives are for developers.

1. Unzip the download and drag **Fridge.app** into **Applications**.
2. Open Fridge. This beta is **ad-hoc signed, not Developer ID signed or Apple notarized**. macOS may block its first launch.
3. If you trust this release and macOS blocks it, follow [Apple's instructions](https://support.apple.com/en-us/102445): after trying to open it, go to **System Settings → Privacy & Security → Open Anyway**, then confirm. Managed Macs may prohibit this. Do not disable Gatekeeper.
4. Choose the screenshot folder if needed and allow folder access when macOS asks.
5. Click **Try magnet animation**, then **Keep running in menu bar**.

This is an early beta, not a security-audited or Apple-verified release. The adjacent SHA-256 file lets you check download integrity; it does not replace developer signing or notarization. To stop the app, choose **Quit Fridge** from its menu-bar menu. It does not start automatically at login.

## Using Fridge

1. Open `Fridge.app`. The welcome window confirms that the screenshot folder is being watched.
2. Choose **Try magnet animation** for a sample, or take a screenshot with **⌘⇧4**.
3. Click the star, strawberry, or olive magnet to keep the screenshot. Click it again to release.
4. Choose **Keep running in menu bar** to hide the welcome window.

| Interaction | Result |
|---|---|
| Leave a new preview alone | Slides away after five seconds, starting after its entrance animation |
| Hover | Pauses the timer and shows a larger preview |
| Click the magnet | Pins it indefinitely during the current app session |
| Click a pinned magnet | Releases and dismisses it |
| Click the screenshot | Shows a larger preview without pinning |
| Drag the screenshot into a compatible app | Shares the original image file as a copy; pinned originals remain |
| Right-click | Pin/release, open, reveal in Finder, copy image, or dismiss |
| Fill the visible edge | Pinned items are retained in **Saved magnets**, with a `+N saved magnets` button |

The countdown also pauses during dragging and context menus. Removing a magnet never deletes the screenshot file. Pinned items are kept in memory during the current session; they do not persist after quitting.

## Build and run locally

The app download and the source code are both available. To inspect, modify, or build the app yourself, use the instructions below.

Requires macOS 14 or later and Apple's Xcode Command Line Tools. Build on your own Mac:

```sh
./scripts/build.sh
open dist/Fridge.app
```

The build script targets your Mac's architecture and signs the local build ad hoc. No package manager or third-party runtime is required; the app uses AppKit, QuartzCore, and ImageIO. `FRIDGE_ARCH` can override the architecture, but cross-built executables are not automatically tested on the build host.

## Screenshot folder and permissions

The app reads the macOS screenshot save location at startup, falling back to Desktop. **Choose screenshot folder…** can override that folder. macOS may request permission to read Desktop or another selected folder. No Accessibility permission is needed for the watcher.

For one preview rather than two, open **⌘⇧5 → Options** and turn off **Show Floating Thumbnail**. With Apple's thumbnail enabled, Fridge may not appear until macOS finishes saving the image. Screenshots copied only to the clipboard, saved directly into another app, or recorded as videos are not detected.

## Screen recording

The [recording guide](docs/RECORDING.md) describes the live capture, five-second dismissal, click-to-keep, drag-to-share, and release flow. A real screen recording will be added after it is captured and reviewed.

## Tests

The build script runs headless tests for:

- File classification, regular-image filtering, and duplicate detection.
- Ignoring pre-existing screenshots and ordinary image files.
- Retrying an incomplete screenshot and delivering it once after it finishes writing.
- Five-second expiry, pause-on-hover, pause-during-drag/menu, persistent pins, and one-time expiration.

The GitHub Actions workflow builds and tests both architectures. Release ZIPs contain the app; the source remains available in this repository. Manual acceptance steps are in [TESTING.md](docs/TESTING.md).

## Privacy and limitations

- No accounts, analytics, network requests, uploads, or cloud storage in the app.
- Bright star, strawberry, and olive magnets use the Mac’s native emoji font at runtime; no emoji artwork or font files are bundled.
- The app is not App Sandbox enabled. Only grant screenshot-folder access you are comfortable with.
- Copy image copies the display preview; drag-and-drop shares the full original file.
- Existing screenshots are not imported on launch.
- Screenshot metadata, English default filenames, and the configured custom filename are recognized. Localized screenshots may depend on Spotlight metadata.
- Only low-resolution display thumbnails are decoded; sharing uses the original file.
- Folder modification time is checked every 0.4 seconds; a full scan occurs only after changes or while writes are pending.
- Floating magnets are visible to recording tools. They may also appear in screenshots that include their area.
- Full-screen apps may manage their own window stacking. Display changes move current magnets onto the main display.
- Animations respect the macOS Reduce Motion setting.
- Demo images are stored in Fridge's local cache directory.

To build a universal release ZIP and checksum locally, run `./scripts/package.sh`. The generated app is ad-hoc signed and unnotarized.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Please omit private screenshots from bug reports.

## License

[MIT](LICENSE).
