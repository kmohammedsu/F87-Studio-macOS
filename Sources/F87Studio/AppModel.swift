import AppKit
import AVFoundation
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    let profileStore = ProfileStore()
    let functionRowController = FunctionRowController()
    @Published var connectionState: ConnectionState = .searching
    @Published var selectedEffect = 3
    @Published var brightness = 4
    @Published var speed = 2
    @Published var colorful = true
    @Published var selectedColor = RGBColor.accent
    @Published var perKeyColors: [Int: RGBColor] = [:]
    @Published var perKeyTool: PerKeyTool = .paint
    @Published var selectedLEDs: Set<Int> = []
    @Published var gradientEndColor = RGBColor(red: 100, green: 105, blue: 255)
    @Published var gradientDirection: GradientDirection = .horizontal
    @Published var sleepMinutes = 10
    @Published var debounceMilliseconds = 3
    @Published var toast: String?
    @Published var activityLog: [String] = []
    @Published var availableEffectIDs = F87Protocol.supportedEffectIDs
    @Published var minimumBrightness = 0
    @Published var supportsTimingSettings = true
    @Published var supportsFactoryReset = false
    @Published var supportsMusicReactive = false
    @Published private(set) var isMusicReactive = false
    @Published private(set) var audioLevels = [Double](repeating: 0, count: 11)
    @Published var musicSensitivity = 1.35
    @Published var musicColor = RGBColor(red: 65, green: 210, blue: 255)
    @Published private(set) var appliedProfile = F87Profile(
        effect: 3, brightness: 4, speed: 2, colorful: true,
        color: .accent, perKey: [:]
    )
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published var automaticProfilesEnabled = false {
        didSet { UserDefaults.standard.set(automaticProfilesEnabled, forKey: "automaticProfilesEnabled") }
    }
    @Published private(set) var activeApplicationName: String?

    private var undoStack: [[Int: RGBColor]] = []
    private var redoStack: [[Int: RGBColor]] = []
    private var strokeBaseline: [Int: RGBColor]?
    private var strokeLEDs: Set<Int> = []
    private var reconnectTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var lastAutomaticProfileID: UUID?
    private var lastExternalBundleIdentifier: String?
    private var lastExternalApplicationName: String?
    private let musicVisualizer = MusicVisualizer()
    private var audioFramePending = false
    private var scanInProgress = false

    private nonisolated let service = KeyboardService()
    private nonisolated let queue = DispatchQueue(label: "studio.f87.device", qos: .userInitiated)

    var selectedEffectInfo: LightingEffect {
        LightingEffect.all.first(where: { $0.id == selectedEffect }) ?? LightingEffect.all[0]
    }

    var eraseMode: Bool {
        get { perKeyTool == .erase }
        set { perKeyTool = newValue ? .erase : .paint }
    }

    var currentProfile: F87Profile {
        F87Profile(effect: selectedEffect, brightness: brightness, speed: speed,
                   colorful: colorful, color: selectedColor, perKey: perKeyColors)
    }

    var hasUnappliedChanges: Bool { currentProfile != appliedProfile }
    var hasUnappliedPerKeyChanges: Bool { perKeyColors != appliedProfile.perKey }
    var hasUnappliedLightingChanges: Bool {
        selectedEffect != appliedProfile.effect || brightness != appliedProfile.brightness ||
            speed != appliedProfile.speed || colorful != appliedProfile.colorful ||
            selectedColor != appliedProfile.color
    }

    init() {
        automaticProfilesEnabled = UserDefaults.standard.bool(forKey: "automaticProfilesEnabled")
        try? Data("F87 Studio diagnostics — \(Date.now.formatted())\n".utf8)
            .write(to: diagnosticURL, options: .atomic)
        installLifecycleMonitoring()
        scan()
    }

    func scan() {
        guard !scanInProgress else {
            log("A keyboard scan is already in progress.")
            return
        }
        if case .busy = connectionState { return }
        if !KeyboardService.hasInputMonitoringAccess {
            _ = KeyboardService.requestInputMonitoringAccess()
            log("Input Monitoring is not reported as granted; attempting the control interface directly.")
        }
        connectionState = .searching
        scanInProgress = true
        log("Scanning for AULA F87 control interfaces…")
        // HIDAPI's macOS enumerator owns an IOHIDManager scheduled on the run
        // loop where it is first initialized. GCD serial queues may hop between
        // worker threads, so enumeration must remain on the persistent main run loop.
        let candidates = HIDDiscovery.candidates()
        queue.async { [weak self] in
            do {
                let name = try self?.service.connect(candidates: candidates) ?? "AULA F87"
                let snapshot = self?.service.currentSnapshot
                let effectIDs = self?.service.supportedEffectIDs ?? F87Protocol.supportedEffectIDs
                let minBrightness = self?.service.minimumBrightness ?? 0
                let timingSupported = self?.service.supportsTimingSettings ?? false
                let resetSupported = self?.service.supportsFactoryReset ?? false
                let musicSupported = self?.service.supportsAudioStreaming ?? false
                DispatchQueue.main.async {
                    self?.scanInProgress = false
                    self?.connectionState = .connected(name)
                    self?.availableEffectIDs = effectIDs
                    self?.minimumBrightness = minBrightness
                    self?.supportsTimingSettings = timingSupported
                    self?.supportsFactoryReset = resetSupported
                    self?.supportsMusicReactive = musicSupported
                    if let snapshot { self?.apply(snapshot: snapshot) }
                    if let self, !self.availableEffectIDs.contains(self.selectedEffect) {
                        self.selectedEffect = self.availableEffectIDs.contains(3) ? 3 : 0
                    }
                    if let self, self.brightness < self.minimumBrightness {
                        self.brightness = self.minimumBrightness
                    }
                    if let self {
                        self.appliedProfile.effect = self.selectedEffect
                        self.appliedProfile.brightness = self.brightness
                        self.appliedProfile.speed = self.speed
                        self.appliedProfile.colorful = self.colorful
                        self.appliedProfile.color = self.selectedColor
                    }
                    self?.log("Connected to \(name).")
                }
            } catch {
                DispatchQueue.main.async {
                    self?.scanInProgress = false
                    self?.connectionState = .disconnected(error.localizedDescription)
                    self?.log(error.localizedDescription)
                }
            }
        }
    }

    func applyEffect() {
        let draft = currentProfile
        run(action: "Applying lighting…", success: "Lighting saved to the keyboard",
            successUpdate: { [weak self] in
                guard let self else { return }
                self.appliedProfile.effect = draft.effect
                self.appliedProfile.brightness = draft.brightness
                self.appliedProfile.speed = draft.speed
                self.appliedProfile.colorful = draft.colorful
                self.appliedProfile.color = draft.color
            }) { [self] in
            let forcedColorful = !selectedEffectInfo.supportsColor && selectedEffect != 0
            try service.applyEffect(effect: selectedEffect, brightness: brightness, speed: speed,
                                    colorful: forcedColorful || colorful, color: selectedColor)
        }
    }

    func paint(key: KeyboardKey) {
        if NSEvent.modifierFlags.contains(.shift) {
            toggleSelection(key.led)
            return
        }
        performPerKeyEdit {
            applyCurrentTool(to: key)
        }
    }

    func beginPaintStroke() {
        if strokeBaseline == nil { strokeBaseline = perKeyColors }
        strokeLEDs.removeAll()
    }

    func continuePaintStroke(key: KeyboardKey) {
        guard strokeLEDs.insert(key.led).inserted else { return }
        if NSEvent.modifierFlags.contains(.shift) {
            toggleSelection(key.led)
            return
        }
        applyCurrentTool(to: key)
    }

    func endPaintStroke() {
        guard let baseline = strokeBaseline else { return }
        strokeBaseline = nil
        strokeLEDs.removeAll()
        commitHistory(from: baseline)
    }

    func fillAll() {
        performPerKeyEdit {
            let targets = selectedLEDs.isEmpty ? Set(F87Layout.allKeys.map(\.led)) : selectedLEDs
            for led in targets { perKeyColors[led] = selectedColor }
        }
    }

    func clearAll() {
        performPerKeyEdit {
            if selectedLEDs.isEmpty { perKeyColors.removeAll() }
            else { for led in selectedLEDs { perKeyColors.removeValue(forKey: led) } }
        }
    }

    func fillSpectrum() {
        let keys = F87Layout.allKeys
        performPerKeyEdit {
            perKeyColors = Dictionary(uniqueKeysWithValues: keys.enumerated().map { index, key in
                let hue = Double(index) / Double(max(1, keys.count))
                return (key.led, RGBColor(color: Color(hue: hue, saturation: 0.92, brightness: 1.0)))
            })
        }
    }

    func fillRows() {
        let hues = [0.56, 0.48, 0.38, 0.18, 0.04, 0.84]
        var result: [Int: RGBColor] = [:]
        for (rowIndex, row) in F87Layout.rows.enumerated() {
            let color = RGBColor(color: Color(hue: hues[min(rowIndex, hues.count - 1)],
                                              saturation: 0.88, brightness: 1.0))
            for item in row {
                if case .key(let key) = item { result[key.led] = color }
            }
        }
        performPerKeyEdit { perKeyColors = result }
    }

    func fillGamingKeys() {
        let gamingLEDs: Set<Int> = [14, 9, 15, 21, 89, 94, 95, 101]
        let accent = RGBColor(red: 255, green: 74, blue: 74)
        let background = RGBColor(red: 25, green: 80, blue: 120)
        performPerKeyEdit {
            perKeyColors = Dictionary(uniqueKeysWithValues: F87Layout.allKeys.map {
                ($0.led, gamingLEDs.contains($0.led) ? accent : background)
            })
        }
    }

    func undoPerKey() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(perKeyColors)
        perKeyColors = previous
        updateHistoryState()
    }

    func redoPerKey() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(perKeyColors)
        perKeyColors = next
        updateHistoryState()
    }

    func toggleSelection(_ led: Int) {
        if selectedLEDs.contains(led) { selectedLEDs.remove(led) }
        else { selectedLEDs.insert(led) }
    }

    func clearSelection() { selectedLEDs.removeAll() }
    func selectAllKeys() { selectedLEDs = Set(F87Layout.allKeys.map(\.led)) }

    func selectGroup(_ group: String) {
        let labels: Set<String>
        switch group {
        case "wasd": labels = ["W", "A", "S", "D"]
        case "arrows": labels = ["↑", "↓", "←", "→"]
        case "function": labels = Set((1...12).map { "F\($0)" })
        case "numbers": labels = Set((0...9).map(String.init))
        case "modifiers": labels = ["Ctrl", "⌘", "Alt", "Fn", "App", "Shift"]
        default: labels = []
        }
        selectedLEDs = Set(F87Layout.allKeys.filter { labels.contains($0.label) }.map(\.led))
        perKeyTool = .select
    }

    func applyGradient() {
        let targets = selectedLEDs.isEmpty ? Set(F87Layout.allKeys.map(\.led)) : selectedLEDs
        let positions = keyPositions()
        performPerKeyEdit {
            for led in targets {
                guard let point = positions[led] else { continue }
                let amount: Double
                switch gradientDirection {
                case .horizontal: amount = point.x
                case .vertical: amount = point.y
                case .radial:
                    amount = min(1, hypot(point.x - 0.5, point.y - 0.5) * 1.8)
                }
                perKeyColors[led] = interpolate(selectedColor, gradientEndColor, amount)
            }
        }
    }

    func revertDraft() {
        let before = perKeyColors
        apply(profile: appliedProfile)
        if before != perKeyColors {
            undoStack.append(before)
            redoStack.removeAll()
            updateHistoryState()
        }
        showToast("Unapplied changes reverted")
    }

    func applyPerKey() {
        let draft = perKeyColors
        run(action: "Saving per-key colors…", success: "Per-key colors saved to the keyboard",
            successUpdate: { [weak self] in self?.appliedProfile.perKey = draft }) { [self] in
            try service.applyPerKey(perKeyColors)
        }
    }

    func saveDraftToLibrary(name: String) {
        let stored = profileStore.add(name: name, profile: currentProfile)
        showToast("Saved \(stored.name)")
    }

    func updateLibraryProfile(_ id: UUID) {
        profileStore.update(id, profile: currentProfile)
        showToast("Profile updated")
    }

    func loadLibraryProfile(_ id: UUID) {
        guard let stored = profileStore.profiles.first(where: { $0.id == id }) else { return }
        apply(profile: stored.profile)
        showToast("Loaded \(stored.name) — apply when ready")
    }

    func applyLibraryProfile(_ id: UUID, automatic: Bool = false) {
        guard let stored = profileStore.profiles.first(where: { $0.id == id }) else { return }
        apply(profile: stored.profile)
        let draft = currentProfile
        run(action: automatic ? "Applying \(stored.name) for \(stored.assignedApplicationName ?? "app")…" : "Applying \(stored.name)…",
            success: "\(stored.name) applied",
            successUpdate: { [weak self] in self?.appliedProfile = draft }) { [self] in
            if draft.perKey.isEmpty {
                let info = LightingEffect.all.first(where: { $0.id == draft.effect })
                let forcedColorful = info?.supportsColor == false && draft.effect != 0
                try service.applyEffect(effect: draft.effect, brightness: draft.brightness,
                                        speed: draft.speed, colorful: forcedColorful || draft.colorful,
                                        color: draft.color)
            } else {
                try service.applyPerKey(draft.perKey)
            }
        }
    }

    func assignProfileToFrontmostApp(_ id: UUID) {
        guard let bundleIdentifier = lastExternalBundleIdentifier else {
            showToast("Open the target app once, then assign again")
            return
        }
        let name = lastExternalApplicationName ?? bundleIdentifier
        profileStore.assign(id, bundleIdentifier: bundleIdentifier, applicationName: name)
        showToast("Assigned to \(name)")
    }

    func removeAppAssignment(_ id: UUID) {
        profileStore.assign(id, bundleIdentifier: nil, applicationName: nil)
        showToast("Automatic assignment removed")
    }

    func startMusicMode() {
        guard connectionState.isConnected, supportsMusicReactive else {
            showToast("Music mode requires the verified 2.4 GHz control connection")
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startMusicEngine()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.startMusicEngine() }
                    else { self?.showToast("Microphone access is required for Music mode") }
                }
            }
        default:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
            showToast("Enable F87 Studio under Privacy & Security → Microphone")
        }
    }

    func stopMusicMode() {
        musicVisualizer.stop()
        isMusicReactive = false
        audioLevels = [Double](repeating: 0, count: 11)
        queue.async { [service] in try? service.stopAudioStream() }
        showToast("Music mode stopped")
    }

    func applySleep() {
        run(action: "Updating sleep timer…", success: "Sleep timer updated") { [self] in
            try service.applySleep(minutes: sleepMinutes)
        }
    }

    func applyDebounce() {
        run(action: "Updating debounce…", success: "Debounce updated") { [self] in
            try service.applyDebounce(milliseconds: debounceMilliseconds)
        }
    }

    func factoryReset() {
        run(action: "Restoring factory lighting settings…", success: "Factory lighting settings restored",
            successUpdate: { [weak self] in
                self?.selectedEffect = 0
                self?.brightness = 4
                self?.speed = 4
                self?.colorful = true
                self?.sleepMinutes = 5
                self?.debounceMilliseconds = 2
                self?.perKeyColors.removeAll()
                if let self { self.appliedProfile = self.currentProfile }
            }) { [self] in
                try service.factoryReset()
            }
    }

    func saveProfile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "My F87 Profile.f87profile"
        panel.allowedContentTypes = [profileContentType]
        panel.isExtensionHidden = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let profile = F87Profile(effect: selectedEffect, brightness: brightness, speed: speed,
                                     colorful: colorful, color: selectedColor, perKey: perKeyColors)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(profile).write(to: url, options: .atomic)
            showToast("Profile saved")
        } catch { showError(error) }
    }

    func loadProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [profileContentType, .json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let profile = try JSONDecoder().decode(F87Profile.self, from: Data(contentsOf: url))
            apply(profile: profile)
            showToast("Profile loaded — use Apply to send it")
        } catch { showError(error) }
    }

    func openInputMonitoring() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func requestInputMonitoring() {
        if KeyboardService.requestInputMonitoringAccess() {
            scan()
        } else {
            openInputMonitoring()
            let message = F87Error.permissionDenied.localizedDescription
            connectionState = .disconnected(message)
            log(message)
        }
    }

    func copyCurrentError() {
        let error = connectionState.detail ?? activityLog.last ?? "No current error."
        copyToPasteboard(error)
        showToast("Error copied")
    }

    func copyDiagnosticReport() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let error = connectionState.detail ?? "None"
        let report = """
        F87 Studio diagnostic report
        Generated: \(Date.now.formatted(date: .abbreviated, time: .standard))
        App: \(version) (\(build))
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Input Monitoring reported: \(KeyboardService.hasInputMonitoringAccess ? "granted" : "not granted")
        Connection status: \(connectionState.title)
        Current error: \(error)

        Recent activity:
        \(activityLog.suffix(40).joined(separator: "\n"))
        """
        copyToPasteboard(report)
        showToast("Diagnostic report copied")
    }

    private func run(action: String, success: String,
                     successUpdate: @escaping @MainActor () -> Void = {},
                     work: @escaping () throws -> Void) {
        guard connectionState.isConnected else {
            if case .busy = connectionState { return }
            scan()
            return
        }
        connectionState = .busy(action)
        log(action)
        queue.async { [weak self] in
            do {
                try work()
                DispatchQueue.main.async {
                    successUpdate()
                    let name = self?.service.connectedName ?? "AULA F87"
                    self?.connectionState = .connected(name)
                    self?.log(success)
                    self?.showToast(success)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.connectionState = .failed(error.localizedDescription)
                    self?.log(error.localizedDescription)
                }
            }
        }
    }

    private func log(_ message: String) {
        let line = "\(Date.now.formatted(date: .omitted, time: .standard))  \(message)"
        activityLog.append(line)
        if activityLog.count > 80 { activityLog.removeFirst(activityLog.count - 80) }
        if let handle = try? FileHandle(forWritingTo: diagnosticURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data((line + "\n").utf8))
        }
    }

    private var diagnosticURL: URL { URL(fileURLWithPath: "/tmp/F87Studio.log") }
    private var profileContentType: UTType {
        UTType(filenameExtension: "f87profile", conformingTo: .json) ?? .json
    }

    private func apply(snapshot: KeyboardSnapshot) {
        if availableEffectIDs.contains(snapshot.effect) { selectedEffect = snapshot.effect }
        if let value = snapshot.brightness, (minimumBrightness...4).contains(value) { brightness = value }
        if let value = snapshot.speed, (0...4).contains(value) { speed = value }
        if let value = snapshot.colorful { colorful = value }
        if let value = snapshot.sleepMinutes, (0...60).contains(value) { sleepMinutes = value }
        if let value = snapshot.debounceMilliseconds, (1...5).contains(value) { debounceMilliseconds = value }
    }

    private func apply(profile: F87Profile) {
        selectedEffect = availableEffectIDs.contains(profile.effect) ? profile.effect : (availableEffectIDs.contains(3) ? 3 : 0)
        brightness = max(minimumBrightness, min(4, profile.brightness))
        speed = max(0, min(4, profile.speed))
        colorful = profile.colorful
        selectedColor = profile.color
        let validLEDs = Set(F87Layout.allKeys.map(\.led))
        perKeyColors = profile.perKey.filter { validLEDs.contains($0.key) }
    }

    private func applyCurrentTool(to key: KeyboardKey) {
        let targets: Set<Int> = selectedLEDs.contains(key.led) && !selectedLEDs.isEmpty
            ? selectedLEDs : Set([key.led])
        switch perKeyTool {
        case .paint:
            for led in targets { perKeyColors[led] = selectedColor }
        case .erase:
            for led in targets { perKeyColors.removeValue(forKey: led) }
        case .select:
            toggleSelection(key.led)
        case .eyedropper:
            if let sampled = perKeyColors[key.led] {
                selectedColor = sampled
                perKeyTool = .paint
                showToast("Picked \(sampled.hex)")
            }
        }
    }

    private func performPerKeyEdit(_ edit: () -> Void) {
        let before = perKeyColors
        edit()
        commitHistory(from: before)
    }

    private func commitHistory(from before: [Int: RGBColor]) {
        guard before != perKeyColors else { return }
        undoStack.append(before)
        if undoStack.count > 60 { undoStack.removeFirst(undoStack.count - 60) }
        redoStack.removeAll()
        updateHistoryState()
    }

    private func updateHistoryState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    private func keyPositions() -> [Int: (x: Double, y: Double)] {
        var result: [Int: (x: Double, y: Double)] = [:]
        for (rowIndex, row) in F87Layout.rows.enumerated() {
            var x = 0.0
            let total = row.reduce(0.0) { partial, item in
                switch item {
                case .gap(let width): return partial + width
                case .key(let key): return partial + key.width
                }
            }
            for item in row {
                switch item {
                case .gap(let width): x += width
                case .key(let key):
                    result[key.led] = ((x + key.width / 2) / max(1, total), Double(rowIndex) / 5.0)
                    x += key.width
                }
            }
        }
        return result
    }

    private func interpolate(_ start: RGBColor, _ end: RGBColor, _ amount: Double) -> RGBColor {
        let t = max(0, min(1, amount))
        func channel(_ a: UInt8, _ b: UInt8) -> UInt8 {
            UInt8(max(0, min(255, Int((Double(a) + (Double(b) - Double(a)) * t).rounded()))))
        }
        return RGBColor(red: channel(start.red, end.red), green: channel(start.green, end.green),
                        blue: channel(start.blue, end.blue))
    }

    private func startMusicEngine() {
        do {
            try musicVisualizer.start { [weak self] levels in
                DispatchQueue.main.async { self?.receiveAudioLevels(levels) }
            }
            isMusicReactive = true
            log("Music-reactive RGB started (microphone spectrum, 11 bands).")
            showToast("Music mode started")
        } catch {
            showError(error)
        }
    }

    private func receiveAudioLevels(_ levels: [Double]) {
        guard isMusicReactive else { return }
        audioLevels = levels
        guard !audioFramePending else { return }
        let positions = keyPositions()
        var colors: [Int: RGBColor] = [:]
        for key in F87Layout.allKeys {
            guard let point = positions[key.led] else { continue }
            let band = max(0, min(10, Int((point.x * 10).rounded())))
            let energy = min(1, levels[band] * musicSensitivity)
            let threshold = 0.08 + (1 - point.y) * 0.78
            guard energy >= threshold else { continue }
            let intensity = max(0.24, min(1, (energy - threshold) / max(0.12, 1 - threshold) + 0.30))
            colors[key.led] = RGBColor(
                red: UInt8(Double(musicColor.red) * intensity),
                green: UInt8(Double(musicColor.green) * intensity),
                blue: UInt8(Double(musicColor.blue) * intensity)
            )
        }
        audioFramePending = true
        queue.async { [weak self, service] in
            do {
                try service.streamAudio(colors)
                DispatchQueue.main.async { self?.audioFramePending = false }
            } catch {
                DispatchQueue.main.async {
                    self?.audioFramePending = false
                    self?.musicVisualizer.stop()
                    self?.isMusicReactive = false
                    self?.showError(error)
                }
            }
        }
    }

    private func installLifecycleMonitoring() {
        let center = NSWorkspace.shared.notificationCenter
        let activation = center.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                            object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor [weak self] in self?.applicationDidActivate(app) }
        }
        let wake = center.addObserver(forName: NSWorkspace.didWakeNotification,
                                     object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, KeyboardService.hasInputMonitoringAccess else { return }
                self.scan()
            }
        }
        workspaceObservers = [activation, wake]
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 7, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, KeyboardService.hasInputMonitoringAccess else { return }
                switch self.connectionState {
                case .disconnected, .failed: self.scan()
                default: break
                }
            }
        }
        RunLoop.main.add(reconnectTimer!, forMode: .common)

        if let app = NSWorkspace.shared.frontmostApplication { applicationDidActivate(app) }
    }

    private func applicationDidActivate(_ app: NSRunningApplication) {
        guard let bundleIdentifier = app.bundleIdentifier else { return }
        if bundleIdentifier != Bundle.main.bundleIdentifier {
            lastExternalBundleIdentifier = bundleIdentifier
            lastExternalApplicationName = app.localizedName ?? bundleIdentifier
            activeApplicationName = app.localizedName ?? bundleIdentifier
        }
        guard automaticProfilesEnabled,
              bundleIdentifier != Bundle.main.bundleIdentifier,
              let stored = profileStore.profile(forBundleIdentifier: bundleIdentifier) else {
            if bundleIdentifier != Bundle.main.bundleIdentifier { lastAutomaticProfileID = nil }
            return
        }
        guard stored.id != lastAutomaticProfileID, connectionState.isConnected else { return }
        lastAutomaticProfileID = stored.id
        applyLibraryProfile(stored.id, automatic: true)
    }

    private func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.16)) { toast = message }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            if toast == message {
                withAnimation(.easeIn(duration: 0.14)) { toast = nil }
            }
        }
    }

    private func showError(_ error: Error) {
        connectionState = .failed(error.localizedDescription)
        log(error.localizedDescription)
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
