import SwiftUI

struct EffectPreviewPanel: View {
    let effect: LightingEffect
    let color: RGBColor
    let brightness: Int
    let speed: Int
    let colorful: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(effect.name, systemImage: "keyboard")
                    .font(.title3.weight(.semibold))
                Spacer()
                Label("Live preview", systemImage: "eye.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(StudioUI.recessed, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            EffectKeyboardPreview(effect: effect, color: color, brightness: brightness,
                                  speed: speed, colorful: colorful)
                .frame(height: 284)

            HStack(spacing: 10) {
                Text(effect.previewDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Preview only")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .background(StudioUI.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(StudioUI.separator.opacity(0.46)))
    }
}

struct EffectKeyboardPreview: View {
    let effect: LightingEffect
    let color: RGBColor
    let brightness: Int
    let speed: Int
    let colorful: Bool
    private let unit: CGFloat = 33

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isAnimated)) { timeline in
            ScrollView(.horizontal) {
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, _ in
                    var y: CGFloat = 18
                    for (rowIndex, row) in F87Layout.rows.enumerated() {
                        var x: CGFloat = 18
                        for (column, item) in row.enumerated() {
                            switch item {
                            case .gap(let width):
                                x += unit * width
                            case .key(let key):
                                let width = unit * key.width + (key.width - 1) * 6
                                let rect = CGRect(x: x, y: y, width: width, height: unit)
                                let path = Path(roundedRect: rect, cornerRadius: 6)
                                context.fill(path, with: .color(keyColor(
                                    row: rowIndex, column: column, led: key.led, elapsed: elapsed
                                )))
                                context.stroke(path, with: .color(.white.opacity(0.20)), lineWidth: 1)
                                context.draw(
                                    Text(key.label)
                                        .font(.system(size: 9.5, weight: .medium))
                                        .foregroundColor(.white.opacity(effect.id == 0 || brightness == 0 ? 0.76 : 0.96)),
                                    at: CGPoint(x: rect.midX, y: rect.midY)
                                )
                                x += width
                            }
                            if column < row.count - 1 { x += 6 }
                        }
                        y += unit + 7
                    }
                }
                .frame(width: max(748, canvasWidth), height: canvasHeight)
                .background(StudioUI.keyboardDeck, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(StudioUI.separator))
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityLabel("Animated preview of the \(effect.name) keyboard lighting effect")
    }

    private var canvasWidth: CGFloat {
        let widestRow = F87Layout.rows.map { row in
            row.enumerated().reduce(CGFloat.zero) { partial, entry in
                let itemWidth: CGFloat
                switch entry.element {
                case .gap(let width): itemWidth = unit * width
                case .key(let key): itemWidth = unit * key.width + (key.width - 1) * 6
                }
                return partial + itemWidth + (entry.offset < row.count - 1 ? 6 : 0)
            }
        }.max() ?? 0
        return widestRow + 36
    }

    private var canvasHeight: CGFloat {
        CGFloat(F87Layout.rows.count) * unit + CGFloat(max(0, F87Layout.rows.count - 1)) * 7 + 36
    }

    private var isAnimated: Bool {
        effect.id != 0 && effect.id != 1 && brightness > 0
    }

    private func keyColor(row: Int, column: Int, led: Int, elapsed: TimeInterval) -> Color {
        guard effect.id != 0, brightness > 0 else { return Color(white: 0.13) }
        let x = Double(column) / 16.0
        let y = Double(row) / 5.0
        let rate = 0.35 + Double(speed) * 0.22
        let time = elapsed * rate
        let brightnessScale = 0.18 + Double(brightness) / 4.0 * 0.82
        let sourceHue = (Double(color.red) * 0.002 + Double(color.green) * 0.003 + Double(color.blue) * 0.001)
            .truncatingRemainder(dividingBy: 1)

        func palette(_ offset: Double = 0) -> Color {
            if colorful || !effect.supportsColor {
                return Color(hue: positive(x * 0.65 + y * 0.22 + time * 0.12 + offset),
                             saturation: 0.92, brightness: brightnessScale)
            }
            return color.color.opacity(brightnessScale)
        }

        var intensity = 1.0
        switch effect.id {
        case 1: // fixed
            intensity = 1
        case 2: // breathing
            intensity = 0.18 + 0.82 * (sin(time * 2.2) + 1) / 2
        case 3: // rainbow
            return Color(hue: positive(x * 0.72 + y * 0.16 - time * 0.22),
                         saturation: 0.94, brightness: brightnessScale)
        case 4: // flash away
            intensity = wave(distance(x, y, positive(time * 0.32), 0.5), time: time)
        case 5: // raindrops
            intensity = twinkle(seed: Double(led) * 1.73, time: time, sharpness: 8)
        case 7: // ripple
            intensity = wave(distance(x, y, 0.5, 0.5), time: time * 1.3)
        case 8: // starlight
            intensity = twinkle(seed: Double(led) * 2.91, time: time * 0.7, sharpness: 14)
        case 10: // snake
            let position = positive(time * 0.15) * 87
            let delta = abs(Double(led % 102) - position)
            intensity = max(0.10, 1 - min(delta, 87 - delta) / 11)
        case 11: // neon stream
            intensity = 0.22 + 0.78 * (sin((x + y - time * 0.48) * .pi * 3) + 1) / 2
        case 12: // reaction
            intensity = max(0.12, wave(distance(x, y, 0.52, 0.54), time: time * 1.7))
        case 13: // sine wave
            intensity = 0.12 + 0.88 * (sin((x * 2.2 + y - time * 0.65) * .pi * 2) + 1) / 2
        case 15: // windmill
            let angle = atan2(y - 0.5, x - 0.5) / (.pi * 2)
            return Color(hue: positive(angle + time * 0.18), saturation: 0.94, brightness: brightnessScale)
        case 16: // waterfall
            return Color(hue: positive(sourceHue + y * 0.45 - time * 0.18),
                         saturation: 0.90, brightness: brightnessScale)
        case 17: // blossoming
            return Color(hue: positive(distance(x, y, 0.5, 0.5) * 0.78 - time * 0.16),
                         saturation: 0.92, brightness: brightnessScale)
        default:
            intensity = 0.35 + 0.65 * (sin((x - time * 0.4) * .pi * 3) + 1) / 2
        }
        return palette(intensity * 0.08).opacity(max(0.06, min(1, intensity)))
    }

    private func positive(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder < 0 ? remainder + 1 : remainder
    }

    private func distance(_ x: Double, _ y: Double, _ cx: Double, _ cy: Double) -> Double {
        hypot(x - cx, y - cy)
    }

    private func wave(_ distance: Double, time: Double) -> Double {
        let phase = abs(sin((distance * 5.5 - time) * .pi))
        return pow(phase, 7)
    }

    private func twinkle(seed: Double, time: Double, sharpness: Double) -> Double {
        let noise = (sin(seed * 12.9898 + time * (0.9 + positive(seed) * 1.4)) + 1) / 2
        return 0.08 + 0.92 * pow(noise, sharpness)
    }
}

extension LightingEffect {
    var previewDescription: String {
        switch id {
        case 0: return "All keyboard lighting is turned off."
        case 1: return "A steady, even color across the keyboard."
        case 2: return "The keyboard gently fades in and out."
        case 3: return "A continuous spectrum travels across the keys."
        case 4: return "A bright pulse moves outward across the keyboard."
        case 5: return "Individual keys appear like falling drops."
        case 7: return "Concentric rings radiate from the center."
        case 8: return "Random keys glimmer like stars."
        case 10: return "A glowing trail travels from key to key."
        case 11: return "Bands of light stream diagonally across the keys."
        case 12: return "A quick expanding burst responds like a ripple."
        case 13: return "Smooth sine-shaped bands travel across the keyboard."
        case 15: return "Rainbow blades rotate around the keyboard center."
        case 16: return "Color pours downward in layered waves."
        case 17: return "Color expands outward from the center like a bloom."
        default: return "An animated representation of this onboard effect."
        }
    }
}
