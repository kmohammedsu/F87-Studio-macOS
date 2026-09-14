import SwiftUI

enum StudioUI {
    static let accent = Color.accentColor
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor).opacity(0.86)
    static let elevated = Color(nsColor: .textBackgroundColor).opacity(0.78)
    static let recessed = Color(nsColor: .underPageBackgroundColor)
    static let separator = Color(nsColor: .separatorColor)
    static let keyboardDeck = Color(nsColor: .underPageBackgroundColor)
    static let mutedAccent = Color.accentColor.opacity(0.11)
    static let keycapTop = Color(red: 0.23, green: 0.24, blue: 0.25)
    static let keycapBottom = Color(red: 0.105, green: 0.11, blue: 0.12)
}

/// A product-like shell shared by the interactive keyboard canvas. The RGB
/// belongs around the keycaps, while the caps themselves remain legible.
struct HardwareKeyboardBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // The darker lower shell stays visible beneath the aluminum top
                // plate and gives the keyboard a real front edge.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.21, green: 0.22, blue: 0.235))
                    .offset(y: 5)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.89, green: 0.90, blue: 0.91),
                                Color(red: 0.69, green: 0.71, blue: 0.73),
                                Color(red: 0.47, green: 0.49, blue: 0.52)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.bottom, 5)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [.white.opacity(0.82), .black.opacity(0.32)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
                    .padding(1)
                    .padding(.bottom, 5)

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.035, green: 0.038, blue: 0.043),
                                Color(red: 0.075, green: 0.08, blue: 0.087)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.top, 8)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.black.opacity(0.62), lineWidth: 2)
                            .padding(.top, 8)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 12)
                    }

                // A soft reflection across the rear edge makes the deck look
                // inset rather than printed onto a flat rectangle.
                LinearGradient(colors: [.white.opacity(0.24), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 7)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 12)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 9)

                VStack(spacing: 0) {
                    HStack {
                        HStack(spacing: 4) {
                            Text("F87")
                                .font(.system(size: 7.5, weight: .bold, design: .rounded))
                                .tracking(0.6)
                            Circle().fill(.green.opacity(0.90)).frame(width: 3, height: 3)
                        }
                        Spacer()
                        HStack(spacing: 3) {
                            Circle().fill(.white.opacity(0.45)).frame(width: 2.5, height: 2.5)
                            Circle().fill(.white.opacity(0.24)).frame(width: 2.5, height: 2.5)
                            Circle().fill(.white.opacity(0.24)).frame(width: 2.5, height: 2.5)
                        }
                    }
                    .foregroundStyle(.white.opacity(0.52))
                    .padding(.horizontal, 20)
                    .padding(.top, 5)
                    Spacer()
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .blue, .purple, .pink, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: min(230, proxy.size.width * 0.30), height: 2.5)
                        .overlay(Capsule().fill(.white.opacity(0.28)).frame(height: 0.7), alignment: .top)
                        .shadow(color: .cyan.opacity(0.62), radius: 4)
                        .padding(.bottom, 3)
                }
            }
            .shadow(color: .black.opacity(0.44), radius: 14, y: 9)
        }
        .allowsHitTesting(false)
    }
}

struct StudioCardModifier: ViewModifier {
    var radius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background(StudioUI.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(StudioUI.separator.opacity(0.46), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.055), radius: 9, y: 3)
    }
}

extension View {
    func studioCard(radius: CGFloat = 14) -> some View {
        modifier(StudioCardModifier(radius: radius))
    }
}

enum StudioSection: String, CaseIterable, Identifiable {
    case lighting, perKey, profiles, music, functionKeys, settings, help

    var id: String { rawValue }
    var title: String {
        switch self {
        case .lighting: return "Lighting"
        case .perKey: return "Per-key RGB"
        case .profiles: return "Profiles"
        case .music: return "Music mode"
        case .functionKeys: return "Mac function keys"
        case .settings: return "Keyboard settings"
        case .help: return "About & help"
        }
    }
    var icon: String {
        switch self {
        case .lighting: return "lightbulb.max.fill"
        case .perKey: return "keyboard.fill"
        case .profiles: return "square.stack.3d.up.fill"
        case .music: return "waveform"
        case .functionKeys: return "command.square.fill"
        case .settings: return "slider.horizontal.3"
        case .help: return "questionmark.circle.fill"
        }
    }
    var shortcut: KeyEquivalent {
        switch self {
        case .lighting: return "1"
        case .perKey: return "2"
        case .profiles: return "3"
        case .music: return "4"
        case .functionKeys: return "5"
        case .settings: return "6"
        case .help: return "7"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: StudioSection = .lighting

    var body: some View {
        VStack(spacing: 0) {
            if shouldShowConnectionBanner {
                ConnectionBanner()
            }
            ZStack(alignment: .top) {
                StudioBackground()
                Group {
                    switch selection {
                    case .perKey: PerKeyView()
                    case .profiles: ProfileLibraryView()
                    case .music: MusicModeView()
                    case .functionKeys: FunctionKeysView()
                    case .settings: SettingsView()
                    case .help: HelpView()
                    case .lighting: LightingView()
                    }
                }
                if let toast = model.toast {
                    Text(toast)
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(StudioUI.separator))
                        .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
                        .padding(.top, 14)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .clipped()
        }
        .frame(width: 1240, height: 800)
        .tint(.accentColor)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ConnectionStatusPill()
            }
            ToolbarItem(placement: .principal) {
                StudioSectionPicker(selection: $selection)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if model.hasUnappliedChanges {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.orange)
                        .help("Changes not applied")
                }
                Button { model.loadProfile() } label: { Label("Open Profile", systemImage: "folder") }
                Button { model.saveProfile() } label: { Label("Save Profile", systemImage: "square.and.arrow.down") }
            }
        }
    }

    private var shouldShowConnectionBanner: Bool {
        switch model.connectionState {
        case .disconnected, .failed: return true
        default: return false
        }
    }
}

private struct StudioSectionPicker: View {
    @Binding var selection: StudioSection

    var body: some View {
        HStack(spacing: 2) {
            ForEach(StudioSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: section.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(tabTitle(for: section))
                            .font(.system(size: 12, weight: selection == section ? .semibold : .medium))
                    }
                    .foregroundStyle(selection == section ? AnyShapeStyle(StudioUI.accent) : AnyShapeStyle(.secondary))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(selection == section ? StudioUI.mutedAccent : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(selection == section ? StudioUI.accent.opacity(0.22) : .clear,
                                    lineWidth: 1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(TactilePlainButtonStyle())
                .keyboardShortcut(section.shortcut, modifiers: .command)
                .help(section.title)
                .animation(.easeOut(duration: 0.14), value: selection)
            }
        }
        .padding(3)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(StudioUI.separator.opacity(0.48), lineWidth: 1)
        }
    }

    private func tabTitle(for section: StudioSection) -> String {
        switch section {
        case .music: return "Music"
        case .functionKeys: return "F-keys"
        case .settings: return "Settings"
        case .help: return "Help"
        default: return section.title
        }
    }
}

private struct ConnectionStatusPill: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button { model.scan() } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(model.connectionState.title)
                    .lineLimit(1)
                Image(systemName: "arrow.clockwise")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .foregroundStyle(model.connectionState.isConnected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(statusColor.opacity(0.09), in: Capsule())
            .overlay(Capsule().stroke(statusColor.opacity(0.20), lineWidth: 1))
        }
        .buttonStyle(TactilePlainButtonStyle())
        .help("Scan for the keyboard")
        .frame(maxWidth: 190, alignment: .leading)
    }

    private var statusColor: Color {
        if model.connectionState.isConnected { return .green }
        if case .busy = model.connectionState { return .orange }
        if case .searching = model.connectionState { return .orange }
        return .red
    }
}

private struct TactilePlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.06), value: configuration.isPressed)
    }
}

private struct StudioBackground: View {
    var body: some View {
        ZStack {
            StudioUI.canvas
            LinearGradient(
                colors: [StudioUI.accent.opacity(0.025), .clear, Color.purple.opacity(0.018)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

struct ConnectionBanner: View {
    @EnvironmentObject private var model: AppModel
    @State private var showsDiagnosis = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cable.connector.horizontal")
                .font(.body.weight(.semibold))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(advice.title)
                    .font(.callout.weight(.semibold))
                Text(advice.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button { model.copyCurrentError() } label: {
                Label("Copy Error", systemImage: "doc.on.doc")
            }
            Button { showsDiagnosis.toggle() } label: {
                Label("Diagnose", systemImage: "stethoscope")
            }
            .popover(isPresented: $showsDiagnosis, arrowEdge: .bottom) {
                DiagnosticAdviceView(advice: advice)
            }
            if model.connectionState.detail?.contains("Input Monitoring") == true {
                Button("Request Access") { model.requestInputMonitoring() }
            }
            Button("Scan again") { model.scan() }
                .buttonStyle(.borderedProminent)
        }
        .controlSize(.small)
        .padding(.horizontal, 20)
        .frame(minHeight: 62)
        .background(Color.orange.opacity(0.055))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var advice: DiagnosticAdvice {
        ConnectionDiagnostics.advice(for: model.connectionState.detail)
    }
}

struct PageHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 29, weight: .semibold))
                .tracking(-0.45)
            Text(subtitle)
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SidebarConnectionCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Circle()
                    .fill(model.connectionState.isConnected ? .green : (isBusy ? .orange : .red))
                    .frame(width: 9, height: 9)
                Text(model.connectionState.title).font(.caption.weight(.semibold)).lineLimit(2)
            }
            if let detail = model.connectionState.detail {
                Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(4)
            }
            HStack {
                Button("Scan again") { model.scan() }.controlSize(.small)
                if model.connectionState.detail != nil {
                    Button { model.copyCurrentError() } label: { Image(systemName: "doc.on.doc") }
                        .controlSize(.small)
                        .help("Copy error")
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioCard(radius: 10)
        .padding(10)
    }

    private var isBusy: Bool {
        if case .busy = model.connectionState { return true }
        if case .searching = model.connectionState { return true }
        return false
    }
}

struct LightingView: View {
    @EnvironmentObject private var model: AppModel
    private let effectColumns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom, spacing: 20) {
                PageHeader(eyebrow: "AULA F87", title: "Lighting Workbench",
                           subtitle: "Choose on the left. Inspect the keyboard on the right. Apply when it is ready.")
                Spacer()
                Label(model.hasUnappliedLightingChanges ? "Draft" : "Applied",
                      systemImage: model.hasUnappliedLightingChanges ? "pencil.line" : "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(model.hasUnappliedLightingChanges ? .orange : .green)
                    .padding(.horizontal, 11)
                    .frame(height: 28)
                    .background(StudioUI.recessed, in: Capsule())
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Onboard effects", systemImage: "lightspectrum.horizontal")
                            .font(.headline)
                        Spacer()
                        Text("\(model.availableEffectIDs.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    ScrollView {
                        LazyVGrid(columns: effectColumns, spacing: 7) {
                            ForEach(LightingEffect.all.filter { model.availableEffectIDs.contains($0.id) }) { effect in
                                EffectCard(effect: effect, selected: effect.id == model.selectedEffect) {
                                    model.selectedEffect = effect.id
                                    if !effect.supportsColor && effect.id != 0 { model.colorful = true }
                                }
                            }
                        }
                        .padding(.trailing, 2)
                    }
                    .frame(height: 230)
                    .scrollIndicators(.hidden)

                    Divider()
                    Label("Adjust", systemImage: "slider.horizontal.3")
                        .font(.headline)
                    LightingSlider(title: "Brightness", symbol: "sun.max.fill",
                                   value: Binding(get: { Double(model.brightness) },
                                                  set: { model.brightness = Int($0.rounded()) }),
                                   range: Double(model.minimumBrightness)...4,
                                   valueText: "\(model.brightness)")
                    LightingSlider(title: "Speed", symbol: "speedometer",
                                   value: Binding(get: { Double(model.speed) },
                                                  set: { model.speed = Int($0.rounded()) }),
                                   range: 0...4,
                                   valueText: "\(model.speed)",
                                   disabled: !model.selectedEffectInfo.supportsSpeed)
                    HStack(spacing: 10) {
                        ColorPicker("Color", selection: Binding(
                            get: { model.selectedColor.color },
                            set: { model.selectedColor = RGBColor(color: $0) }
                        ))
                        .disabled(!model.selectedEffectInfo.supportsColor || model.colorful)
                        Spacer()
                        Toggle("Spectrum", isOn: $model.colorful)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .disabled(!model.selectedEffectInfo.supportsColor)
                    }

                    Button { model.applyEffect() } label: {
                        Label(model.selectedEffect == 0 ? "Turn Keyboard Lights Off" : "Apply to Keyboard",
                              systemImage: "arrow.down.to.line.compact")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!model.connectionState.isConnected || !model.hasUnappliedLightingChanges)
                }
                .padding(16)
                .frame(width: 326)
                .studioCard(radius: 14)

                VStack(alignment: .leading, spacing: 14) {
                    EffectPreviewPanel(effect: model.selectedEffectInfo, color: model.selectedColor,
                                       brightness: model.brightness, speed: model.speed,
                                       colorful: model.colorful)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: 1180, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 30)
        .padding(.vertical, 24)
    }
}

private struct LightingSlider: View {
    let title: String
    let symbol: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueText: String
    var disabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 9) {
                Slider(value: $value, in: range, step: 1)
                    .disabled(disabled)
                Text(valueText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LightingApplyBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: model.hasUnappliedLightingChanges ? "eye.fill" : "checkmark.circle.fill")
                .font(.body)
                .foregroundStyle(model.hasUnappliedLightingChanges ? .orange : .green)
                .scaleEffect(model.hasUnappliedLightingChanges ? 1.08 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.hasUnappliedLightingChanges ? "Previewing \(model.selectedEffectInfo.name)" : "Lighting is up to date")
                    .font(.callout.weight(.semibold))
                Text(model.hasUnappliedLightingChanges ? "Press Apply to send this look to the keyboard." : "The preview matches your keyboard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Revert") { model.revertDraft() }
                .disabled(!model.hasUnappliedChanges)
            Button { model.applyEffect() } label: {
                Label(applyTitle, systemImage: model.selectedEffect == 0 ? "lightbulb.slash.fill" : "lightbulb.max.fill")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.connectionState.isConnected || !model.hasUnappliedLightingChanges)
        }
        .padding(.horizontal, 28)
        .frame(height: 64)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .animation(.easeOut(duration: 0.14), value: model.hasUnappliedLightingChanges)
    }

    private var applyTitle: String {
        model.selectedEffect == 0 ? "Apply Lights Off" : "Apply to Keyboard"
    }
}

struct EffectCard: View {
    let effect: LightingEffect
    let selected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? StudioUI.accent : .secondary)
                    .frame(width: 16)
                Text(effect.name)
                    .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(StudioUI.accent)
                }
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .background(selected ? StudioUI.mutedAccent : (isHovering ? StudioUI.recessed : StudioUI.surface),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(selected ? StudioUI.accent.opacity(0.38) : StudioUI.separator.opacity(0.42)))
        }
        .buttonStyle(TactilePlainButtonStyle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.10), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: selected)
    }

    private var icon: String {
        switch effect.id {
        case 0: return "moon.zzz.fill"
        case 1: return "sun.max.fill"
        case 2: return "waveform.path"
        case 3, 6, 15, 16, 17: return "rainbow"
        case 5, 8: return "sparkles"
        case 7, 12: return "dot.radiowaves.left.and.right"
        default: return "lightspectrum.horizontal"
        }
    }
}

struct PerKeyView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isPaintingStroke = false
    @State private var showsSaveProfile = false
    @State private var profileName = "My RGB Layout"
    private let unit: CGFloat = 37
    private let swatches: [RGBColor] = [
        .init(red: 255, green: 70, blue: 80), .init(red: 255, green: 150, blue: 45),
        .init(red: 255, green: 224, blue: 65), .init(red: 60, green: 220, blue: 130),
        .init(red: 64, green: 200, blue: 255), .init(red: 100, green: 105, blue: 255),
        .init(red: 215, green: 75, blue: 255), .init(red: 255, green: 255, blue: 255)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom) {
                PageHeader(eyebrow: "Editor", title: "Per-key Workbench",
                           subtitle: "Paint, select, and build gradients while the full F87 remains in view.")
                Spacer()
                Text("\(model.perKeyColors.count) painted · \(model.selectedLEDs.count) selected")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Tools", systemImage: "paintbrush.pointed.fill")
                            .font(.headline)
                        Spacer()
                        Button { model.undoPerKey() } label: { Image(systemName: "arrow.uturn.backward") }
                            .disabled(!model.canUndo)
                            .help("Undo")
                        Button { model.redoPerKey() } label: { Image(systemName: "arrow.uturn.forward") }
                            .disabled(!model.canRedo)
                            .help("Redo")
                    }

                    Picker("Tool", selection: $model.perKeyTool) {
                        ForEach(PerKeyTool.allCases) { tool in
                            Label(tool.title, systemImage: tool.symbol).tag(tool)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    HStack(spacing: 10) {
                        ColorPicker("Brush color",
                                    selection: Binding(get: { model.selectedColor.color },
                                                       set: { model.selectedColor = RGBColor(color: $0) }))
                            .disabled(model.perKeyTool == .erase || model.perKeyTool == .select)
                        Spacer()
                        Text(model.selectedColor.hex)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 5) {
                        ForEach(swatches, id: \.self) { swatch in
                            Button { model.selectedColor = swatch; model.perKeyTool = .paint } label: {
                                Circle()
                                    .fill(swatch.color)
                                    .frame(width: 18, height: 18)
                                    .overlay(Circle().stroke(.white, lineWidth: model.selectedColor == swatch && model.perKeyTool == .paint ? 2 : 0))
                                    .padding(2)
                            }
                            .buttonStyle(.plain)
                            .help(swatch.hex)
                        }
                    }

                    Divider()

                    Text("Quick designs")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 7) {
                        InspectorButton(title: "Spectrum", symbol: "rainbow", action: model.fillSpectrum)
                        InspectorButton(title: "Rows", symbol: "rectangle.split.3x1.fill", action: model.fillRows)
                        InspectorButton(title: "Gaming", symbol: "gamecontroller.fill", action: model.fillGamingKeys)
                        InspectorButton(title: "Fill all", symbol: "paintbrush.fill", action: model.fillAll)
                    }

                    Divider()

                    HStack {
                        Menu {
                            Button("WASD") { model.selectGroup("wasd") }
                            Button("Arrow keys") { model.selectGroup("arrows") }
                            Button("Function row") { model.selectGroup("function") }
                            Button("Number row") { model.selectGroup("numbers") }
                            Button("Modifiers") { model.selectGroup("modifiers") }
                            Divider()
                            Button("All keys") { model.selectAllKeys() }
                        } label: {
                            Label("Select group", systemImage: "selection.pin.in.out")
                        }
                        Spacer()
                        Button("Clear") { model.clearSelection() }
                            .disabled(model.selectedLEDs.isEmpty)
                    }

                    HStack(spacing: 8) {
                        ColorPicker("End color", selection: Binding(
                            get: { model.gradientEndColor.color },
                            set: { model.gradientEndColor = RGBColor(color: $0) }
                        ))
                        Picker("Direction", selection: $model.gradientDirection) {
                            ForEach(GradientDirection.allCases) { direction in
                                Label(direction.title, systemImage: direction.symbol).tag(direction)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 95)
                        Button("Apply") { model.applyGradient() }
                            .disabled(model.selectedLEDs.isEmpty)
                    }

                    Divider()

                    HStack {
                        Button(role: .destructive) { model.clearAll() } label: {
                            Label("Clear", systemImage: "trash")
                        }
                        Spacer()
                        Button("Revert") { model.revertDraft() }
                            .disabled(!model.hasUnappliedChanges)
                        Button { showsSaveProfile = true } label: {
                            Label("Save", systemImage: "plus")
                        }
                    }

                    Button { model.applyPerKey() } label: {
                        Label("Apply to Keyboard", systemImage: "arrow.down.to.line.compact")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!model.connectionState.isConnected || !model.hasUnappliedPerKeyChanges)
                }
                .padding(16)
                .frame(width: 300)
                .studioCard(radius: 14)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("F87 canvas", systemImage: "keyboard")
                            .font(.headline)
                        Spacer()
                        Label(model.perKeyTool.title, systemImage: model.perKeyTool.symbol)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(Array(F87Layout.rows.enumerated()), id: \.offset) { _, row in
                                HStack(spacing: 6) {
                                    ForEach(Array(row.enumerated()), id: \.offset) { _, item in
                                        switch item {
                                        case .gap(let width): Color.clear.frame(width: unit * width, height: unit)
                                        case .key(let key): KeyboardKeyButton(key: key, unit: unit)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(18)
                        .background { HardwareKeyboardBackdrop() }
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if !isPaintingStroke {
                                        isPaintingStroke = true
                                        model.beginPaintStroke()
                                    }
                                    if let key = F87Layout.key(at: value.location, unit: unit) {
                                        model.continuePaintStroke(key: key)
                                    }
                                }
                                .onEnded { _ in
                                    isPaintingStroke = false
                                    model.endPaintStroke()
                                }
                        )
                    }
                    .scrollIndicators(.hidden)
                    .frame(height: CGFloat(F87Layout.rows.count) * unit
                           + CGFloat(max(0, F87Layout.rows.count - 1)) * 7 + 36)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .top)
                .studioCard(radius: 14)
            }
        }
        .frame(maxWidth: 1180, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 30)
        .padding(.vertical, 24)
        .alert("Save profile", isPresented: $showsSaveProfile) {
            TextField("Profile name", text: $profileName)
            Button("Cancel", role: .cancel) { }
            Button("Save") { model.saveDraftToLibrary(name: profileName) }
        } message: {
            Text("Save the current effect and per-key layout to your profile library.")
        }
    }
}

private struct InspectorButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
    }
}

struct KeyboardKeyButton: View {
    @EnvironmentObject private var model: AppModel
    @State private var isHovering = false
    let key: KeyboardKey
    let unit: CGFloat

    var body: some View {
        Button { model.paint(key: key) } label: {
            ZStack {
                if let assigned {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(assigned.color.opacity(0.92))
                        .padding(1)
                        .shadow(color: assigned.color.opacity(0.85), radius: 4)
                }

                // Sidewall: deliberately visible below the smaller top face.
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.15, green: 0.155, blue: 0.165),
                                     Color(red: 0.045, green: 0.048, blue: 0.052)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.horizontal, 2)
                    .padding(.top, 3)
                    .padding(.bottom, 1)
                    .shadow(color: .black.opacity(0.80), radius: 2, y: 2)

                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.32, green: 0.325, blue: 0.335),
                                     StudioUI.keycapTop,
                                     StudioUI.keycapBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        if let assigned {
                            RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                                .fill(assigned.color.opacity(0.18))
                        }
                    }
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(.white.opacity(0.29), lineWidth: 0.8)
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, 1)
                    .padding(.bottom, 5)
                    .shadow(color: .black.opacity(0.50), radius: 1, y: 1)

                Text(key.label)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(textColor)
                    .offset(y: -1.5)
                    .shadow(color: .black.opacity(0.75), radius: 0.5, y: 1)
            }
            .frame(width: keyWidth, height: unit)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(strokeColor,
                            lineWidth: model.selectedLEDs.contains(key.led) ? 2.5 : (isHovering ? 2 : 0.75))
            }
        }
        .buttonStyle(.plain)
        .help("\(model.perKeyTool.title) \(key.label) · LED \(key.led) · Shift-click to select")
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }

    private var assigned: RGBColor? { model.perKeyColors[key.led] }
    private var keyWidth: CGFloat { unit * key.width + (key.width - 1) * 6 }
    private var strokeColor: Color {
        if model.selectedLEDs.contains(key.led) { return .yellow }
        if isHovering { return StudioUI.accent }
        return assigned?.color.opacity(0.72) ?? .white.opacity(0.13)
    }
    private var textColor: Color {
        assigned == nil ? .white.opacity(0.80) : .white.opacity(0.96)
    }
}

struct ProfileLibraryView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: ProfileStore
    @State private var showsNewProfile = false
    @State private var newProfileName = "New Profile"
    @State private var renameID: UUID?
    @State private var renameText = ""
    @State private var deleteID: UUID?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    PageHeader(eyebrow: "Library", title: "Profiles",
                               subtitle: "Save complete lighting setups and switch between them without managing files.")
                    Button { showsNewProfile = true } label: { Label("Save Current", systemImage: "plus") }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }

                HStack {
                    Toggle("Automatically apply assigned profiles", isOn: $model.automaticProfilesEnabled)
                    Spacer()
                    if let app = model.activeApplicationName {
                        Label("Last app: \(app)", systemImage: "app.fill")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .studioCard()

                if store.profiles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.up")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("No profiles yet").font(.title3.weight(.semibold))
                        Text("Create a lighting design, then save the current setup here.")
                            .foregroundStyle(.secondary)
                    }
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(store.profiles.enumerated()), id: \.element.id) { index, stored in
                            ProfileCard(stored: stored,
                                        load: { model.loadLibraryProfile(stored.id) },
                                        apply: { model.applyLibraryProfile(stored.id) },
                                        update: { model.updateLibraryProfile(stored.id) },
                                        duplicate: { store.duplicate(stored.id) },
                                        rename: { renameID = stored.id; renameText = stored.name },
                                        assign: { model.assignProfileToFrontmostApp(stored.id) },
                                        unassign: { model.removeAppAssignment(stored.id) },
                                        delete: { deleteID = stored.id })
                            if index < store.profiles.count - 1 {
                                Divider().padding(.leading, 240)
                            }
                        }
                    }
                    .studioCard(radius: 12)
                }

                if let error = store.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity)
            .padding(30)
        }
        .alert("Save current setup", isPresented: $showsNewProfile) {
            TextField("Profile name", text: $newProfileName)
            Button("Cancel", role: .cancel) { }
            Button("Save") { model.saveDraftToLibrary(name: newProfileName) }
        }
        .alert("Rename profile", isPresented: Binding(
            get: { renameID != nil }, set: { if !$0 { renameID = nil } }
        )) {
            TextField("Profile name", text: $renameText)
            Button("Cancel", role: .cancel) { renameID = nil }
            Button("Rename") {
                if let renameID { store.rename(renameID, to: renameText) }
                renameID = nil
            }
        }
        .alert("Delete this profile?", isPresented: Binding(
            get: { deleteID != nil }, set: { if !$0 { deleteID = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleteID = nil }
            Button("Delete", role: .destructive) {
                if let deleteID { store.remove(deleteID) }
                deleteID = nil
            }
        } message: {
            Text("This removes the profile from the local library. It does not change the keyboard.")
        }
    }
}

private struct ProfileCard: View {
    let stored: StoredProfile
    let load: () -> Void
    let apply: () -> Void
    let update: () -> Void
    let duplicate: () -> Void
    let rename: () -> Void
    let assign: () -> Void
    let unassign: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            ProfileThumbnail(profile: stored.profile)
                .frame(width: 210, height: 78)
            VStack(alignment: .leading, spacing: 5) {
                Text(stored.name).font(.headline).lineLimit(1)
                Text(summary).font(.caption).foregroundStyle(.secondary)
                if let app = stored.assignedApplicationName {
                    Label("Opens with \(app)", systemImage: "bolt.fill")
                        .font(.caption)
                        .foregroundStyle(StudioUI.accent)
                }
            }
            Spacer()
            Button("Load", action: load)
            Button("Apply", action: apply)
                .buttonStyle(.borderedProminent)
            Menu { menu } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
        }
        .padding(14)
    }

    @ViewBuilder private var menu: some View {
        Button("Update from current setup", action: update)
        Button("Rename", action: rename)
        Button("Duplicate", action: duplicate)
        Divider()
        Button("Assign to last active app", action: assign)
        if stored.assignedBundleIdentifier != nil {
            Button("Remove automatic assignment", action: unassign)
        }
        Divider()
        Button("Delete", role: .destructive, action: delete)
    }

    private var summary: String {
        if stored.profile.perKey.isEmpty {
            return LightingEffect.all.first(where: { $0.id == stored.profile.effect })?.name ?? "Lighting effect"
        }
        return "\(stored.profile.perKey.count) per-key colors"
    }
}

private struct ProfileThumbnail: View {
    let profile: F87Profile

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let columns = 16
                let rows = 6
                let gap: CGFloat = 3
                let width = (size.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
                let height = (size.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
                let colors = profile.perKey.isEmpty
                    ? [profile.color]
                    : profile.perKey.sorted(by: { $0.key < $1.key }).map(\.value)
                for row in 0..<rows {
                    for column in 0..<columns {
                        let index = row * columns + column
                        let color: Color
                        if profile.perKey.isEmpty && profile.colorful {
                            color = Color(hue: Double(column) / Double(columns), saturation: 0.9, brightness: 0.9)
                        } else {
                            color = colors[index % max(1, colors.count)].color
                        }
                        let rect = CGRect(x: CGFloat(column) * (width + gap), y: CGFloat(row) * (height + gap),
                                          width: width, height: height)
                        context.fill(Path(roundedRect: rect, cornerRadius: 2.5),
                                     with: .color(profile.effect == 0 && profile.perKey.isEmpty ? Color(white: 0.12) : color))
                    }
                }
            }
        }
        .padding(10)
        .background(StudioUI.recessed, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(StudioUI.separator.opacity(0.7)))
    }
}

struct MusicModeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(eyebrow: "Live lighting", title: "Audio visualizer",
                           subtitle: "Stream an 11-band visualization from the Mac microphone to the keyboard.")

                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label(model.isMusicReactive ? "Listening and streaming" : "Ready when you are",
                              systemImage: model.isMusicReactive ? "waveform.circle.fill" : "waveform.circle")
                            .font(.headline)
                            .foregroundStyle(model.isMusicReactive ? .green : .primary)
                        Spacer()
                        Text("15 FPS · receiver protocol 0x88")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    MusicSpectrumView(levels: model.audioLevels, color: model.musicColor)
                        .frame(height: 190)

                    HStack(spacing: 22) {
                        ColorPicker("Lighting color", selection: Binding(
                            get: { model.musicColor.color },
                            set: { model.musicColor = RGBColor(color: $0) }
                        ))
                        LabeledContent("Sensitivity") {
                            Slider(value: $model.musicSensitivity, in: 0.6...2.5)
                                .frame(width: 210)
                            Text(model.musicSensitivity.formatted(.number.precision(.fractionLength(1))))
                                .monospacedDigit().frame(width: 30)
                        }
                        Spacer()
                        if model.isMusicReactive {
                            Button("Stop", role: .destructive) { model.stopMusicMode() }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                        } else {
                            Button("Start Music Mode") { model.startMusicMode() }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .disabled(!model.connectionState.isConnected || !model.supportsMusicReactive)
                        }
                    }
                }
                .padding(18)
                .studioCard()

                Label("Music mode uses the Mac microphone only to calculate frequency levels in memory. Audio is not recorded, saved, or transmitted. The app must remain running while this live mode is active.",
                      systemImage: "mic.and.signal.meter.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .background(StudioUI.recessed, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                Text("Hardware capabilities").font(.title3.weight(.semibold))
                VStack(spacing: 0) {
                    CapabilityStatusRow(title: "Music-reactive streaming", symbol: "waveform",
                                        status: model.supportsMusicReactive ? "Verified on this connection" : "Requires the 20-byte receiver connection",
                                        available: model.supportsMusicReactive)
                    Divider().padding(.leading, 58)
                    CapabilityStatusRow(title: "Battery telemetry", symbol: "battery.50",
                                        status: "Not exposed by the verified F87 configuration protocol", available: false)
                    Divider().padding(.leading, 58)
                    CapabilityStatusRow(title: "Side-light control", symbol: "light.beacon.max.fill",
                                        status: "No validated 3554:FA09 packets available; keyboard shortcuts remain the safe control", available: false)
                    Divider().padding(.leading, 58)
                    CapabilityStatusRow(title: "Mac function row & macros", symbol: "command.square.fill",
                                        status: model.functionRowController.isRunning ? "Active through the safe host-side mapper" : "Available in Mac function keys",
                                        available: model.functionRowController.isRunning)
                }
                .studioCard(radius: 12)
            }
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity)
            .padding(30)
        }
    }
}

private struct MusicSpectrumView: View {
    let levels: [Double]
    let color: RGBColor

    var body: some View {
        HStack(alignment: .bottom, spacing: 9) {
            ForEach(0..<11, id: \.self) { index in
                let level = levels.indices.contains(index) ? levels[index] : 0
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.color)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(8, 175 * level))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
        .padding(14)
        .background(StudioUI.recessed, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct CapabilityStatusRow: View {
    let title: String
    let symbol: String
    let status: String
    let available: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(available ? .green : .secondary)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(status).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: available ? "checkmark.circle.fill" : "lock.fill")
                .foregroundStyle(available ? .green : .secondary)
        }
        .padding(14)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmsFactoryReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(eyebrow: "Device", title: "Keyboard",
                           subtitle: "Manage connection behavior and supported onboard settings.")

                ConnectionHealthView()

                VStack(spacing: 0) {
                    SettingCard(icon: "powersleep", title: "Sleep timer",
                                detail: model.supportsTimingSettings ? "Turn the lighting off after the keyboard is idle. Set 0 to disable." : "Not yet available for this wired firmware revision.",
                                information: "The sleep timer saves battery by turning the RGB lighting off after a period without key presses. It does not disconnect the keyboard. Pressing any key wakes the lighting immediately. Choose Off if you want the lights to remain on continuously.") {
                        Stepper("\(model.sleepMinutes == 0 ? "Off" : "\(model.sleepMinutes) minutes")",
                                value: $model.sleepMinutes, in: 0...60)
                        Button("Apply") { model.applySleep() }.buttonStyle(.borderedProminent)
                            .disabled(!model.connectionState.isConnected || !model.supportsTimingSettings)
                    }
                    Divider().padding(.leading, 60)
                    SettingCard(icon: "bolt.horizontal.fill", title: "Debounce",
                                detail: model.supportsTimingSettings ? "Lower values react sooner; 3 ms is a safe everyday setting." : "Not yet available for this wired firmware revision.",
                                information: "Debounce prevents one physical key press from being registered more than once while a mechanical switch settles. Lower values reduce latency but may expose chatter on worn switches. Three milliseconds is the recommended everyday setting.") {
                        Picker("Debounce", selection: $model.debounceMilliseconds) {
                            ForEach(1...5, id: \.self) { Text("\($0) ms").tag($0) }
                        }.labelsHidden().frame(width: 110)
                        Button("Apply") { model.applyDebounce() }.buttonStyle(.borderedProminent)
                            .disabled(!model.connectionState.isConnected || !model.supportsTimingSettings)
                    }
                    Divider().padding(.leading, 60)
                    SettingCard(icon: "arrow.counterclockwise", title: "Factory lighting reset",
                                detail: model.supportsFactoryReset ? "Restore the captured OEM lighting, timing, and color defaults." : "Not available on this connection protocol.",
                                information: "Restores the verified AULA defaults for lighting, per-key colors, sleep, and debounce. It does not change normal typing behavior or key assignments. Use this if an RGB configuration looks wrong or you want a clean starting point.") {
                        Button("Restore Defaults", role: .destructive) { confirmsFactoryReset = true }
                            .disabled(!model.connectionState.isConnected || !model.supportsFactoryReset)
                    }
                }
                .studioCard(radius: 12)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Activity", systemImage: "text.alignleft")
                            .font(.headline)
                        SettingInfoButton(title: "Activity log", text: "Shows connection scans, settings sent to the keyboard, confirmations, and readable error details. F87 Studio never logs your keystrokes or the text you type.")
                        Spacer()
                        Button { model.copyDiagnosticReport() } label: {
                            Label("Copy diagnostic report", systemImage: "doc.on.doc")
                        }
                    }
                    Divider()
                    ScrollView {
                        Text(model.activityLog.joined(separator: "\n"))
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 130)
                }
                .padding(16)
                .studioCard(radius: 12)
            }
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity)
            .padding(30)
        }
        .alert("Restore factory lighting settings?", isPresented: $confirmsFactoryReset) {
            Button("Cancel", role: .cancel) { }
            Button("Restore", role: .destructive) { model.factoryReset() }
        } message: {
            Text("This replaces saved lighting, per-key colors, sleep, and debounce settings on the keyboard. Key assignments are not changed.")
        }
    }
}

struct FunctionKeysView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    eyebrow: "Host controls",
                    title: "Mac function keys",
                    subtitle: "Turn F1–F12 into MacBook-style controls and useful shortcuts without changing the keyboard firmware."
                )
                FunctionRowSettingsView(controller: model.functionRowController)
            }
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity)
            .padding(30)
        }
    }
}

private struct FunctionRowSettingsView: View {
    @ObservedObject var controller: FunctionRowController
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.system(size: 20))
                    .foregroundStyle(StudioUI.accent)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text("Mac function row & macros").font(.headline)
                        SettingInfoButton(
                            title: "Mac function row",
                            text: "F87 Studio intercepts unmodified F1–F12 presses and performs your chosen Mac action while the app is running. The mappings are host-side and never overwrite the keyboard firmware. Modifier shortcuts continue to pass through normally."
                        )
                    }
                    Text("Give the F87 MacBook-style controls without writing unsafe onboard macro tables.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                    Text(controller.statusTitle).font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(StudioUI.recessed, in: Capsule())
                Toggle("Enabled", isOn: $controller.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            if controller.isEnabled && !controller.isRunning {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "accessibility.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(controller.accessibilityGranted ? "Accessibility granted — listener not active" : "Accessibility permission is required")
                                .font(.callout.weight(.semibold))
                            Text(controller.activationError ?? "It lets F87 Studio replace an F-key press with the selected Mac action. Keystrokes are not recorded or saved.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if controller.accessibilityGranted {
                            Button("Review Access") { _ = controller.requestAccess() }
                            Button("Relaunch F87 Studio") { controller.relaunch() }
                                .buttonStyle(.borderedProminent)
                        } else {
                            Button("Allow Access") { _ = controller.requestAccess() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    HStack(spacing: 16) {
                        PermissionStateLabel(title: "Accessibility", granted: controller.accessibilityGranted)
                        PermissionStateLabel(title: "Listen", granted: controller.listenAccessGranted)
                        PermissionStateLabel(title: "Post actions", granted: controller.postAccessGranted)
                        PermissionStateLabel(title: "Listener", granted: controller.isRunning)
                        Spacer()
                        Button("Check again") { controller.refreshAfterPermissionChange() }
                            .buttonStyle(.borderless)
                    }
                }
                .padding(13)
                .background(.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(.orange.opacity(0.20)))
            }

            if !controller.bundleExists {
                Label("The running app was moved or deleted. Reinstall it in Applications before relaunching.", systemImage: "externaldrive.badge.exclamationmark")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.green)
                    .frame(width: 34, height: 34)
                    .background(.green.opacity(0.11), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("2.4 GHz always-on mode").font(.callout.weight(.semibold))
                    Text("Function-row macros use normal macOS key events, so they do not depend on the RGB control connection.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if controller.launchAtLoginNeedsApproval {
                    Button("Approve in Login Items") { controller.openLoginItemsSettings() }
                }
                Toggle("Launch F87 Studio at login", isOn: Binding(
                    get: { controller.launchAtLoginEnabled },
                    set: { controller.setLaunchAtLogin($0) }
                ))
                .toggleStyle(.switch)
            }
            .padding(13)
            .background(.green.opacity(0.055), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(.green.opacity(0.13)))

            HStack(spacing: 12) {
                Image(systemName: "display")
                    .foregroundStyle(StudioUI.accent)
                    .frame(width: 34, height: 34)
                    .background(StudioUI.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Pointer-targeted display brightness").font(.callout.weight(.semibold))
                        SettingInfoButton(
                            title: "Brightness follows the pointer",
                            text: "F1/F2 control the display containing the mouse pointer. On the MacBook display, F87 Studio uses native brightness. On an HDMI or DisplayPort monitor, it uses universal software dimming. External dimming changes perceived brightness, not the monitor's physical backlight or power use."
                        )
                    }
                    Text(controller.externalDisplayStatus)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "sun.min.fill").foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { controller.externalDisplayBrightness },
                    set: { controller.setExternalDisplayBrightness($0) }
                ), in: 0.2...1, step: 0.05)
                .frame(width: 180)
                .disabled(!controller.pointerTargetsExternalDisplay)
                Text("\(Int(controller.externalDisplayBrightness * 100))%")
                    .font(.caption.monospacedDigit()).frame(width: 38, alignment: .trailing)
                Button { controller.refreshExternalDisplays() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Update the display under the pointer")
            }
            .padding(13)
            .background(StudioUI.recessed, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudioUI.separator.opacity(0.7)))

            if let error = controller.launchAtLoginError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1...12, id: \.self) { functionKey in
                    HStack(spacing: 10) {
                        Text("F\(functionKey)")
                            .font(.system(.callout, design: .monospaced).weight(.semibold))
                            .frame(width: 30, height: 30)
                            .background(StudioUI.recessed, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Picker("F\(functionKey)", selection: assignmentBinding(for: functionKey)) {
                            ForEach(MacFunctionAction.allCases) { action in
                                Label(action.title, systemImage: action.symbol).tag(action)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Button { controller.testFunctionKey(functionKey) } label: {
                            Image(systemName: "play.circle.fill")
                                .foregroundStyle(StudioUI.accent)
                        }
                        .buttonStyle(.borderless)
                        .help("Test F\(functionKey) action")
                        .disabled(!controller.isRunning || [.standard, .nothing].contains(controller.assignment(for: functionKey)))
                    }
                    .padding(10)
                    .background(StudioUI.recessed, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudioUI.separator.opacity(0.55)))
                }
            }
            .disabled(!controller.isEnabled)

            HStack {
                Label("Set a key to Standard F-key to pass it through. Holding a modifier also preserves normal app shortcuts.",
                      systemImage: "command")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let lastTriggered = controller.lastTriggered {
                    Label(lastTriggered, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
                Button("Test F1") { controller.testFunctionKey(1) }
                    .disabled(!controller.isRunning || [.standard, .nothing].contains(controller.assignment(for: 1)))
                Button("MacBook Defaults") { controller.resetDefaults() }
            }
        }
        .padding(18)
        .studioCard()
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            controller.refreshAfterPermissionChange()
        }
    }

    private var statusColor: Color {
        if controller.isRunning { return .green }
        return controller.isEnabled ? .orange : .secondary
    }

    private func assignmentBinding(for functionKey: Int) -> Binding<MacFunctionAction> {
        Binding(
            get: { controller.assignment(for: functionKey) },
            set: { controller.setAssignment($0, for: functionKey) }
        )
    }
}

private struct PermissionStateLabel: View {
    let title: String
    let granted: Bool

    var body: some View {
        Label(title, systemImage: granted ? "checkmark.circle.fill" : "circle")
            .font(.caption2.weight(.medium))
            .foregroundStyle(granted ? .green : .secondary)
    }
}

private struct ConnectionHealthView: View {
    @EnvironmentObject private var model: AppModel
    private var installedInApplications: Bool {
        Bundle.main.bundleURL.path.hasPrefix("/Applications/")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Connection health", systemImage: "heart.text.square.fill")
                    .font(.headline)
                Spacer()
                Text("Automatic reconnect every 7 seconds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HealthCheckRow(title: "Applications copy", passed: installedInApplications,
                           detail: installedInApplications ? "Running from /Applications" : "Move F87 Studio to Applications")
            HealthCheckRow(title: "Input Monitoring", passed: KeyboardService.hasInputMonitoringAccess,
                           detail: KeyboardService.hasInputMonitoringAccess ? "Reported as granted" : "macOS has not granted HID access")
            HealthCheckRow(title: "Accessibility macros",
                           passed: !model.functionRowController.isEnabled || model.functionRowController.isRunning,
                           detail: model.functionRowController.isEnabled
                            ? (model.functionRowController.isRunning ? "Function-key listener active" : model.functionRowController.statusTitle)
                            : "Not needed while the Mac function row is off")
            HealthCheckRow(title: "Keyboard control channel", passed: model.connectionState.isConnected,
                           detail: model.connectionState.title)
            HealthCheckRow(title: "Protocol verification", passed: model.connectionState.isConnected,
                           detail: model.connectionState.isConnected ? "Configuration read and checksum passed" : "Waiting for a successful scan")
            HStack {
                Button("Open Input Monitoring") { model.openInputMonitoring() }
                Button("Copy diagnostic report") { model.copyDiagnosticReport() }
                Spacer()
                Button("Run connection check") { model.scan() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .studioCard()
    }
}

private struct HealthCheckRow: View {
    let title: String
    let passed: Bool
    let detail: String

    var body: some View {
        HStack {
            Image(systemName: passed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(passed ? .green : .orange)
            Text(title).font(.callout.weight(.semibold)).frame(width: 160, alignment: .leading)
            Text(detail).font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
    }
}

struct SettingCard<Content: View>: View {
    let icon: String
    let title: String
    let detail: String
    let information: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(StudioUI.accent)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title).font(.headline)
                    SettingInfoButton(title: title, text: information)
                }
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 12) { content }
        }
        .padding(16)
    }
}

struct SettingInfoButton: View {
    let title: String
    let text: String
    @State private var isPresented = false

    var body: some View {
        Button { isPresented.toggle() } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Learn about \(title)")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: "info.circle.fill")
                    .font(.headline)
                    .foregroundStyle(StudioUI.accent)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(width: 330, alignment: .leading)
        }
    }
}

struct DiagnosticAdviceView: View {
    @EnvironmentObject private var model: AppModel
    let advice: DiagnosticAdvice

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(advice.title, systemImage: advice.symbol)
                .font(.headline)
                .foregroundStyle(.orange)
            Text(advice.explanation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(advice.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 9) {
                        Text("\(index + 1)")
                            .font(.caption2.bold())
                            .frame(width: 20, height: 20)
                            .background(.orange.opacity(0.16), in: Circle())
                        Text(step).font(.callout)
                    }
                }
            }
            Divider()
            HStack {
                Button { model.copyDiagnosticReport() } label: {
                    Label("Copy report", systemImage: "doc.on.doc")
                }
                if advice.opensInputMonitoring {
                    Spacer()
                    Button("Open Input Monitoring") { model.openInputMonitoring() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(18)
        .frame(width: 410, alignment: .leading)
    }
}

struct SectionLabel: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            Spacer()
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct HelpView: View {
    @EnvironmentObject private var model: AppModel
    @State private var expandedDiagnosticID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(eyebrow: "F87 Studio 4.6.0", title: "About F87 Studio",
                           subtitle: "A focused, independent macOS controller for the AULA F87 family.")

                HStack(spacing: 10) {
                    Link(destination: URL(string: "https://github.com/kmohammedsu/F87-Studio-macOS")!) {
                        Label("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    .buttonStyle(.borderedProminent)
                    Link(destination: URL(string: "https://github.com/kmohammedsu/F87-Studio-macOS/releases/latest")!) {
                        Label("Latest Release", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Label("Local processing", systemImage: "lock.shield.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                }

                HStack(spacing: 14) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(StudioUI.accent)
                        .frame(width: 38, height: 38)
                        .background(StudioUI.mutedAccent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Private by design").font(.headline)
                        Text("Keyboard configuration and audio levels are processed locally. F87 Studio does not collect analytics, record typing, or upload profiles.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(15)
                .studioCard(radius: 12)

                HelpRow(number: "1", title: "Use USB or a supported 2.4 GHz receiver",
                        text: "The known 3554:FA09 dongle is supported. If the app cannot configure your receiver—or you are using Bluetooth—plug in the cable and switch the keyboard to wired mode.")
                HelpRow(number: "2", title: "Allow Input Monitoring if asked",
                        text: "macOS protects keyboard interfaces. F87 Studio does not record your typing; permission is used only to open AULA’s vendor control channel.")
                HelpRow(number: "3", title: "Reconnect after granting access",
                        text: "Unplug and reconnect the cable or receiver, then choose Scan again.")

                HStack {
                    Button("Request Input Monitoring access") { model.requestInputMonitoring() }
                    Button("Scan again") { model.scan() }.buttonStyle(.borderedProminent)
                }

                Divider()
                Text("Common connection problems").font(.title3.weight(.semibold))
                Text("Open a diagnosis below for the safest recovery steps. Copy a diagnostic report from Keyboard settings → Activity when you need to share the exact failure.")
                    .foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(Array(ConnectionDiagnostics.common.enumerated()), id: \.element.id) { index, advice in
                        DiagnosticGuideRow(
                            advice: advice,
                            isExpanded: Binding(
                                get: { expandedDiagnosticID == advice.id },
                                set: { expandedDiagnosticID = $0 ? advice.id : nil }
                            )
                        )
                        if index < ConnectionDiagnostics.common.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .studioCard(radius: 12)

                Divider()
                Text("Compatibility").font(.title3.weight(.semibold))
                Text("Designed for F87/F87 Pro units using wired USB 258A:010C or the known 2.4 GHz receiver 3554:FA09. AULA has shipped multiple receiver revisions; if yours is not recognized, wired mode is the reliable fallback. The app reads and validates the current configuration before it writes anything.")
                    .foregroundStyle(.secondary)
                Text("Windows feature compatibility").font(.title3.weight(.semibold))
                Text("Available on the verified 3554:FA09 receiver: onboard effects, brightness, speed and color, Per-key Pro editing, profiles, automatic app switching, sleep, debounce, current-setting sync, factory lighting reset, and host-powered Music mode. The Mac function row and curated macros work host-side over any connection that sends normal F-key events. Battery telemetry, side-strip packets, and onboard arbitrary key reassignment are not available on this verified protocol.")
                    .foregroundStyle(.secondary)
                Text("Limitations").font(.title3.weight(.semibold))
                Text("Timing and factory-reset controls are enabled only on firmware revisions where those settings can be read and verified safely. Mac function-row mappings require F87 Studio to remain running and Accessibility permission to replace the incoming F-key event. Onboard macros and arbitrary firmware reassignment remain disabled because the published tables target other device IDs and are write-only; sending a guessed table could erase existing assignments.")
                    .foregroundStyle(.secondary)
            }.padding(28).frame(maxWidth: 820, alignment: .leading)
        }
    }
}

struct DiagnosticGuideRow: View {
    let advice: DiagnosticAdvice
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 9) {
                Text(advice.explanation)
                    .foregroundStyle(.secondary)
                ForEach(advice.steps, id: \.self) { step in
                    Label(step, systemImage: "chevron.right")
                        .font(.callout)
                }
            }
            .padding(.top, 10)
            .padding(.leading, 26)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: advice.symbol)
                    .foregroundStyle(.orange)
                    .frame(width: 30, height: 30)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(advice.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

struct HelpRow: View {
    let number: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number).font(.caption.weight(.semibold)).frame(width: 28, height: 28)
                .background(StudioUI.recessed, in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary)
            }
        }
    }
}
