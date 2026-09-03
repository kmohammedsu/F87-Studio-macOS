import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import ServiceManagement

enum MacFunctionAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case standard
    case brightnessDown
    case brightnessUp
    case missionControl
    case spotlight
    case dictation
    case focusControls
    case showDesktop
    case appWindows
    case controlCenter
    case notificationCenter
    case emojiAndSymbols
    case quickNote
    case previousTrack
    case playPause
    case nextTrack
    case mute
    case volumeDown
    case volumeUp
    case launchpad
    case keyboardLightDown
    case keyboardLightUp
    case screenshot
    case lockScreen
    case displaySleep
    case externalBrightnessDown
    case externalBrightnessUp
    case nothing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "Standard F-key"
        case .brightnessDown: return "Pointer Display Brightness Down"
        case .brightnessUp: return "Pointer Display Brightness Up"
        case .missionControl: return "Mission Control"
        case .spotlight: return "Spotlight"
        case .dictation: return "Dictation"
        case .focusControls: return "Focus / Control Center"
        case .showDesktop: return "Show Desktop"
        case .appWindows: return "Current App Windows"
        case .controlCenter: return "Control Center"
        case .notificationCenter: return "Notification Center"
        case .emojiAndSymbols: return "Emoji & Symbols"
        case .quickNote: return "Quick Note"
        case .previousTrack: return "Previous Track"
        case .playPause: return "Play / Pause"
        case .nextTrack: return "Next Track"
        case .mute: return "Mute"
        case .volumeDown: return "Volume Down"
        case .volumeUp: return "Volume Up"
        case .launchpad: return "Launchpad"
        case .keyboardLightDown: return "Keyboard Light Down"
        case .keyboardLightUp: return "Keyboard Light Up"
        case .screenshot: return "Screenshot Toolbar"
        case .lockScreen: return "Lock Screen"
        case .displaySleep: return "Sleep Displays"
        case .externalBrightnessDown: return "External Monitor Dimmer Down"
        case .externalBrightnessUp: return "External Monitor Dimmer Up"
        case .nothing: return "No Action"
        }
    }

    var symbol: String {
        switch self {
        case .standard: return "f.square"
        case .brightnessDown: return "sun.min.fill"
        case .brightnessUp: return "sun.max.fill"
        case .missionControl: return "rectangle.3.group.fill"
        case .spotlight: return "magnifyingglass"
        case .dictation: return "mic.fill"
        case .focusControls: return "moon.fill"
        case .showDesktop: return "macwindow.on.rectangle"
        case .appWindows: return "rectangle.stack.fill"
        case .controlCenter: return "switch.2"
        case .notificationCenter: return "bell.fill"
        case .emojiAndSymbols: return "face.smiling.fill"
        case .quickNote: return "note.text.badge.plus"
        case .previousTrack: return "backward.fill"
        case .playPause: return "playpause.fill"
        case .nextTrack: return "forward.fill"
        case .mute: return "speaker.slash.fill"
        case .volumeDown: return "speaker.wave.1.fill"
        case .volumeUp: return "speaker.wave.3.fill"
        case .launchpad: return "square.grid.3x3.fill"
        case .keyboardLightDown: return "lightbulb.min.fill"
        case .keyboardLightUp: return "lightbulb.max.fill"
        case .screenshot: return "camera.viewfinder"
        case .lockScreen: return "lock.fill"
        case .displaySleep: return "display.trianglebadge.exclamationmark"
        case .externalBrightnessDown: return "display.and.arrow.down"
        case .externalBrightnessUp: return "display.and.arrow.up"
        case .nothing: return "minus.circle"
        }
    }

    var isRepeatable: Bool {
        switch self {
        case .brightnessDown, .brightnessUp, .volumeDown, .volumeUp,
             .keyboardLightDown, .keyboardLightUp, .externalBrightnessDown,
             .externalBrightnessUp:
            return true
        default:
            return false
        }
    }
}

final class FunctionRowController: ObservableObject, @unchecked Sendable {
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledDefaultsKey)
            isEnabled ? start() : stop()
        }
    }
    @Published private(set) var assignments: [Int: MacFunctionAction]
    @Published private(set) var isRunning = false
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var listenAccessGranted = false
    @Published private(set) var postAccessGranted = false
    @Published private(set) var activationError: String?
    @Published private(set) var lastTriggered: String?
    @Published private(set) var externalDisplayBrightness = 1.0
    @Published private(set) var externalDisplayCount = 0
    @Published private(set) var externalDisplayStatus = "Checking for external displays…"
    @Published private(set) var pointerTargetsExternalDisplay = false
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginNeedsApproval = false
    @Published private(set) var launchAtLoginError: String?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var recoveryTimer: Timer?
    private var originalDisplayGamma: [CGDirectDisplayID: DisplayGamma] = [:]
    private var savedDisplayBrightness: [String: Double] = [:]
    private var legacyExternalBrightness = 1.0

    private static let enabledDefaultsKey = "macFunctionRowEnabled"
    private static let assignmentsDefaultsKey = "macFunctionRowAssignments"
    private static let defaultsVersionKey = "macFunctionRowDefaultsVersion"
    private static let externalBrightnessKey = "externalDisplaySoftwareBrightness"
    private static let perDisplayBrightnessKey = "externalDisplayBrightnessByDisplay"
    private static let functionKeyCodes: [Int: Int64] = [
        1: 0x7A, 2: 0x78, 3: 0x63, 4: 0x76, 5: 0x60, 6: 0x61,
        7: 0x62, 8: 0x64, 9: 0x65, 10: 0x6D, 11: 0x67, 12: 0x6F
    ]

    static let macBookDefaults: [Int: MacFunctionAction] = [
        1: .brightnessDown, 2: .brightnessUp, 3: .missionControl, 4: .spotlight,
        5: .dictation, 6: .focusControls, 7: .previousTrack, 8: .playPause,
        9: .nextTrack, 10: .mute, 11: .volumeDown, 12: .volumeUp
    ]

    static func functionKey(forVirtualKeyCode keyCode: Int64) -> Int? {
        functionKeyCodes.first(where: { $0.value == keyCode })?.key
    }

    init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: Self.enabledDefaultsKey) as? Bool ?? true
        legacyExternalBrightness = defaults.object(forKey: Self.externalBrightnessKey) as? Double ?? 1
        externalDisplayBrightness = legacyExternalBrightness
        if let saved = defaults.dictionary(forKey: Self.perDisplayBrightnessKey) {
            savedDisplayBrightness = saved.reduce(into: [:]) { values, entry in
                if let number = entry.value as? NSNumber { values[entry.key] = number.doubleValue }
            }
        }
        if let data = defaults.data(forKey: Self.assignmentsDefaultsKey),
           let decoded = try? JSONDecoder().decode([Int: MacFunctionAction].self, from: data) {
            assignments = Self.macBookDefaults.merging(decoded) { _, saved in saved }
            if defaults.integer(forKey: Self.defaultsVersionKey) < 2 {
                if decoded[5] == .standard { assignments[5] = .dictation }
                if decoded[6] == .standard { assignments[6] = .focusControls }
            }
        } else {
            assignments = Self.macBookDefaults
        }
        defaults.set(2, forKey: Self.defaultsVersionKey)
        persistAssignments()
        refreshPermissionStatus()
        refreshLaunchAtLoginStatus()
        refreshExternalDisplays()
        DispatchQueue.main.async { [weak self] in
            self?.start()
            self?.applySavedExternalDisplayBrightness()
        }
    }

    deinit { stop() }

    var hasRequiredAccess: Bool {
        isRunning
    }

    var bundleExists: Bool {
        FileManager.default.fileExists(atPath: Bundle.main.bundleURL.path)
    }

    var statusTitle: String {
        if !isEnabled { return "Off" }
        if isRunning { return "Active" }
        if accessibilityGranted { return "Restart needed" }
        return "Permission needed"
    }

    func assignment(for functionKey: Int) -> MacFunctionAction {
        assignments[functionKey] ?? .standard
    }

    func setAssignment(_ action: MacFunctionAction, for functionKey: Int) {
        guard (1...12).contains(functionKey) else { return }
        assignments[functionKey] = action
        persistAssignments()
    }

    func resetDefaults() {
        assignments = Self.macBookDefaults
        persistAssignments()
    }

    func testFunctionKey(_ functionKey: Int) {
        guard isRunning else { return }
        let action = assignment(for: functionKey)
        guard action != .standard && action != .nothing else { return }
        perform(action)
        lastTriggered = "F\(functionKey) · \(action.title) · Test"
    }

    func refreshExternalDisplays() {
        let displays = activeDisplays()
        let external = displays.filter { CGDisplayIsBuiltin($0) == 0 }
        externalDisplayCount = external.count
        originalDisplayGamma = originalDisplayGamma.filter { external.contains($0.key) }
        updatePointerDisplayStatus(from: displays)
    }

    func setExternalDisplayBrightness(_ value: Double) {
        let displays = activeDisplays()
        guard let display = displayUnderPointer(from: displays), CGDisplayIsBuiltin(display) == 0 else {
            refreshExternalDisplays()
            return
        }
        let brightness = min(1, max(0.2, value))
        externalDisplayBrightness = brightness
        legacyExternalBrightness = brightness
        savedDisplayBrightness[displayKey(display)] = brightness
        UserDefaults.standard.set(brightness, forKey: Self.externalBrightnessKey)
        UserDefaults.standard.set(savedDisplayBrightness, forKey: Self.perDisplayBrightnessKey)
        let succeeded = applyExternalDisplayBrightness(brightness, to: display)
        pointerTargetsExternalDisplay = true
        externalDisplayStatus = succeeded
            ? "Pointer target: \(displayName(display)) · \(Int(brightness * 100))%"
            : "\(displayName(display)) does not allow software dimming in its current display mode"
    }

    func adjustExternalDisplayBrightness(by delta: Double) {
        refreshExternalDisplays()
        guard pointerTargetsExternalDisplay else {
            externalDisplayStatus = "Move the pointer onto an external monitor, then try again"
            return
        }
        setExternalDisplayBrightness(externalDisplayBrightness + delta)
    }

    private func adjustBrightnessAtPointer(by delta: Double, nativeKeyType: Int) {
        let displays = activeDisplays()
        guard let display = displayUnderPointer(from: displays) else {
            postSystemKey(nativeKeyType)
            return
        }
        if CGDisplayIsBuiltin(display) != 0 {
            pointerTargetsExternalDisplay = false
            externalDisplayStatus = "Pointer target: \(displayName(display)) · native brightness"
            postSystemKey(nativeKeyType)
        } else {
            updatePointerDisplayStatus(from: displays)
            setExternalDisplayBrightness(externalDisplayBrightness + delta)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        refreshLaunchAtLoginStatus()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    @discardableResult
    func requestAccess() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        _ = CGRequestListenEventAccess()
        _ = CGRequestPostEventAccess()
        openAccessibilitySettings()
        ensureRecoveryTimer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.refreshAfterPermissionChange()
        }
        return accessibilityGranted
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func refreshAfterPermissionChange() {
        refreshPermissionStatus()
        refreshLaunchAtLoginStatus()
        if isEnabled { start() }
    }

    func relaunch() {
        guard bundleExists else {
            activationError = "This running copy was moved or deleted. Reinstall F87 Studio in Applications first."
            return
        }
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = ["-c", "sleep 0.8; exec /usr/bin/open -n \"$1\"", "f87-relaunch", Bundle.main.bundleURL.path]
        do {
            try helper.run()
            NSApplication.shared.terminate(nil)
        } catch {
            activationError = "Could not relaunch F87 Studio: \(error.localizedDescription)"
        }
    }

    private func refreshLaunchAtLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLoginEnabled = status == .enabled
        launchAtLoginNeedsApproval = status == .requiresApproval
    }

    private func refreshPermissionStatus() {
        accessibilityGranted = AXIsProcessTrusted()
        listenAccessGranted = CGPreflightListenEventAccess()
        postAccessGranted = CGPreflightPostEventAccess()
    }

    private func ensureRecoveryTimer() {
        guard recoveryTimer == nil else { return }
        recoveryTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.refreshPermissionStatus()
                self.refreshExternalDisplays()
                if self.isEnabled && !self.isRunning {
                    self.start()
                }
            }
        }
        if let recoveryTimer {
            RunLoop.main.add(recoveryTimer, forMode: .common)
        }
    }

    private func start() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.start() }
            return
        }
        guard isEnabled else { stop(); return }
        refreshPermissionStatus()
        ensureRecoveryTimer()
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            isRunning = CGEvent.tapIsEnabled(tap: eventTap)
            activationError = isRunning ? nil : "macOS disabled the function-key listener."
            return
        }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue) |
            CGEventMask(1 << CGEventType.keyUp.rawValue) |
            CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue) |
            CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: eventMask,
                                          callback: functionRowEventCallback,
                                          userInfo: pointer) else {
            isRunning = false
            if accessibilityGranted {
                activationError = "Permission is granted, but this process could not start the listener. Relaunch F87 Studio once."
            } else {
                activationError = "Allow F87 Studio in Accessibility, then return here. Activation is checked automatically."
            }
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        isRunning = CGEvent.tapIsEnabled(tap: tap)
        activationError = isRunning ? nil : "The function-key listener was created but macOS did not enable it."
    }

    private func stop() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.stop() }
            return
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
        isRunning = false
        activationError = nil
        recoveryTimer?.invalidate()
        recoveryTimer = nil
    }

    fileprivate func process(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                isRunning = CGEvent.tapIsEnabled(tap: eventTap)
                activationError = isRunning ? nil : "macOS disabled the function-key listener."
            }
            return Unmanaged.passUnretained(event)
        }
        guard isEnabled, isRunning,
              let functionKey = Self.functionKey(forVirtualKeyCode: event.getIntegerValueField(.keyboardEventKeycode)),
              let action = assignments[functionKey], action != .standard else {
            return Unmanaged.passUnretained(event)
        }

        let shortcutModifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
        guard event.flags.intersection(shortcutModifiers).isEmpty else {
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return nil }
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if !isRepeat || action.isRepeatable {
            perform(action)
            lastTriggered = "F\(functionKey) · \(action.title)"
        }
        return nil
    }

    private func perform(_ action: MacFunctionAction) {
        switch action {
        case .standard: return
        case .brightnessDown:
            adjustBrightnessAtPointer(by: -0.08, nativeKeyType: 3)
        case .brightnessUp:
            adjustBrightnessAtPointer(by: 0.08, nativeKeyType: 2)
        case .previousTrack: postSystemKey(18)
        case .playPause: postSystemKey(16)
        case .nextTrack: postSystemKey(17)
        case .mute: postSystemKey(7)
        case .volumeDown: postSystemKey(1)
        case .volumeUp: postSystemKey(0)
        case .launchpad: postSystemKey(13)
        case .keyboardLightDown: postSystemKey(22)
        case .keyboardLightUp: postSystemKey(21)
        case .missionControl: postDockAction("com.apple.expose.awake")
        case .spotlight: postShortcut(keyCode: 0x31, flags: .maskCommand)
        case .dictation: startDictation()
        case .focusControls, .controlCenter: postGlobeShortcut(keyCode: 0x08)
        case .showDesktop: postDockAction("com.apple.showdesktop.awake")
        case .appWindows: postDockAction("com.apple.expose.front.awake")
        case .notificationCenter: postGlobeShortcut(keyCode: 0x2D)
        case .emojiAndSymbols: postShortcut(keyCode: 0x31, flags: [.maskCommand, .maskControl])
        case .quickNote: postGlobeShortcut(keyCode: 0x0C)
        case .screenshot: postShortcut(keyCode: 0x17, flags: [.maskCommand, .maskShift])
        case .lockScreen: postShortcut(keyCode: 0x0C, flags: [.maskCommand, .maskControl])
        case .displaySleep: sleepDisplays()
        case .externalBrightnessDown: adjustExternalDisplayBrightness(by: -0.08)
        case .externalBrightnessUp: adjustExternalDisplayBrightness(by: 0.08)
        case .nothing: return
        }
    }

    private func postDockAction(_ name: String) {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name(name), object: nil, userInfo: nil, deliverImmediately: true
        )
    }

    private func postGlobeShortcut(keyCode: CGKeyCode) {
        postShortcut(keyCode: keyCode, flags: .maskSecondaryFn)
    }

    private func startDictation() {
        postFunctionModifierPress()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.postFunctionModifierPress()
        }
    }

    private func postFunctionModifierPress() {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0x3F, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 0x3F, keyDown: false) else { return }
        down.flags = .maskSecondaryFn
        up.flags = []
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func sleepDisplays() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try? process.run()
    }

    private func activeDisplays() -> [CGDirectDisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(UInt32(ids.count), &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    private func displayUnderPointer(from displays: [CGDirectDisplayID]) -> CGDirectDisplayID? {
        let location = CGEvent(source: nil)?.location ?? NSEvent.mouseLocation
        return displays.first(where: { CGDisplayBounds($0).contains(location) })
            ?? displays.first(where: { $0 == CGMainDisplayID() })
    }

    private func updatePointerDisplayStatus(from displays: [CGDirectDisplayID]) {
        guard let display = displayUnderPointer(from: displays) else {
            pointerTargetsExternalDisplay = false
            externalDisplayStatus = "No active display detected"
            return
        }
        if CGDisplayIsBuiltin(display) != 0 {
            pointerTargetsExternalDisplay = false
            externalDisplayStatus = "Pointer target: \(displayName(display)) · native brightness"
        } else {
            pointerTargetsExternalDisplay = true
            externalDisplayBrightness = brightness(for: display)
            externalDisplayStatus = "Pointer target: \(displayName(display)) · \(Int(externalDisplayBrightness * 100))%"
        }
    }

    private func displayName(_ display: CGDirectDisplayID) -> String {
        if let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display
        }) {
            return screen.localizedName
        }
        return CGDisplayIsBuiltin(display) != 0 ? "MacBook display" : "External monitor"
    }

    private func displayKey(_ display: CGDirectDisplayID) -> String {
        let vendor = CGDisplayVendorNumber(display)
        let model = CGDisplayModelNumber(display)
        let serial = CGDisplaySerialNumber(display)
        return serial == 0 ? "\(vendor):\(model):display-\(display)" : "\(vendor):\(model):\(serial)"
    }

    private func brightness(for display: CGDirectDisplayID) -> Double {
        savedDisplayBrightness[displayKey(display)] ?? legacyExternalBrightness
    }

    private func applySavedExternalDisplayBrightness() {
        let displays = activeDisplays().filter { CGDisplayIsBuiltin($0) == 0 }
        for display in displays {
            _ = applyExternalDisplayBrightness(brightness(for: display), to: display)
        }
        refreshExternalDisplays()
    }

    @discardableResult
    private func applyExternalDisplayBrightness(_ brightness: Double, to display: CGDirectDisplayID) -> Bool {
        if originalDisplayGamma[display] == nil {
            originalDisplayGamma[display] = DisplayGamma.capture(display)
        }
        let result: CGError
        if brightness >= 0.995, let original = originalDisplayGamma[display] {
            result = original.apply(to: display)
            originalDisplayGamma.removeValue(forKey: display)
        } else {
            let maximum = Float(brightness)
            result = CGSetDisplayTransferByFormula(
                display, 0, maximum, 1, 0, maximum, 1, 0, maximum, 1
            )
        }
        return result == .success
    }

    private func postSystemKey(_ keyType: Int) {
        for state in [0x0A, 0x0B] {
            let data = (keyType << 16) | (state << 8)
            let event = NSEvent.otherEvent(with: .systemDefined, location: .zero,
                                           modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                           windowNumber: 0, context: nil, subtype: 8,
                                           data1: data, data2: -1)
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }

    private func postShortcut(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else { return }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func persistAssignments() {
        if let data = try? JSONEncoder().encode(assignments) {
            UserDefaults.standard.set(data, forKey: Self.assignmentsDefaultsKey)
        }
    }
}

private struct DisplayGamma {
    let redMin: Float
    let redMax: Float
    let redGamma: Float
    let greenMin: Float
    let greenMax: Float
    let greenGamma: Float
    let blueMin: Float
    let blueMax: Float
    let blueGamma: Float

    static func capture(_ display: CGDirectDisplayID) -> DisplayGamma? {
        var redMin: Float = 0
        var redMax: Float = 1
        var redGamma: Float = 1
        var greenMin: Float = 0
        var greenMax: Float = 1
        var greenGamma: Float = 1
        var blueMin: Float = 0
        var blueMax: Float = 1
        var blueGamma: Float = 1
        let result = CGGetDisplayTransferByFormula(
            display, &redMin, &redMax, &redGamma,
            &greenMin, &greenMax, &greenGamma,
            &blueMin, &blueMax, &blueGamma
        )
        guard result == .success else { return nil }
        return DisplayGamma(redMin: redMin, redMax: redMax, redGamma: redGamma,
                            greenMin: greenMin, greenMax: greenMax, greenGamma: greenGamma,
                            blueMin: blueMin, blueMax: blueMax, blueGamma: blueGamma)
    }

    func apply(to display: CGDirectDisplayID) -> CGError {
        CGSetDisplayTransferByFormula(
            display, redMin, redMax, redGamma,
            greenMin, greenMax, greenGamma,
            blueMin, blueMax, blueGamma
        )
    }
}

private let functionRowEventCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<FunctionRowController>.fromOpaque(userInfo).takeUnretainedValue()
    return controller.process(type: type, event: event)
}
