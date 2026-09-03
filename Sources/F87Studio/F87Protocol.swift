import Foundation

enum F87Protocol {
    static let reportID: UInt8 = 0x13
    static let commandRead: UInt8 = 0x44
    static let commandWrite: UInt8 = 0x04
    static let commandColor: UInt8 = 0x09
    static let commandPerKey: UInt8 = 0x02
    static let commandSave: UInt8 = 0x0A
    static let subConfig: UInt8 = 0x0A
    static let subPalette: UInt8 = 0x25
    static let subPerKey: UInt8 = 0x1C
    static let subConfirm: UInt8 = 0x01
    static let customEffect: UInt8 = 21
    static let commandAudio: UInt8 = 0x88
    static let supportedEffectIDs: Set<Int> = [0, 1, 2, 3, 4, 5, 7, 8, 10, 11, 12, 13, 15, 16, 17]

    static func checksum(_ data: [UInt8]) -> UInt8 {
        UInt8(data.prefix(19).reduce(0) { ($0 + Int($1)) & 0xFF })
    }

    static func frame(command: UInt8, subcommand: UInt8, sequence: UInt8, payload: [UInt8] = []) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: 20)
        result[0] = reportID
        result[1] = command
        result[2] = subcommand
        result[3] = sequence
        for index in 0..<min(15, payload.count) { result[4 + index] = payload[index] }
        result[19] = checksum(result)
        return result
    }

    static func readRequest() -> [UInt8] {
        frame(command: commandRead, subcommand: subConfirm, sequence: 0)
    }

    static func saveFrame() -> [UInt8] {
        frame(command: commandSave, subcommand: subConfirm, sequence: 0,
              payload: [0x04, 0x07] + [UInt8](repeating: 0, count: 13))
    }

    static let factoryConfigPayloads: [[UInt8]] = [
        [0x0E, 0x00, 0x03, 0x03, 0x01, 0x00, 0x00, 0x04, 0x04, 0x07, 0x00, 0x00, 0x20, 0x03, 0x00],
        [0x0E, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x02, 0x01, 0x00, 0xFF, 0x0A, 0x00, 0x00, 0x00],
        [0x0E, 0x01, 0x00, 0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
        [0x0E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
        [0x0E, 0xFF, 0xFF, 0x04, 0x47, 0x04, 0x47, 0x04, 0x47, 0x04, 0x47, 0x04, 0x47, 0x04, 0x47],
        [0x0E, 0x04, 0x47, 0x04, 0x47, 0x04, 0x47, 0x04, 0x47, 0x04, 0x47, 0x04, 0x47, 0x04, 0x47],
        [0x0E, 0x04, 0x47, 0x04, 0x47, 0x04, 0x47, 0x04, 0x37, 0x04, 0x37, 0x04, 0x37, 0x04, 0x37],
        [0x0E, 0x07, 0x47, 0x07, 0x47, 0x07, 0x44, 0x07, 0x44, 0x07, 0x44, 0x07, 0x44, 0x07, 0x44],
        [0x0E, 0x07, 0x44, 0x07, 0x44, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04],
        [0x02, 0x5A, 0xA5, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    ]

    static func factoryConfigFrames() -> [[UInt8]] {
        factoryConfigPayloads.enumerated().map { sequence, original in
            var payload = original
            if sequence == 0 { payload[4] = 0x01 }
            return frame(command: commandWrite, subcommand: subConfig,
                         sequence: UInt8(sequence), payload: payload)
        }
    }

    static func effectTableLocation(_ effect: Int) -> (sequence: Int, offset: Int)? {
        switch effect {
        case 1...6: return (4, 7 + (effect - 1) * 2)
        case 7...13: return (5, 5 + (effect - 7) * 2)
        case 14...18: return (6, 5 + (effect - 14) * 2)
        default: return nil
        }
    }

    static func speedByte(speed: Int, colorful: Bool) -> UInt8 {
        UInt8((max(0, min(4, speed)) << 4) | (colorful ? 0x07 : 0x00))
    }

    static func updateEffect(config: [[UInt8]], effect: Int, brightness: Int, speed: Int,
                             colorful: Bool, usesCustomColor: Bool) throws -> [[UInt8]] {
        guard config.count == 10, config.allSatisfy({ $0.count == 20 }) else {
            throw F87Error.invalidConfiguration
        }
        var output = config
        for index in output.indices {
            output[index][1] = commandWrite
            if index == 0 {
                output[index][8] = 0x01
                output[index][14] = 0x00
                output[index][15] = UInt8(effect)
                output[index][17] = (usesCustomColor || colorful) ? 0x01 : 0x03
            }
            if let location = effectTableLocation(effect), index == location.sequence {
                output[index][location.offset] = UInt8(max(0, min(4, brightness)))
                output[index][location.offset + 1] = speedByte(speed: speed, colorful: colorful)
            }
            output[index][19] = checksum(output[index])
        }
        return output
    }

    static func paletteFrames(color: RGBColor?) -> [[UInt8]] {
        let a: [UInt8] = [0x0e, 0x00, 0xff, 0xff, 0xff, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff]
        let b: [UInt8] = [0x0e, 0xff, 0x00, 0x00, 0x00, 0xff, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0x00, 0xff, 0x00]
        let c: [UInt8] = [0x0e, 0xff, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0xff, 0x00, 0x00]
        var frames: [[UInt8]] = []
        for sequence in 0..<37 {
            var payload: [UInt8]
            switch sequence {
            case 0: payload = [0x0e] + [UInt8](repeating: 0, count: 14)
            case 1:
                payload = [0x0e, 0, 0, 0, 0, 0, 0, 0, 0xff, 0, 0, 0, 0xff, 0, 0]
                if let color {
                    payload[8] = color.red
                    payload[9] = color.green
                    payload[10] = color.blue
                    payload[12] = 0xff
                }
            case 2...20: payload = [a, b, c][(sequence - 2) % 3]
            case 36: payload = [0x08, 0, 0, 0x5a, 0xa5] + [UInt8](repeating: 0, count: 10)
            default: payload = [0x0e] + [UInt8](repeating: 0, count: 14)
            }
            frames.append(frame(command: commandColor, subcommand: subPalette,
                                sequence: UInt8(sequence), payload: payload))
        }
        return frames
    }

    static func perKeyFrames(colors: [Int: RGBColor]) -> [[UInt8]] {
        var planes = [[UInt8](repeating: 0, count: 126),
                      [UInt8](repeating: 0, count: 126),
                      [UInt8](repeating: 0, count: 126)]
        for (index, color) in colors where (0..<126).contains(index) {
            planes[0][index] = color.red
            planes[1][index] = color.green
            planes[2][index] = color.blue
        }
        var result: [[UInt8]] = []
        var sequence = 0
        for plane in planes {
            for part in 0..<9 {
                let start = part * 14
                let payload = [UInt8(0x0e)] + Array(plane[start..<(start + 14)])
                result.append(frame(command: commandPerKey, subcommand: subPerKey,
                                    sequence: UInt8(sequence), payload: payload))
                sequence += 1
            }
        }
        var trailer = [UInt8](repeating: 0, count: 15)
        trailer[0] = 0x06
        trailer[3] = 0x5a
        trailer[4] = 0xa5
        result.append(frame(command: commandPerKey, subcommand: subPerKey,
                            sequence: UInt8(sequence), payload: trailer))
        return result
    }

    static func audioIdleFrame() -> [UInt8] {
        var result = [UInt8](repeating: 0, count: 20)
        result[0] = reportID
        result[1] = commandAudio
        result[2] = 0x01
        result[4] = 0x23
        result[19] = checksum(result)
        return result
    }

    static func audioFrames(colors: [Int: RGBColor], quantize initialStep: Int = 64) -> [[UInt8]] {
        guard !colors.isEmpty else { return [audioIdleFrame()] }
        var step = max(1, initialStep)
        var data: [UInt8] = []
        while true {
            var groups: [RGBColor: [UInt8]] = [:]
            for (index, color) in colors where color != .black {
                func quantized(_ value: UInt8) -> UInt8 {
                    UInt8(min(255, ((Int(value) + step / 2) / step) * step))
                }
                let key = RGBColor(red: quantized(color.red), green: quantized(color.green),
                                   blue: quantized(color.blue))
                groups[key, default: []].append(UInt8(truncatingIfNeeded: index))
            }
            data.removeAll(keepingCapacity: true)
            for (color, indices) in groups.sorted(by: { $0.value.count > $1.value.count }) {
                data.append(contentsOf: [color.red, color.green, color.blue, UInt8(indices.count)])
                data.append(contentsOf: indices)
            }
            if data.count <= 196 || step >= 256 { break }
            step *= 2
        }
        guard !data.isEmpty else { return [audioIdleFrame()] }
        let chunks = stride(from: 0, to: data.count, by: 14).map {
            Array(data[$0..<min($0 + 14, data.count)])
        }.prefix(14)
        let total = chunks.count
        return chunks.enumerated().map { sequence, chunk in
            var result = [UInt8](repeating: 0, count: 20)
            result[0] = reportID
            result[1] = commandAudio
            result[2] = UInt8(total)
            result[3] = UInt8(sequence)
            result[4] = sequence == total - 1 ? UInt8(0x10 + chunk.count) : 0x1E
            for (offset, byte) in chunk.enumerated() { result[5 + offset] = byte }
            result[19] = checksum(result)
            return result
        }
    }

    static func customModeConfig(from config: [[UInt8]]) throws -> [[UInt8]] {
        guard config.count == 10, config.allSatisfy({ $0.count == 20 }) else {
            throw F87Error.invalidConfiguration
        }
        var output = config
        for index in output.indices {
            output[index][1] = commandWrite
            if index == 0 {
                output[index][8] = 0x01
                output[index][14] = 0x00
                output[index][15] = customEffect
                output[index][17] = 0x01
            }
            output[index][19] = checksum(output[index])
        }
        return output
    }
}

enum F87Error: LocalizedError {
    case notFound
    case permissionDenied
    case cannotOpen
    case writeFailed
    case readFailed
    case invalidConfiguration
    case verificationFailed(String)
    case unsupported(String)
    case diagnostic(String)

    var errorDescription: String? {
        switch self {
        case .notFound: return "No configurable F87 connection was found. If you are using Bluetooth, plug in the USB cable and switch the keyboard to wired mode, then scan again. The known 2.4 GHz receiver (3554:FA09) is also supported."
        case .permissionDenied: return "The AULA keyboard is connected, but Input Monitoring access is not enabled for this copy of F87 Studio. Open the setting, remove any older F87 Studio entry, add the copy in Applications, enable it, then quit and reopen the app."
        case .cannotOpen: return "macOS found the keyboard but could not open its control interface. Allow F87 Studio in Privacy & Security → Input Monitoring, then reconnect the keyboard."
        case .writeFailed: return "The keyboard stopped accepting data. Reconnect it and try again."
        case .readFailed: return "The keyboard did not return its current configuration. No changes were written."
        case .invalidConfiguration: return "The keyboard returned an unexpected configuration format. No changes were written."
        case .verificationFailed(let message): return message
        case .unsupported(let message): return message
        case .diagnostic(let message): return message
        }
    }
}
