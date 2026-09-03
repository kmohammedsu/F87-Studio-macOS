import CHID
import Foundation
import IOKit.hid

struct HIDCandidate: Sendable {
    let path: String
    let vendorID: UInt16
    let productID: UInt16
    let usagePage: UInt16
    let mode: String

    var displayName: String {
        "AULA F87 · \(mode) · \(String(format: "%04X:%04X", vendorID, productID))"
    }
}

final class HIDConnection {
    private var handle: OpaquePointer?
    let candidate: HIDCandidate

    init(candidate: HIDCandidate) throws {
        self.candidate = candidate
        handle = candidate.path.withCString { hid_open_path($0) }
        guard handle != nil else {
            throw F87Error.diagnostic("Open failed for \(candidate.displayName): \(Self.lastError())")
        }
    }

    deinit { close() }

    func close() {
        if let handle { hid_close(handle); self.handle = nil }
    }

    func write(_ bytes: [UInt8]) throws {
        guard let handle else { throw F87Error.cannotOpen }
        let sent = bytes.withUnsafeBufferPointer { pointer in
            hid_write(handle, pointer.baseAddress, bytes.count)
        }
        guard sent == bytes.count else {
            throw F87Error.diagnostic("Output report failed: \(Self.lastError(handle))")
        }
    }

    func read(timeoutMilliseconds: Int32) -> [UInt8]? {
        guard let handle else { return nil }
        var buffer = [UInt8](repeating: 0, count: 64)
        let count = buffer.withUnsafeMutableBufferPointer { pointer in
            hid_read_timeout(handle, pointer.baseAddress, pointer.count, timeoutMilliseconds)
        }
        guard count > 0 else { return nil }
        return Array(buffer.prefix(Int(count)))
    }

    func sendFeature(_ bytes: [UInt8]) throws {
        guard let handle else { throw F87Error.cannotOpen }
        let sent = bytes.withUnsafeBufferPointer { pointer in
            hid_send_feature_report(handle, pointer.baseAddress, bytes.count)
        }
        guard sent == bytes.count else {
            throw F87Error.diagnostic("Feature report write failed: \(Self.lastError(handle))")
        }
    }

    func getFeature(reportID: UInt8 = 0x06, length: Int = 520) throws -> [UInt8] {
        guard let handle else { throw F87Error.cannotOpen }
        var buffer = [UInt8](repeating: 0, count: length)
        buffer[0] = reportID
        let count = buffer.withUnsafeMutableBufferPointer { pointer in
            hid_get_feature_report(handle, pointer.baseAddress, pointer.count)
        }
        guard count > 0 else {
            throw F87Error.diagnostic("Feature report read failed: \(Self.lastError(handle))")
        }
        return Array(buffer.prefix(Int(count)))
    }

    private static func lastError(_ handle: OpaquePointer? = nil) -> String {
        guard let pointer = hid_error(handle) else { return "No HID error detail" }
        var scalars = String.UnicodeScalarView()
        var cursor = pointer
        while cursor.pointee != 0 {
            if let scalar = UnicodeScalar(UInt32(bitPattern: cursor.pointee)) { scalars.append(scalar) }
            cursor = cursor.advanced(by: 1)
        }
        let message = String(scalars)
        return message.isEmpty ? "No HID error detail" : message
    }
}

@MainActor
enum HIDDiscovery {
    static func initialize() {
        _ = hid_init()
        hid_darwin_set_open_exclusive(0)
    }

    static func candidates() -> [HIDCandidate] {
        initialize()
        let devices: [(UInt16, UInt16, String)] = [
            (0x258A, 0x010C, "USB"),
            (0x3554, 0xFA09, "2.4 GHz")
        ]
        var result: [HIDCandidate] = []
        for (vendor, product, mode) in devices {
            var cursor = hid_enumerate(vendor, product)
            let root = cursor
            while let node = cursor {
                let info = node.pointee
                let page = UInt16(truncatingIfNeeded: info.usage_page)
                if page >= 0xFF00, let rawPath = info.path {
                    result.append(.init(path: String(cString: rawPath), vendorID: vendor,
                                        productID: product, usagePage: page, mode: mode))
                }
                cursor = info.next
            }
            if let root { hid_free_enumeration(root) }
        }
        return result
    }
}

final class KeyboardService: @unchecked Sendable {
    static var hasInputMonitoringAccess: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    @discardableResult
    static func requestInputMonitoringAccess() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    private enum Backend {
        case feature(HIDConnection)
        case fragments(HIDConnection)

        var connection: HIDConnection {
            switch self {
            case .feature(let connection), .fragments(let connection): return connection
            }
        }

        var isFeature: Bool {
            if case .feature = self { return true }
            return false
        }
    }

    private var backend: Backend?
    private(set) var currentSnapshot: KeyboardSnapshot?

    var connectedName: String? {
        guard let backend else { return nil }
        let suffix = backend.isFeature ? "520-byte wired" : "20-byte control"
        return "\(backend.connection.candidate.displayName) · \(suffix)"
    }
    var supportsTimingSettings: Bool {
        if case .fragments = backend { return true }
        return false
    }
    var supportsFactoryReset: Bool {
        if case .fragments = backend { return true }
        return false
    }
    var supportsAudioStreaming: Bool {
        if case .fragments = backend { return true }
        return false
    }
    var minimumBrightness: Int { backend?.isFeature == true ? 1 : 0 }
    var supportedEffectIDs: Set<Int> {
        backend?.isFeature == true ? FeatureF87Protocol.supportedEffectIDs : F87Protocol.supportedEffectIDs
    }

    func connect(candidates: [HIDCandidate]) throws -> String {
        backend?.connection.close()
        backend = nil
        currentSnapshot = nil
        guard !candidates.isEmpty else { throw F87Error.notFound }
        var failures: [String] = ["Input Monitoring status: \(Self.hasInputMonitoringAccess ? "granted" : "not reported as granted")"]
        for candidate in candidates {
            do {
                let probe = try HIDConnection(candidate: candidate)
                do {
                    if candidate.vendorID == 0x258A {
                        try primeFeatureDevice(using: probe)
                        let config = try readFeatureConfig(using: probe)
                        backend = .feature(probe)
                        currentSnapshot = featureSnapshot(from: config)
                    } else {
                        let config = try readFragmentConfig(using: probe)
                        backend = .fragments(probe)
                        currentSnapshot = fragmentSnapshot(from: config)
                    }
                    return connectedName ?? candidate.displayName
                } catch {
                    failures.append("\(candidate.displayName): \(error.localizedDescription)")
                    probe.close()
                }
            } catch {
                failures.append(error.localizedDescription)
            }
        }
        throw F87Error.diagnostic(failures.joined(separator: " | "))
    }

    func disconnect() {
        backend?.connection.close()
        backend = nil
        currentSnapshot = nil
    }

    func applyEffect(effect: Int, brightness: Int, speed: Int, colorful: Bool, color: RGBColor) throws {
        guard let backend else { throw F87Error.notFound }
        switch backend {
        case .feature(let connection):
            try applyFeatureEffect(using: connection, effect: effect, brightness: brightness,
                                   speed: speed, colorful: colorful, color: color)
            return
        case .fragments(let connection):
            try applyFragmentEffect(using: connection, effect: effect, brightness: brightness,
                                    speed: speed, colorful: colorful, color: color)
        }
    }

    private func applyFragmentEffect(using connection: HIDConnection, effect: Int, brightness: Int,
                                     speed: Int, colorful: Bool, color: RGBColor) throws {
        guard F87Protocol.supportedEffectIDs.contains(effect) else {
            throw F87Error.unsupported("That effect has not been validated on this F87 firmware revision.")
        }
        let base = try readFragmentConfig(using: connection)
        let supportsColor = LightingEffect.all.first(where: { $0.id == effect })?.supportsColor ?? false
        let customColor = supportsColor && !colorful && effect != 0
        let writes = try F87Protocol.updateEffect(config: base, effect: effect,
                                                  brightness: brightness, speed: speed,
                                                  colorful: colorful, usesCustomColor: customColor)
        try transmit(writes, using: connection)
        try transmit(F87Protocol.paletteFrames(color: customColor ? color : nil), using: connection)
        try transmitOne(F87Protocol.saveFrame(), using: connection, requireEcho: false)
        let verified = try readFragmentConfig(using: connection)
        guard verified[0][15] == UInt8(effect) else {
            throw F87Error.verificationFailed("The keyboard replied, but did not activate the requested effect.")
        }
        if let location = F87Protocol.effectTableLocation(effect) {
            let expectedBrightness = UInt8(max(0, min(4, brightness)))
            let expectedSpeed = F87Protocol.speedByte(speed: speed, colorful: colorful)
            guard verified[location.sequence][location.offset] == expectedBrightness,
                  verified[location.sequence][location.offset + 1] == expectedSpeed else {
                throw F87Error.verificationFailed("The effect changed, but the keyboard did not retain the requested brightness, speed, or color mode.")
            }
        }
    }

    func applyPerKey(_ colors: [Int: RGBColor]) throws {
        guard let backend else { throw F87Error.notFound }
        switch backend {
        case .feature(let connection):
            try connection.sendFeature(FeatureF87Protocol.perKeyColors(colors))
            let config = try readFeatureConfig(using: connection)
            try connection.sendFeature(try FeatureF87Protocol.configWrite(
                from: config, effect: 18, brightness: max(1, featureBrightness(from: config, effect: 18)),
                speed: 0, colorful: false))
            let verified = try readFeatureConfig(using: connection)
            guard verified[18] == 18 else {
                throw F87Error.verificationFailed("The keyboard did not enter per-key color mode.")
            }
        case .fragments(let connection):
            let base = try readFragmentConfig(using: connection)
            try transmit(F87Protocol.customModeConfig(from: base), using: connection)
            try transmit(F87Protocol.perKeyFrames(colors: colors), using: connection)
            try transmitOne(F87Protocol.saveFrame(), using: connection, requireEcho: false)
            let verified = try readFragmentConfig(using: connection)
            guard verified[0][15] == F87Protocol.customEffect else {
                throw F87Error.verificationFailed("The keyboard replied, but did not enter per-key color mode.")
            }
        }
    }

    func applySleep(minutes: Int) throws {
        guard case .fragments(let connection) = backend else {
            throw F87Error.unsupported("Sleep timing has not been decoded safely for this wired firmware revision.")
        }
        let expected = UInt8(max(0, min(60, minutes)) * 2)
        var config = try readFragmentConfig(using: connection)
        for index in config.indices {
            config[index][1] = F87Protocol.commandWrite
            if index == 0 { config[index][8] = 0x01 }
            if index == 1 { config[index][15] = expected }
            config[index][19] = F87Protocol.checksum(config[index])
        }
        try transmit(config, using: connection)
        try transmitOne(F87Protocol.saveFrame(), using: connection, requireEcho: false)
        let verified = try readFragmentConfig(using: connection)
        guard verified[1][15] == expected else {
            throw F87Error.verificationFailed("The keyboard did not confirm the requested sleep timer.")
        }
    }

    func applyDebounce(milliseconds: Int) throws {
        guard case .fragments(let connection) = backend else {
            throw F87Error.unsupported("Debounce timing has not been decoded safely for this wired firmware revision.")
        }
        let expected = UInt8(max(1, min(5, milliseconds)) - 1)
        var config = try readFragmentConfig(using: connection)
        for index in config.indices {
            config[index][1] = F87Protocol.commandWrite
            if index == 0 { config[index][8] = expected }
            config[index][19] = F87Protocol.checksum(config[index])
        }
        try transmit(config, using: connection)
        try transmitOne(F87Protocol.saveFrame(), using: connection, requireEcho: false)
        let verified = try readFragmentConfig(using: connection)
        guard verified[0][8] == expected else {
            throw F87Error.verificationFailed("The keyboard did not confirm the debounce setting.")
        }
    }

    func factoryReset() throws {
        guard case .fragments(let connection) = backend else {
            throw F87Error.unsupported("Factory reset is available only on the verified 20-byte F87 control protocol.")
        }
        try transmit(F87Protocol.factoryConfigFrames(), using: connection)
        try transmit(F87Protocol.paletteFrames(color: nil), using: connection)
        try transmitOne(F87Protocol.saveFrame(), using: connection, requireEcho: false)
        let verified = try readFragmentConfig(using: connection)
        guard verified[0][15] == 0, verified[1][15] == 0x0A, verified[0][8] == 0x01 else {
            throw F87Error.verificationFailed("The keyboard did not confirm all factory-default settings.")
        }
        currentSnapshot = fragmentSnapshot(from: verified)
    }

    func streamAudio(_ colors: [Int: RGBColor]) throws {
        guard case .fragments(let connection) = backend else {
            throw F87Error.unsupported("Music-reactive streaming is available only on the verified 20-byte receiver protocol.")
        }
        for frame in F87Protocol.audioFrames(colors: colors) {
            try connection.write(frame)
            Thread.sleep(forTimeInterval: 0.002)
        }
    }

    func stopAudioStream() throws {
        guard case .fragments(let connection) = backend else { return }
        try connection.write(F87Protocol.audioIdleFrame())
    }

    private func applyFeatureEffect(using connection: HIDConnection, effect: Int, brightness: Int,
                                    speed: Int, colorful: Bool, color: RGBColor) throws {
        guard FeatureF87Protocol.supportedEffectIDs.contains(effect) else {
            throw F87Error.unsupported("That effect is not present in this F87 firmware revision.")
        }
        let info = LightingEffect.all.first(where: { $0.id == effect })
        let hasColor = info?.supportsColor == true && effect != 0 && !colorful
        if hasColor { try connection.sendFeature(FeatureF87Protocol.customColor(color)) }
        let config = try readFeatureConfig(using: connection)
        try connection.sendFeature(try FeatureF87Protocol.configWrite(
            from: config, effect: effect, brightness: brightness, speed: speed,
            colorful: colorful || info?.supportsColor == false))
        let verified = try readFeatureConfig(using: connection)
        guard verified.count >= FeatureF87Protocol.configSize, verified[18] == UInt8(effect) else {
            throw F87Error.verificationFailed("The keyboard replied, but did not activate the requested effect.")
        }
        if (1...18).contains(effect) {
            let offset = 64 + 2 * effect
            let expectedBrightness = UInt8(max(1, min(4, brightness)))
            let expectedSpeed = UInt8((max(0, min(4, speed)) << 4) | ((colorful || info?.supportsColor == false) ? 0x07 : 0x00))
            guard verified[offset] == expectedBrightness, verified[offset + 1] == expectedSpeed else {
                throw F87Error.verificationFailed("The effect changed, but the keyboard did not retain the requested brightness, speed, or color mode.")
            }
        }
    }

    private func readFeatureConfig(using connection: HIDConnection) throws -> [UInt8] {
        try connection.sendFeature(FeatureF87Protocol.configReadTrigger())
        Thread.sleep(forTimeInterval: 0.008)
        let response = try connection.getFeature(length: FeatureF87Protocol.reportSize)
        guard response.count >= FeatureF87Protocol.configSize,
              response[134] == 0x5A, response[135] == 0xA5 else {
            let header = response.prefix(20).map { String(format: "%02X", $0) }.joined(separator: " ")
            throw F87Error.diagnostic("Unexpected config response (\(response.count) bytes; header \(header)). No changes were written.")
        }
        return response
    }

    private func primeFeatureDevice(using connection: HIDConnection) throws {
        try connection.sendFeature(FeatureF87Protocol.modelQuery())
        Thread.sleep(forTimeInterval: 0.008)
        _ = try connection.getFeature(length: FeatureF87Protocol.reportSize)
    }

    private func featureBrightness(from config: [UInt8], effect: Int) -> Int {
        let offset = 64 + 2 * effect
        guard config.indices.contains(offset) else { return 4 }
        let value = Int(config[offset])
        return (1...4).contains(value) ? value : 4
    }

    private func featureSnapshot(from config: [UInt8]) -> KeyboardSnapshot {
        let effect = config.indices.contains(18) ? Int(config[18]) : 0
        let offset = 64 + 2 * effect
        let brightness = config.indices.contains(offset) ? Int(config[offset]) : nil
        let speedByte = config.indices.contains(offset + 1) ? config[offset + 1] : nil
        return KeyboardSnapshot(effect: effect,
                                brightness: brightness,
                                speed: speedByte.map { Int(($0 >> 4) & 0x0F) },
                                colorful: speedByte.map { ($0 & 0x0F) == 0x07 },
                                sleepMinutes: nil,
                                debounceMilliseconds: nil)
    }

    private func fragmentSnapshot(from config: [[UInt8]]) -> KeyboardSnapshot {
        let effect = Int(config[0][15])
        let location = F87Protocol.effectTableLocation(effect)
        let brightness = location.map { Int(config[$0.sequence][$0.offset]) }
        let speedByte = location.map { config[$0.sequence][$0.offset + 1] }
        let sleepRaw = Int(config[1][15])
        let debounceRaw = Int(config[0][8])
        return KeyboardSnapshot(effect: effect,
                                brightness: brightness,
                                speed: speedByte.map { Int(($0 >> 4) & 0x0F) },
                                colorful: speedByte.map { ($0 & 0x0F) == 0x07 },
                                sleepMinutes: sleepRaw <= 120 ? sleepRaw / 2 : nil,
                                debounceMilliseconds: debounceRaw <= 4 ? debounceRaw + 1 : nil)
    }

    private func readFragmentConfig(using connection: HIDConnection) throws -> [[UInt8]] {
        for attempt in 0..<2 {
            if attempt > 0 { Thread.sleep(forTimeInterval: 0.1) }
            try connection.write(F87Protocol.readRequest())
            Thread.sleep(forTimeInterval: 0.05)
            var config = [[UInt8]?](repeating: nil, count: 10)
            let deadline = Date().addingTimeInterval(1.6)
            while Date() < deadline, config.contains(where: { $0 == nil }) {
                guard let report = connection.read(timeoutMilliseconds: 120), report.count >= 20 else { continue }
                let frame = Array(report.prefix(20))
                guard frame[0] == F87Protocol.reportID,
                      frame[1] == F87Protocol.commandRead,
                      frame[2] == F87Protocol.subConfig,
                      frame[19] == F87Protocol.checksum(frame) else { continue }
                let sequence = Int(frame[3])
                if (0..<10).contains(sequence) { config[sequence] = frame }
            }
            if config.allSatisfy({ $0 != nil }) { return config.map { $0! } }
        }
        throw F87Error.readFailed
    }

    private func transmit(_ frames: [[UInt8]], using connection: HIDConnection) throws {
        for frame in frames { try transmitOne(frame, using: connection) }
    }

    private func transmitOne(_ frame: [UInt8], using connection: HIDConnection,
                             requireEcho: Bool = true) throws {
        let attempts = requireEcho ? 2 : 1
        for _ in 0..<attempts {
            try connection.write(frame)
            Thread.sleep(forTimeInterval: 0.003)
            let deadline = Date().addingTimeInterval(0.35)
            while Date() < deadline {
                guard let report = connection.read(timeoutMilliseconds: 70) else { continue }
                if report.count >= frame.count, Array(report.prefix(frame.count)) == frame { return }
            }
        }
        if !requireEcho { return }
        let command = frame.count > 2 ? String(format: "%02X/%02X", frame[1], frame[2]) : "unknown"
        throw F87Error.diagnostic("The keyboard did not echo control packet \(command). The write was stopped before continuing.")
    }
}
