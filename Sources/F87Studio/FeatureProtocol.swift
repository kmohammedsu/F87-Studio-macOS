import Foundation

enum FeatureF87Protocol {
    static let reportSize = 520
    static let configSize = 136
    static let supportedEffectIDs: Set<Int> = [0, 1, 2, 3, 4, 5, 7, 8, 10, 11, 12, 13, 15, 16, 17]

    static func packet(command: UInt8) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: reportSize)
        data[0] = 0x06
        data[1] = command
        data[4] = 0x01
        return data
    }

    static func modelQuery() -> [UInt8] {
        var data = packet(command: 0x82)
        data[2] = 0x01
        data[6] = 0x06
        return data
    }

    static func configReadTrigger() -> [UInt8] {
        var data = packet(command: 0x84)
        data[6] = 0x80
        return data
    }

    static func configWrite(from config: [UInt8], effect: Int, brightness: Int,
                            speed: Int, colorful: Bool) throws -> [UInt8] {
        guard config.count >= configSize, config[0] == 0x06 else {
            throw F87Error.invalidConfiguration
        }
        var data = packet(command: 0x04)
        data[6] = 0x80
        data.replaceSubrange(8..<configSize, with: config[8..<configSize])
        data[17] = effect == 18 ? 0x01 : 0x00
        data[18] = UInt8(effect)
        if (1...18).contains(effect) {
            let offset = 64 + 2 * effect
            data[offset] = UInt8(max(1, min(4, brightness)))
            data[offset + 1] = UInt8((max(0, min(4, speed)) << 4) | (colorful ? 0x07 : 0x00))
        }
        return data
    }

    static func customColor(_ color: RGBColor) -> [UInt8] {
        var data = packet(command: 0x0A)
        data[7] = 0x02
        var offset = 29
        while offset + 2 < 514 {
            data[offset] = color.red
            data[offset + 1] = color.green
            data[offset + 2] = color.blue
            offset += 3
        }
        data[514] = 0x5A
        data[515] = 0xA5
        return data
    }

    static func perKeyColors(_ colors: [Int: RGBColor]) -> [UInt8] {
        var data = packet(command: 0x06)
        data[6] = 0x7A
        data[7] = 0x01
        for (index, color) in colors where (0..<122).contains(index) {
            data[8 + index] = color.red
            data[134 + index] = color.green
            data[260 + index] = color.blue
        }
        return data
    }
}
