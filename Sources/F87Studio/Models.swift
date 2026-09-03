import Foundation
import SwiftUI

struct RGBColor: Codable, Hashable, Sendable {
    var red: UInt8
    var green: UInt8
    var blue: UInt8

    static let black = RGBColor(red: 0, green: 0, blue: 0)
    static let accent = RGBColor(red: 92, green: 225, blue: 230)

    init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(color: Color) {
        let ns = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
        red = UInt8(max(0, min(255, Int(ns.redComponent * 255))))
        green = UInt8(max(0, min(255, Int(ns.greenComponent * 255))))
        blue = UInt8(max(0, min(255, Int(ns.blueComponent * 255))))
    }

    var color: Color {
        Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    var hex: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }
}

struct LightingEffect: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let supportsSpeed: Bool
    let supportsColor: Bool

    static let all: [LightingEffect] = [
        .init(id: 0, name: "Off", supportsSpeed: false, supportsColor: false),
        .init(id: 1, name: "Fixed On", supportsSpeed: false, supportsColor: true),
        .init(id: 2, name: "Breathing", supportsSpeed: true, supportsColor: true),
        .init(id: 3, name: "Rainbow", supportsSpeed: true, supportsColor: false),
        .init(id: 4, name: "Flash Away", supportsSpeed: true, supportsColor: true),
        .init(id: 5, name: "Raindrops", supportsSpeed: true, supportsColor: true),
        .init(id: 6, name: "Rainbow Wheel", supportsSpeed: true, supportsColor: true),
        .init(id: 7, name: "Ripple", supportsSpeed: true, supportsColor: true),
        .init(id: 8, name: "Starlight", supportsSpeed: true, supportsColor: true),
        .init(id: 9, name: "Shadow", supportsSpeed: true, supportsColor: true),
        .init(id: 10, name: "Retro Snake", supportsSpeed: true, supportsColor: true),
        .init(id: 11, name: "Neon Stream", supportsSpeed: true, supportsColor: true),
        .init(id: 12, name: "Reaction", supportsSpeed: true, supportsColor: true),
        .init(id: 13, name: "Sine Wave", supportsSpeed: true, supportsColor: true),
        .init(id: 14, name: "Scanning", supportsSpeed: true, supportsColor: true),
        .init(id: 15, name: "Windmill", supportsSpeed: true, supportsColor: false),
        .init(id: 16, name: "Waterfall", supportsSpeed: true, supportsColor: false),
        .init(id: 17, name: "Blossoming", supportsSpeed: true, supportsColor: false),
        .init(id: 18, name: "Rotating Storm", supportsSpeed: true, supportsColor: true)
    ]
}

struct KeyboardKey: Identifiable, Hashable, Sendable {
    let label: String
    let led: Int
    let width: Double
    var id: Int { led }
}

enum KeyRowItem: Hashable, Sendable {
    case key(KeyboardKey)
    case gap(Double)
}

enum F87Layout {
    static let rows: [[KeyRowItem]] = [
        row([("Esc",0,1), ("F1",12,1), ("F2",18,1), ("F3",24,1), ("F4",30,1), ("F5",36,1), ("F6",42,1), ("F7",48,1), ("F8",54,1), ("F9",60,1), ("F10",66,1), ("F11",72,1), ("F12",78,1), ("Prt",84,1), ("Scr",90,1), ("Pse",96,1)], gaps: [1:1, 5:0.5, 9:0.5, 13:0.25]),
        row([("`",1,1), ("1",7,1), ("2",13,1), ("3",19,1), ("4",25,1), ("5",31,1), ("6",37,1), ("7",43,1), ("8",49,1), ("9",55,1), ("0",61,1), ("-",67,1), ("=",73,1), ("Bksp",79,2), ("Ins",85,1), ("Home",91,1), ("PgUp",97,1)], gaps: [14:0.25]),
        row([("Tab",2,1.5), ("Q",8,1), ("W",14,1), ("E",20,1), ("R",26,1), ("T",32,1), ("Y",38,1), ("U",44,1), ("I",50,1), ("O",56,1), ("P",62,1), ("[",68,1), ("]",74,1), ("\\",80,1.5), ("Del",86,1), ("End",92,1), ("PgDn",98,1)], gaps: [14:0.25]),
        row([("Caps",3,1.75), ("A",9,1), ("S",15,1), ("D",21,1), ("F",27,1), ("G",33,1), ("H",39,1), ("J",45,1), ("K",51,1), ("L",57,1), (";",63,1), ("'",69,1), ("Enter",81,2.25)]),
        row([("Shift",4,2.25), ("Z",10,1), ("X",16,1), ("C",22,1), ("V",28,1), ("B",34,1), ("N",40,1), ("M",46,1), (",",52,1), (".",58,1), ("/",64,1), ("Shift",82,2.75), ("↑",94,1)], gaps: [12:1.25]),
        row([("Ctrl",5,1.25), ("⌘",11,1.25), ("Alt",17,1.25), ("Space",35,6.25), ("Alt",53,1.25), ("Fn",59,1.25), ("App",65,1.25), ("Ctrl",83,1.25), ("←",89,1), ("↓",95,1), ("→",101,1)], gaps: [8:0.25])
    ]

    static let allKeys: [KeyboardKey] = rows.flatMap { row in
        row.compactMap { if case let .key(key) = $0 { return key }; return nil }
    }

    static func key(at point: CGPoint, unit: CGFloat, keySpacing: CGFloat = 6,
                    rowSpacing: CGFloat = 7, inset: CGFloat = 18) -> KeyboardKey? {
        let rowIndex = Int((point.y - inset) / (unit + rowSpacing))
        guard rows.indices.contains(rowIndex) else { return nil }
        let rowTop = inset + CGFloat(rowIndex) * (unit + rowSpacing)
        guard point.y >= rowTop, point.y <= rowTop + unit else { return nil }
        var x = inset
        for item in rows[rowIndex] {
            switch item {
            case .gap(let width):
                x += unit * width + keySpacing
            case .key(let key):
                let width = unit * key.width + (key.width - 1) * keySpacing
                if point.x >= x, point.x <= x + width { return key }
                x += width + keySpacing
            }
        }
        return nil
    }

    private static func row(_ keys: [(String, Int, Double)], gaps: [Int: Double] = [:]) -> [KeyRowItem] {
        var result: [KeyRowItem] = []
        for (index, value) in keys.enumerated() {
            if let gap = gaps[index] { result.append(.gap(gap)) }
            result.append(.key(.init(label: value.0, led: value.1, width: value.2)))
        }
        return result
    }
}

struct F87Profile: Codable, Hashable, Sendable {
    var effect: Int
    var brightness: Int
    var speed: Int
    var colorful: Bool
    var color: RGBColor
    var perKey: [Int: RGBColor]
}

struct StoredProfile: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var profile: F87Profile
    var assignedBundleIdentifier: String?
    var assignedApplicationName: String?
    var modifiedAt: Date

    init(id: UUID = UUID(), name: String, profile: F87Profile,
         assignedBundleIdentifier: String? = nil, assignedApplicationName: String? = nil,
         modifiedAt: Date = .now) {
        self.id = id
        self.name = name
        self.profile = profile
        self.assignedBundleIdentifier = assignedBundleIdentifier
        self.assignedApplicationName = assignedApplicationName
        self.modifiedAt = modifiedAt
    }
}

enum PerKeyTool: String, CaseIterable, Identifiable, Sendable {
    case paint, erase, select, eyedropper
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .paint: return "paintbrush.fill"
        case .erase: return "eraser.fill"
        case .select: return "selection.pin.in.out"
        case .eyedropper: return "eyedropper"
        }
    }
}

enum GradientDirection: String, CaseIterable, Identifiable, Sendable {
    case horizontal, vertical, radial
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .horizontal: return "arrow.left.and.right"
        case .vertical: return "arrow.up.and.down"
        case .radial: return "circle.dotted"
        }
    }
}

struct KeyboardSnapshot: Sendable {
    let effect: Int
    let brightness: Int?
    let speed: Int?
    let colorful: Bool?
    let sleepMinutes: Int?
    let debounceMilliseconds: Int?
}

enum ConnectionState: Equatable {
    case searching
    case disconnected(String)
    case connected(String)
    case busy(String)
    case failed(String)

    var title: String {
        switch self {
        case .searching: return "Looking for keyboard…"
        case .disconnected: return "Not connected"
        case .connected(let name): return name
        case .busy(let action): return action
        case .failed: return "Connection needs attention"
        }
    }

    var detail: String? {
        switch self {
        case .disconnected(let message), .failed(let message): return message
        default: return nil
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
