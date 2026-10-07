# Fridge

**Screenshots that stick.** A tiny native macOS utility that turns screenshot previews into fridge magnets.

Take a screenshot. Ignore it and the preview slides away after five seconds. Click its magnet and it stays within reach.

## Using Fridge

1. Open `Fridge.app`. The welcome window confirms that the screenshot folder is being watched.
2. Choose **Try magnet animation** for a sample, or take a screenshot with **⌘⇧4**.
3. Click the star, strawberry, or olive magnet to keep the screenshot, or press **⌃⌥⌘K**. Click the magnet again to release.
4. Choose **Keep running in menu bar** to hide the welcome window.

| Interaction | Result |
|---|---|
| Leave a new preview alone | Slides away after five seconds, starting after its entrance animation |
| Hover | Pauses the timer and shows a larger preview |
| Click the magnet | Pins it indefinitely during the current app session |
| Press ⌃⌥⌘K | Pins the newest magnet, no mouse needed. Also in the menu bar as **Keep latest screenshot** |
| Click a pinned magnet | Releases and dismisses it |
| Click the screenshot | Shows a larger preview without pinning |
| Drag the screenshot into a compatible app | Shares the original image file as a copy; pinned originals remain |
| Right-click | Pin/release, open, reveal in Finder, copy the full-resolution image, or dismiss |
| Fill the visible edge | Pinned items are retained in **Saved magnets**, with a `+N saved magnets` button |

The countdown also pauses during dragging and context menus. Removing a magnet never deletes the screenshot file. Pinned items are kept in memory during the current session; they do not persist after quitting.

## Build and run locally

This project is distributed as source code only. There is no prebuilt app download or App Store release, and publishing this source does not require Apple notarization.

Requires macOS 14 or later and Apple's Xcode Command Line Tools. Build on your own Mac:

```sh
./scripts/build.sh
open dist/Fridge.app
```

The build script targets your Mac's architecture and signs the local build ad hoc. No package manager or third-party runtime is required; the app uses AppKit, QuartzCore, and ImageIO. `FRIDGE_ARCH` can override the architecture, but cross-built executables are not automatically tested on the build host.

## Screenshot folder and permissions

The app reads the macOS screenshot save location at startup, falling back to Desktop. **Choose screenshot folder…** can override that folder, and **Use macOS screenshot folder** goes back to following the macOS setting. macOS may ask permission to read Desktop, Documents, Downloads, or an external drive, depending on where your screenshots are saved. No Accessibility or Input Monitoring permission is needed, including for the ⌃⌥⌘K shortcut.

For one preview rather than two, open **⌘⇧5 → Options** and turn off **Show Floating Thumbnail**. With Apple's thumbnail enabled, Fridge may not appear until macOS finishes saving the image. Screenshots copied only to the clipboard, saved directly into another app, or recorded as videos are not detected.

## Tests

The build script runs headless tests for:

- File classification, regular-image filtering, and duplicate detection.
- Ignoring pre-existing screenshots and ordinary image files.
- Retrying an incomplete screenshot and delivering it once after it finishes writing.
- Five-second expiry, pause-on-hover, pause-during-drag/menu, persistent pins, and one-time expiration.
- Copy image keeping the original's full resolution, and falling back to the preview if the original has moved.
- A folder error staying visible through pause and resume.
- Registering the ⌃⌥⌘K shortcut.

The GitHub Actions workflow builds and tests the source without uploading app binaries. Manual acceptance steps are in [TESTING.md](docs/TESTING.md).

## Privacy and limitations

- No accounts, analytics, network requests, uploads, or cloud storage.
- Existing screenshots are not imported on launch.
- Screenshot metadata, English default filenames, and the configured custom filename are recognized. Localized screenshots may depend on Spotlight metadata.
- Only low-resolution display thumbnails are decoded; sharing uses the original file.
- Folder modification time is checked every 0.4 seconds; a full scan occurs only after changes or while writes are pending.
- Magnets are excluded from screen capture by default, so a screenshot of something private does not appear in a screen share, a recording, or your next screenshot. Turn on **Show magnets in screen recordings** in the menu bar when you want them visible, for example to record a demo.
- Full-screen apps may manage their own window stacking. Display changes move current magnets onto the main display.
- Animations respect the macOS Reduce Motion setting.
- Demo images are kept in Fridge's cache directory and cleared on the next launch.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Please omit private screenshots from bug reports.

## License

[MIT](LICENSE).
