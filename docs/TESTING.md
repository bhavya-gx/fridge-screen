# Manual acceptance checklist

- Launch shows the welcome window. Reopening restores it. Cmd-Q quits.
- A new screenshot appears after the file is saved. Existing screenshots are ignored.
- Keep the pointer away: the preview leaves five seconds after its arrival.
- Hover before expiry: wait longer than five seconds; the preview remains. Move away and it expires after the remaining time.
- Click the magnet before expiry. Confirm the hint changes to Pinned, then move away and wait at least ten seconds.
- Click the pinned magnet again. It lifts and the card slides away. Original file still exists.
- Click the screenshot area: preview opens without pinning it.
- Drag a pinned capture to Notes or a local draft that accepts image files. Verify the image arrives and the pinned original stays.
- Keep the context menu open longer than five seconds; the temporary preview must not disappear beneath it.
- Pin more images than fit. Use +N saved magnets or the menu-bar Saved magnets list to bring an older one back.
- Check a second display, disconnect it, and confirm retained pins move to the main display.
- With Reduce Motion on, magnets appear, rearrange, and leave without animating.
- By default, magnets do not appear in a screenshot that covers them, a screen recording, or a live screen share (Zoom, Meet). Turn on **Show magnets in screen recordings** and confirm they now appear, including magnets already on screen.
- Right-click → Copy image, then in Preview choose File → New from Clipboard. The image matches the original's full pixel size, not the small preview.
- Press ⌃⌥⌘K while a magnet is counting down: it pins. With nothing counting down, the Mac beeps and **Keep latest screenshot** is greyed out.
- Choose a screenshot folder, then **Use macOS screenshot folder**: watching returns to the macOS setting and the item greys out.
- In **Choose screenshot folder…**, press ⌘⇧G and paste a path with ⌘V. ⌘W closes the welcome window.
- Point Fridge at an unreadable folder: the menu shows the error, and it stays after Pause then Resume.
- Quit and reopen: current pins are intentionally not restored; files remain on disk.

Before a public release, repeat on a clean Mac with the minimum supported OS and validate any architecture included in the download.
