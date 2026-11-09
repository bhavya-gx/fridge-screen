import Cocoa
import QuartzCore
import ImageIO
// magnet only reads newly created screenshots. Originals remain in their saved location.
struct ScreenshotIdentity: Hashable { let path: String; let created: Date }
struct ScreenshotScan {
    static let extensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "tif"]
    static func identity(_ url: URL) -> ScreenshotIdentity? {
        guard extensions.contains(url.pathExtension.lowercased()),
              let v = try? url.resourceValues(forKeys: [.creationDateKey, .isRegularFileKey]),
              v.isRegularFile == true, let date = v.creationDate else { return nil }
        return ScreenshotIdentity(path: url.path, created: date)
    }
    static func isScreenshot(_ url: URL) -> Bool {
        // Finder's screenshot metadata works even for localized or customized names.
        if let item = MDItemCreate(kCFAllocatorDefault, url.path as CFString),
           let flag = MDItemCopyAttribute(item, "kMDItemIsScreenCapture" as CFString) as? Bool, flag { return true }
        let name = url.lastPathComponent.lowercased()
        let custom = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "name")?.lowercased()
        return name.hasPrefix("screenshot") || name.hasPrefix("screen shot") || (custom.map { name.hasPrefix($0) } ?? false)
    }
}

final class ScreenshotWatcher {
    let queue = DispatchQueue(label: "fridge.screenshot-watcher", qos: .utility)
    var timer: DispatchSourceTimer?
    var known = Set<ScreenshotIdentity>()
    var lastDirectoryDate:Date?
    var pending: [ScreenshotIdentity: (size: Int, stable: Int, attempts: Int)] = [:]
    let started = Date()
    var folder: URL
    var onImage: ((URL, CGImage) -> Void)?
    var onError: ((String?) -> Void)?
    init(folder: URL) { self.folder = folder }
    func start() {
        queue.async { [self] in
            // Establish a baseline so launching never imports the existing screenshot library.
            if let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey, .isRegularFileKey]) {
                known = Set(files.compactMap(ScreenshotScan.identity))
            }
            let t = DispatchSource.makeTimerSource(queue: queue)
            t.schedule(deadline: .now() + 0.35, repeating: 0.4)
            t.setEventHandler { [weak self] in self?.scan() }
            timer = t; t.resume()
        }
    }
    func stop() { queue.async { [weak self] in self?.timer?.cancel(); self?.timer = nil } }
    func scan() {
        do {
            let directoryDate=try FileManager.default.attributesOfItem(atPath:folder.path)[.modificationDate] as? Date
            if pending.isEmpty,let directoryDate,directoryDate==lastDirectoryDate {return}
            lastDirectoryDate=directoryDate
            let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey, .isRegularFileKey, .fileSizeKey])
            DispatchQueue.main.async { [weak self] in self?.onError?(nil) }
            let fresh = files.compactMap { url -> (URL, ScreenshotIdentity)? in
                guard let id = ScreenshotScan.identity(url), !known.contains(id) else { return nil }
                if id.created < started.addingTimeInterval(-1) { known.insert(id); return nil }
                return (url, id)
            }.sorted { $0.1.created < $1.1.created }
            for (url, id) in fresh {
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                var p = pending[id] ?? (0, 0, 0)
                p.attempts += 1; p.stable = size == p.size && size > 0 ? p.stable + 1 : 0; p.size = size
                pending[id] = p
                // Wait until the screenshot service finishes writing, and allow metadata time to index.
                guard p.stable >= 1 else { continue }
                if ScreenshotScan.isScreenshot(url),
                   let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                   let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1600, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) {
                    known.insert(id); pending[id] = nil
                    DispatchQueue.main.async { [weak self] in self?.onImage?(url, cg) }
                } else if p.attempts > 30 { known.insert(id); pending[id] = nil }
            }
            let current = Set(files.compactMap(ScreenshotScan.identity))
            known.formIntersection(current)
            pending = pending.filter { current.contains($0.key) }
        } catch {
            DispatchQueue.main.async { [weak self] in self?.onError?("Can’t read screenshot folder. Choose a folder in the magnet menu.") }
        }
    }
}

// Use the system's emoji glyphs at runtime; no Apple artwork or fonts are bundled.
func magnetImage(kind: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: 76, height: 76))
    image.lockFocus()
    let glyph = (["⭐️", "🍓", "🫒"][kind % 3]) as NSString
    let font = NSFont(name: "Apple Color Emoji", size: 57) ?? NSFont.systemFont(ofSize: 57)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let size = glyph.size(withAttributes: attributes)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = 3
    shadow.shadowOffset = NSSize(width: 0, height: -3)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    glyph.draw(at: NSPoint(x: (76-size.width)/2, y: (76-size.height)/2+3), withAttributes: attributes)
    NSGraphicsContext.restoreGraphicsState()
    image.unlockFocus()
    return image
}

struct PinLifetime {
    var remaining:TimeInterval=5
    var pinned=false
    var hovered=false
    var dragging=false
    var menuOpen=false
    var arrived=false
    var expired=false
    mutating func advance(_ elapsed:TimeInterval)->Bool {
        guard arrived,!pinned,!hovered,!dragging,!menuOpen,!expired else { return false }
        remaining=max(0,remaining-max(0,elapsed))
        if remaining<=0 { expired=true;return true }
        return false
    }
}

final class PinView: NSView, NSDraggingSource, NSMenuDelegate {
    let image: NSImage
    let url: URL
    let kind: Int
    let tilt: CGFloat
    var dismiss: (() -> Void)?
    var peek: ((Bool) -> Void)?
    var keep: (() -> Void)?
    var hoverChanged: ((Bool) -> Void)?
    var dragChanged: ((Bool) -> Void)?
    var menuChanged: ((Bool) -> Void)?
    var pinned=false
    var down: NSPoint = .zero
    var dragging = false
    var tracking: NSTrackingArea?
    let paper = NSView()
    let photo = NSImageView()
    let magnet = NSButton()
    let hint=NSTextField(labelWithString:"Click magnet to keep · 5s")
    var paperRect: NSRect { NSRect(x: 14, y: 15, width: bounds.width-28, height: bounds.height-47) }
    init(image: NSImage, url: URL, kind: Int, frame: NSRect) {
        self.image=image; self.url=url; self.kind=kind; self.tilt = kind % 2 == 0 ? -0.035 : 0.045
        super.init(frame:frame)
        wantsLayer=true
        paper.wantsLayer=true; paper.layer?.backgroundColor=NSColor.white.cgColor
        paper.layer?.cornerRadius=9; paper.layer?.shadowColor=NSColor.black.cgColor; paper.layer?.shadowOpacity=0.20; paper.layer?.shadowRadius=8; paper.layer?.shadowOffset=CGSize(width:2,height:-4)
        addSubview(paper)
        photo.image=image; photo.imageScaling = .scaleProportionallyUpOrDown
        paper.addSubview(photo)
        magnet.image=magnetImage(kind:kind); magnet.imageScaling = .scaleProportionallyUpOrDown; magnet.wantsLayer=true
        magnet.isBordered=false;magnet.setButtonType(.momentaryChange);magnet.target=self;magnet.action=#selector(pressMagnet);magnet.title="";magnet.imagePosition = .imageOnly
        magnet.setAccessibilityLabel("Keep screenshot pinned");magnet.toolTip="Click magnet to keep"
        addSubview(magnet)
        hint.font=NSFont.systemFont(ofSize:10,weight:.medium);hint.textColor = .labelColor;hint.alignment = .center
        hint.wantsLayer=true;hint.layer?.backgroundColor=NSColor.windowBackgroundColor.withAlphaComponent(0.92).cgColor;hint.layer?.cornerRadius=4
        addSubview(hint)
        toolTip="Click to preview · Drag into another app · Right-click for options"
        layoutCard();setPinned(false)
    }
    required init?(coder: NSCoder) { fatalError() }
    func layoutCard() {
        paper.frame=paperRect; photo.frame=paper.bounds.insetBy(dx:6,dy:6)
        magnet.frame=NSRect(x:bounds.midX-32,y:bounds.maxY-64,width:64,height:64)
        hint.frame=NSRect(x:9,y:0,width:bounds.width-18,height:14)
        paper.layer?.transform=CATransform3DMakeRotation(tilt,0,0,1)
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas(); if let tracking { removeTrackingArea(tracking) }
        let t=NSTrackingArea(rect:bounds,options:[.mouseEnteredAndExited,.activeAlways,.inVisibleRect],owner:self,userInfo:nil); addTrackingArea(t); tracking=t
    }
    override func hitTest(_ point:NSPoint)->NSView? {
        guard !isHidden,frame.contains(point) else { return nil }
        let local=convert(point,from:superview)
        return magnet.frame.contains(local) ? magnet : self
    }
    @objc func pressMagnet() { keep?() }
    func setPinned(_ value:Bool) {
        pinned=value
        magnet.layer?.transform=CATransform3DMakeTranslation(0,value ? 0:6,0)
        magnet.alphaValue=1
        magnet.setAccessibilityLabel(value ? "Release pinned screenshot":"Keep screenshot pinned")
        magnet.toolTip=value ? "Click to release":"Click magnet to keep"
        if value {hint.stringValue="Pinned · click magnet to release";snap()}
    }
    func showRemaining(_ remaining:TimeInterval) {
        if !pinned {hint.stringValue="Click magnet to keep · \(Int(ceil(remaining)))s"}
    }
    override func mouseEntered(with event:NSEvent) {hoverChanged?(true);if !dragging {peek?(true)}}
    override func mouseExited(with event:NSEvent) {hoverChanged?(false);peek?(false)}
    override func mouseDown(with event:NSEvent) {down=convert(event.locationInWindow,from:nil);dragging=false}
    override func mouseUp(with event:NSEvent) {if !dragging {peek?(true)}}
    override func mouseDragged(with event: NSEvent) {
        guard !dragging else { return }
        let p=convert(event.locationInWindow,from:nil)
        guard hypot(p.x-down.x,p.y-down.y)>4 else { return }
        dragging=true; dragChanged?(true);peek?(false)
        let item=NSDraggingItem(pasteboardWriter:url as NSURL)
        item.setDraggingFrame(paperRect, contents:image)
        beginDraggingSession(with:[item],event:event,source:self)
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) { dragging=false;dragChanged?(false);hoverChanged?(window?.frame.contains(NSEvent.mouseLocation) ?? false) }
    override func menu(for event: NSEvent) -> NSMenu? {
        peek?(false)
        let menu=NSMenu();menu.delegate=self
        let pinItem=NSMenuItem(title:pinned ? "Release screenshot":"Keep screenshot pinned",action:#selector(pressMagnet),keyEquivalent:"");pinItem.target=self;menu.addItem(pinItem)
        for (title, action) in [("Open screenshot",#selector(openFile)),("Show in Finder",#selector(reveal)),("Copy image",#selector(copyImage)),("Remove magnet",#selector(removePin))] {
            let item=NSMenuItem(title:title,action:action,keyEquivalent:""); item.target=self; menu.addItem(item)
        }
        return menu
    }
    func menuWillOpen(_ menu:NSMenu) {menuChanged?(true)}
    func menuDidClose(_ menu:NSMenu) {menuChanged?(false);hoverChanged?(window?.frame.contains(NSEvent.mouseLocation) ?? false)}
    @objc func openFile() { NSWorkspace.shared.open(url) }
    @objc func reveal() { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    @objc func copyImage() { NSPasteboard.general.clearContents(); NSPasteboard.general.writeObjects([image]) }
    @objc func removePin() { dismiss?() }
    func snap() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let wobble=CAKeyframeAnimation(keyPath:"transform.rotation.z")
        wobble.values=[tilt-0.12,tilt+0.075,tilt-0.04,tilt+0.018,tilt]; wobble.keyTimes=[0,0.25,0.5,0.75,1]; wobble.duration=0.6; paper.layer?.add(wobble,forKey:"settle")
        let drop=CASpringAnimation(keyPath:"transform.translation.y"); drop.fromValue=26; drop.toValue=0; drop.mass=0.5; drop.stiffness=250; drop.damping=12; drop.duration=0.6; magnet.layer?.add(drop,forKey:"snap")
        let scale=CASpringAnimation(keyPath:"transform.scale"); scale.fromValue=1.55; scale.toValue=1; scale.damping=13; scale.stiffness=210; scale.duration=0.6; magnet.layer?.add(scale,forKey:"land")
    }
}

final class Pin {
    var life=PinLifetime()
    var leaving=false
    let id=UUID()
    let panel:NSPanel
    let view:PinView
    var screen:NSScreen
    init(url:URL,image:NSImage,kind:Int,screen:NSScreen) {
        self.screen=screen
        let width:CGFloat=186
        let ratio=image.size.height/max(image.size.width,1)
        let height=min(175,max(104,(width-40)*ratio+47))
        panel=NSPanel(contentRect:NSRect(x:0,y:0,width:width,height:height),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.isFloatingPanel=true; panel.level = .floating; panel.isOpaque=false; panel.backgroundColor = .clear; panel.hasShadow=false; panel.hidesOnDeactivate=false; panel.isReleasedWhenClosed=false
        panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle]
        view=PinView(image:image,url:url,kind:kind,frame:NSRect(x:0,y:0,width:width,height:height)); panel.contentView=view
        panel.sharingType = .readOnly // Keep magnets visible to screen-recording tools.
    }
}

final class MagnetApp: NSObject, NSApplicationDelegate {
    var welcome:NSWindow?
    var welcomeStatus:NSTextField?
    var welcomeFolder:NSTextField?
    var statusItem:NSStatusItem!
    var pins:[Pin]=[]
    var watcher:ScreenshotWatcher?
    var folder:URL
    var preview:NSPanel?
    var errorText:String?
    var ticker:Timer?
    var lastTick=ProcessInfo.processInfo.systemUptime
    var overflowPanels:[NSPanel]=[]
    var savedMenu=NSMenu()
    var savedItem:NSMenuItem!
    var paused=false
    var count=0
    var globalMonitor:Any?
    var menu:NSMenu!
    var folderItem:NSMenuItem!
    var healthItem:NSMenuItem!
    var pauseItem:NSMenuItem!
    init(folder: URL) { self.folder=folder; super.init() }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        statusItem=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        statusItem.button?.image=NSImage(systemSymbolName:"pin.fill",accessibilityDescription:"magnet screenshots")
        menu=NSMenu(); statusItem.menu=menu
        let title=NSMenuItem(title:"magnet · Screenshot magnets",action:nil,keyEquivalent:""); menu.addItem(title)
        healthItem=NSMenuItem(title:"Watching for screenshots",action:nil,keyEquivalent:""); menu.addItem(healthItem)
        folderItem=NSMenuItem(title:folder.path,action:#selector(showFolder),keyEquivalent:""); folderItem.target=self; menu.addItem(folderItem)
        menu.addItem(.separator())
        addMenu("Open magnet…",#selector(showWelcome),"o")
        addMenu("Try magnet animation",#selector(demo),"d")
        addMenu("Take screenshot…",#selector(capture),"s")
        pauseItem=addMenu("Pause capture watching",#selector(togglePause),"p")
        addMenu("Choose screenshot folder…",#selector(chooseFolder),"")
        addMenu("Clear magnets",#selector(clearPins),"k")
        savedItem=NSMenuItem(title:"Saved magnets (0)",action:nil,keyEquivalent:"");savedItem.submenu=savedMenu;menu.addItem(savedItem)
        let appMenu=NSMenu();let appRoot=NSMenuItem();appMenu.addItem(appRoot);let commands=NSMenu();appRoot.submenu=commands
        let quitItem=NSMenuItem(title:"Quit magnet",action:#selector(quit),keyEquivalent:"q");quitItem.target=self;commands.addItem(quitItem);NSApp.mainMenu=appMenu
        ticker=Timer(timeInterval:0.1,repeats:true){[weak self] _ in self?.tick()};RunLoop.main.add(ticker!,forMode:.common)
        menu.addItem(.separator()); addMenu("Quit magnet",#selector(quit),"q")
        startWatching()
        showWelcome()
        globalMonitor=NSEvent.addGlobalMonitorForEvents(matching:[.leftMouseDown,.rightMouseDown,.keyDown]) { [weak self] _ in self?.hidePreview() }
        NotificationCenter.default.addObserver(self,selector:#selector(screensChanged),name:NSApplication.didChangeScreenParametersNotification,object:nil)
        if CommandLine.arguments.contains("--demo") { DispatchQueue.main.asyncAfter(deadline:.now()+0.5) { self.demo() } }
    }
    @objc func showWelcome() {
        NSApp.setActivationPolicy(.regular)
        if welcome == nil {
            let w=NSWindow(contentRect:NSRect(x:0,y:0,width:510,height:355),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
            w.title="magnet"; w.isReleasedWhenClosed=false
            let content=NSView(frame:NSRect(x:0,y:0,width:510,height:355)); w.contentView=content
            func label(_ text:String,_ x:CGFloat,_ y:CGFloat,_ width:CGFloat,_ height:CGFloat,_ size:CGFloat,_ bold:Bool=false)->NSTextField {
                let l=NSTextField(wrappingLabelWithString:text);l.frame=NSRect(x:x,y:y,width:width,height:height);l.font=NSFont.systemFont(ofSize:size,weight:bold ? .semibold:.regular);content.addSubview(l);return l
            }
            let icon=NSImageView(frame:NSRect(x:25,y:256,width:78,height:78));icon.image=magnetImage(kind:0);content.addSubview(icon)
            _=label("magnet is ready.",110,285,350,33,27,true)
            _=label("Screenshots that stick.",111,259,350,25,16)
            _=label("Take a screenshot with ⌘⇧4. It fades after 5 seconds. Click the magnet to keep it; click again to release.",32,185,446,53,16)
            welcomeStatus=label("Watching for screenshots",32,152,446,23,13,true)
            welcomeFolder=label(folder.path,32,122,446,25,12)
            welcomeFolder?.textColor = .secondaryLabelColor
            func button(_ title:String,_ x:CGFloat,_ y:CGFloat,_ width:CGFloat,_ action:Selector) {
                let b=NSButton(title:title,target:self,action:action);b.frame=NSRect(x:x,y:y,width:width,height:35);b.bezelStyle = .rounded;content.addSubview(b)
            }
            button("Try magnet animation",28, 70,215,#selector(demo))
            button("Choose screenshot folder…",251, 70,231,#selector(chooseFolder))
            button("Keep running in menu bar",126,22,258,#selector(hideWelcome))
            welcome=w;w.center()
        }
        welcome?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    @objc func hideWelcome() {welcome?.orderOut(nil);NSApp.setActivationPolicy(.accessory)}
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool {showWelcome();return true}
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {false}
    @discardableResult func addMenu(_ title:String,_ action:Selector,_ key:String)->NSMenuItem { let i=NSMenuItem(title:title,action:action,keyEquivalent:key); i.target=self; menu.addItem(i); return i }
    func startWatching() {
        watcher?.stop()
        let w=ScreenshotWatcher(folder:folder)
        w.onImage={ [weak self] url,image in guard let self,!self.paused else {return}; self.addPin(url:url,image:NSImage(cgImage:image,size:NSSize(width:image.width,height:image.height))) }
        w.onError={ [weak self] message in guard let self else {return}; self.errorText=message; self.healthItem.title=message ?? (self.paused ? "Capture watching paused" : "Watching for screenshots"); self.welcomeStatus?.stringValue=self.healthItem.title }
        watcher=w; w.start(); folderItem.title=folder.path; welcomeFolder?.stringValue=folder.path
    }
    func addPin(url:URL,image:NSImage) {
        guard let screen=NSScreen.screens.first(where:{$0.frame.contains(NSEvent.mouseLocation)}) ?? NSScreen.main else {return}
        hidePreview()
        let pin=Pin(url:url,image:image,kind:count,screen:screen); count+=1
        pin.view.dismiss={ [weak self,weak pin] in if let pin {self?.remove(pin)} }
        pin.view.peek={ [weak self,weak pin] show in guard let self,let pin else{return}; if show {self.showPreview(pin)} else {self.hidePreview()} }
        pins.insert(pin,at:0)
        pin.view.keep={ [weak self,weak pin] in
            guard let self,let pin,!pin.leaving else{return}
            if pin.life.pinned {self.remove(pin)} else {pin.life.pinned=true;pin.view.setPinned(true);self.refreshSavedMenu();self.layout()}
        }
        pin.view.hoverChanged={ [weak pin] value in pin?.life.hovered=value }
        pin.view.dragChanged={ [weak pin] value in pin?.life.dragging=value }
        pin.view.menuChanged={ [weak pin] value in pin?.life.menuOpen=value }
        let target=targetFrame(pin)
        let start=NSRect(x:screen.visibleFrame.maxX-target.width-24,y:screen.visibleFrame.minY+32,width:target.width,height:target.height)
        pin.panel.setFrame(start,display:true); pin.panel.alphaValue=0; pin.panel.orderFrontRegardless()
        layout(except:pin)
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {pin.panel.setFrame(target,display:true);pin.panel.alphaValue=1;pin.life.arrived=true;return}
        NSAnimationContext.runAnimationGroup({ctx in ctx.duration=0.46;ctx.timingFunction=CAMediaTimingFunction(controlPoints:0.18,0.8,0.25,1);pin.panel.animator().setFrame(target,display:true);pin.panel.animator().alphaValue=1},completionHandler:{pin.life.arrived=true;pin.life.hovered=pin.panel.frame.contains(NSEvent.mouseLocation)})
    }
    func tick() {
        let now=ProcessInfo.processInfo.systemUptime
        let elapsed=min(0.5,max(0,now-lastTick));lastTick=now
        for pin in pins where !pin.leaving {
            if pin.life.advance(elapsed) {remove(pin)} else {pin.view.showRemaining(pin.life.remaining)}
        }
    }
    func visiblePins(on screen:NSScreen)->[Pin] {
        var space=screen.visibleFrame.height-75
        var result:[Pin]=[]
        for pin in pins where pin.screen==screen && !pin.leaving {
            if pin.panel.frame.height+7<=space {result.append(pin);space-=pin.panel.frame.height+7}
        }
        return result
    }
    func targetFrame(_ pin:Pin)->NSRect {
        let screen=pin.screen.visibleFrame
        var y=screen.maxY-15
        for p in visiblePins(on:pin.screen) {y-=p.panel.frame.height;if p===pin{return NSRect(x:screen.maxX-p.panel.frame.width-10,y:y,width:p.panel.frame.width,height:p.panel.frame.height)};y-=7}
        return pin.panel.frame
    }
    func layout(except:Pin?=nil) {
        for p in pins where p !== except && !p.leaving {
            if visiblePins(on:p.screen).contains(where:{$0===p}) {
                p.panel.orderFrontRegardless();let f=targetFrame(p)
                NSAnimationContext.runAnimationGroup{c in c.duration=0.22;p.panel.animator().setFrame(f,display:true)}
            } else {p.panel.orderOut(nil);p.life.hovered=false}
        }
        refreshOverflow()
    }
    func refreshSavedMenu() {
        savedMenu.removeAllItems()
        let kept=pins.filter{$0.life.pinned && !$0.leaving};savedItem.title="Saved magnets (\(kept.count))"
        for p in kept {
            let i=NSMenuItem(title:p.view.url.lastPathComponent,action:#selector(restorePin(_:)),keyEquivalent:"");i.target=self;i.representedObject=p.id.uuidString;savedMenu.addItem(i)
        }
    }
    func refreshOverflow() {
        overflowPanels.forEach{$0.orderOut(nil)};overflowPanels=[]
        for screen in NSScreen.screens {
            let visible=visiblePins(on:screen)
            let count=pins.filter{p in p.screen==screen && p.life.pinned && !p.leaving && !visible.contains(where:{$0===p})}.count
            guard count>0 else {continue}
            let frame=NSRect(x:screen.visibleFrame.maxX-182,y:screen.visibleFrame.minY+12,width:166,height:34)
            let p=NSPanel(contentRect:frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false);p.level = .floating;p.isReleasedWhenClosed=false;p.hidesOnDeactivate=false;p.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary];p.isOpaque=false;p.backgroundColor = .clear
            let b=NSButton(title:"+\(count) saved magnets",target:self,action:#selector(openSaved(_:)));b.frame=NSRect(origin:.zero,size:frame.size);b.bezelStyle = .rounded;p.contentView=b;p.orderFrontRegardless();overflowPanels.append(p)
        }
    }
    @objc func openSaved(_ sender:NSButton) {savedMenu.popUp(positioning:nil,at:NSPoint(x:0,y:sender.bounds.maxY),in:sender)}
    @objc func restorePin(_ sender:NSMenuItem) {
        guard let id=sender.representedObject as? String,let p=pins.first(where:{$0.id.uuidString==id}) else{return}
        pins.removeAll{$0===p};pins.insert(p,at:0);layout()
    }
    func remove(_ pin:Pin) {
        guard !pin.leaving else{return};pin.leaving=true;hidePreview()
        pin.view.magnet.layer?.transform=CATransform3DMakeTranslation(0,16,0)
        let finish={ [weak self] in pin.panel.orderOut(nil);self?.pins.removeAll{$0===pin};self?.refreshSavedMenu();self?.layout() }
        if !pin.panel.isVisible || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {finish();return}
        NSAnimationContext.runAnimationGroup({c in c.duration=0.28;pin.panel.animator().alphaValue=0;pin.panel.animator().setFrameOrigin(NSPoint(x:pin.screen.frame.maxX+5,y:pin.panel.frame.minY))},completionHandler:finish)
    }
    func showPreview(_ pin:Pin) {
        hidePreview()
        let safe=pin.screen.visibleFrame
        let maxW=min(580,safe.width-pin.panel.frame.width-65),maxH=min(620,safe.height-80)
        let size=pin.view.image.size
        let scale=min(maxW/max(size.width,1),maxH/max(size.height,1),1)
        let w=max(140,size.width*scale),h=max(90,size.height*scale)
        let frame=NSRect(x:max(safe.minX+10,pin.panel.frame.minX-w-22),y:max(safe.minY+12,min(safe.maxY-h-12,pin.panel.frame.midY-h/2)),width:w,height:h)
        let p=NSPanel(contentRect:frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        p.level = .floating; p.isReleasedWhenClosed=false;p.backgroundColor=NSColor(calibratedRed:0.98,green:0.97,blue:0.93,alpha:1);p.hasShadow=true;p.hidesOnDeactivate=false;p.ignoresMouseEvents=true
        p.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle]
        let iv=NSImageView(frame:NSRect(origin:.zero,size:frame.size));iv.image=pin.view.image;iv.imageScaling = .scaleProportionallyUpOrDown;p.contentView=iv;p.sharingType = .readOnly
        p.orderFrontRegardless();preview=p
    }
    func hidePreview() {preview?.orderOut(nil);preview=nil}
    @objc func screensChanged() {hidePreview();guard let screen=NSScreen.main else{return};for p in pins {p.screen=screen};layout()}
    @objc func clearPins() {hidePreview();pins.forEach{$0.panel.orderOut(nil)};pins.removeAll();overflowPanels.forEach{$0.orderOut(nil)};overflowPanels=[];refreshSavedMenu()}
    @objc func togglePause() {paused.toggle();pauseItem.title=paused ? "Resume capture watching":"Pause capture watching";healthItem.title=paused ? "Capture watching paused":"Watching for screenshots"}
    @objc func showFolder() {NSWorkspace.shared.open(folder)}
    @objc func chooseFolder() {
        NSApp.activate(ignoringOtherApps:true)
        let p=NSOpenPanel();p.title="Choose the folder where macOS saves your screenshots";p.canChooseDirectories=true;p.canChooseFiles=false;p.allowsMultipleSelection=false;p.directoryURL=folder
        if p.runModal() == .OK,let url=p.url {folder=url;UserDefaults.standard.set(url.path,forKey:"screenshotFolder");startWatching()}
    }
    @objc func capture() {
        // macOS owns screenshot capture and its normal permissions / save destination.
        let task=Process();task.executableURL=URL(fileURLWithPath:"/usr/sbin/screencapture");task.arguments=["-i","-U"];try? task.run()
    }
    @objc func demo() {
        let size=NSSize(width:720,height:460)
        let image=NSImage(size:size);image.lockFocus()
        NSColor(calibratedRed:0.98,green:0.97,blue:0.92,alpha:1).setFill();NSBezierPath(rect:NSRect(origin:.zero,size:size)).fill()
        let ink=NSColor(calibratedRed:0.12,green:0.2,blue:0.53,alpha:1)
        ("Something worth keeping." as NSString).draw(at:NSPoint(x:42,y:345),withAttributes:[.font:NSFont.systemFont(ofSize:38,weight:.semibold),.foregroundColor:ink])
        ("Your screenshot. A tiny magnet. Right where you need it." as NSString).draw(at:NSPoint(x:44,y:300),withAttributes:[.font:NSFont.systemFont(ofSize:19),.foregroundColor:NSColor.darkGray])
        let line=NSBezierPath();line.move(to:NSPoint(x:45,y:70));for p in [NSPoint(x:130,y:100),NSPoint(x:225,y:88),NSPoint(x:330,y:167),NSPoint(x:420,y:154),NSPoint(x:540,y:238),NSPoint(x:675,y:260)]{line.line(to:p)};ink.setStroke();line.lineWidth=5;line.stroke()
        ("FRIDGE  /  DEMO CAPTURE" as NSString).draw(at:NSPoint(x:44,y:26),withAttributes:[.font:NSFont.monospacedSystemFont(ofSize:12,weight:.medium),.foregroundColor:NSColor.gray])
        image.unlockFocus()
        let dir=FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask).first!.appendingPathComponent("com.local.fridge",isDirectory:true)
        do {try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);let url=dir.appendingPathComponent("magnet-demo-\(UUID().uuidString.prefix(8)).png");if let data=image.tiffRepresentation,let rep=NSBitmapImageRep(data:data),let png=rep.representation(using:.png,properties:[:]){try png.write(to:url);addPin(url:url,image:image)}}catch{healthItem.title="Could not create demo: \(error.localizedDescription)"}
    }
    @objc func quit(){NSApp.terminate(nil)}
    func applicationWillTerminate(_ notification:Notification) {ticker?.invalidate();watcher?.stop();if let globalMonitor{NSEvent.removeMonitor(globalMonitor)}}
}

if CommandLine.arguments.contains("--watch-test") {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("fridge-watch-\(UUID().uuidString)")
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: dir) }
    let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:8,pixelsHigh:8,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:32,bitsPerPixel:32)!
    let png = bitmap.representation(using:.png,properties:[:])!
    try png.write(to:dir.appendingPathComponent("Screenshot existing.png"))
    var received:[String]=[]
    let watcher=ScreenshotWatcher(folder:dir)
    watcher.onImage={url,_ in received.append(url.lastPathComponent)}
    watcher.start()
    DispatchQueue.main.asyncAfter(deadline:.now()+0.6) {
        try! Data([0,1]).write(to:dir.appendingPathComponent("Screenshot new.png"))
        try! png.write(to:dir.appendingPathComponent("ordinary-image.png"))
    }
    DispatchQueue.main.asyncAfter(deadline:.now()+1.2) {
        try! png.write(to:dir.appendingPathComponent("Screenshot new.png"))
    }
    RunLoop.main.run(until:Date().addingTimeInterval(3.5))
    watcher.stop()
    guard received == ["Screenshot new.png"] else {fputs("FAIL: received \(received)\n",stderr);exit(1)}
    print("PASS: existing files ignored; incomplete screenshot retried; ordinary image ignored; new screenshot delivered exactly once")
    exit(0)
}

if CommandLine.arguments.contains("--self-test") {
    let fm=FileManager.default
    let dir=fm.temporaryDirectory.appendingPathComponent("fridge-tests-\(UUID().uuidString)")
    try fm.createDirectory(at:dir,withIntermediateDirectories:true)
    defer {try? fm.removeItem(at:dir)}
    let screenshot=dir.appendingPathComponent("Screenshot 2026-10-07 at 10.00.00 AM.png")
    let other=dir.appendingPathComponent("holiday.png")
    try Data([1,2,3]).write(to:screenshot);try Data([1,2,3]).write(to:other)
    precondition(ScreenshotScan.isScreenshot(screenshot));precondition(!ScreenshotScan.isScreenshot(other))
    precondition(ScreenshotScan.identity(screenshot) != nil)
    precondition(ScreenshotScan.identity(dir) == nil)
    let first=ScreenshotScan.identity(screenshot)!
    precondition(Set([first]).contains(ScreenshotScan.identity(screenshot)!))
    var life=PinLifetime()
    precondition(!life.advance(10) && life.remaining==5)
    life.arrived=true;precondition(!life.advance(4) && life.remaining==1)
    life.hovered=true;precondition(!life.advance(10) && life.remaining==1)
    life.hovered=false;life.dragging=true;precondition(!life.advance(10) && life.remaining==1)
    life.dragging=false;life.menuOpen=true;precondition(!life.advance(10) && life.remaining==1)
    life.menuOpen=false;life.pinned=true;precondition(!life.advance(100) && life.remaining==1)
    life.pinned=false;precondition(life.advance(1));precondition(!life.advance(1))
    print("PASS: classification, deduplication, five-second expiry, hover/menu/drag pauses, persistent pin, single expiry")
    exit(0)
}
let prefs=UserDefaults.standard
let configured=prefs.string(forKey:"screenshotFolder") ?? UserDefaults(suiteName:"com.apple.screencapture")?.string(forKey:"location") ?? "~/Desktop"
let folder=URL(fileURLWithPath:(configured as NSString).expandingTildeInPath,isDirectory:true)
let app=NSApplication.shared
let delegate=MagnetApp(folder:folder)
app.delegate=delegate
withExtendedLifetime(delegate) { app.run() }
