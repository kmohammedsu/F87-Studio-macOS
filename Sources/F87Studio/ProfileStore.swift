import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [StoredProfile] = []
    @Published private(set) var lastError: String?

    init() { load() }

    @discardableResult
    func add(name: String, profile: F87Profile) -> StoredProfile {
        let cleanName = uniqueName(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Profile" : name)
        let item = StoredProfile(name: cleanName, profile: profile)
        profiles.insert(item, at: 0)
        save()
        return item
    }

    func update(_ id: UUID, profile: F87Profile) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].profile = profile
        profiles[index].modifiedAt = .now
        save()
    }

    func rename(_ id: UUID, to name: String) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        profiles[index].name = clean
        profiles[index].modifiedAt = .now
        save()
    }

    func duplicate(_ id: UUID) {
        guard let source = profiles.first(where: { $0.id == id }) else { return }
        var copy = source
        copy.id = UUID()
        copy.name = uniqueName("\(source.name) Copy")
        copy.assignedBundleIdentifier = nil
        copy.assignedApplicationName = nil
        copy.modifiedAt = .now
        profiles.insert(copy, at: 0)
        save()
    }

    func remove(_ id: UUID) {
        profiles.removeAll { $0.id == id }
        save()
    }

    func assign(_ id: UUID, bundleIdentifier: String?, applicationName: String?) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        for other in profiles.indices where profiles[other].assignedBundleIdentifier == bundleIdentifier && bundleIdentifier != nil {
            profiles[other].assignedBundleIdentifier = nil
            profiles[other].assignedApplicationName = nil
        }
        profiles[index].assignedBundleIdentifier = bundleIdentifier
        profiles[index].assignedApplicationName = applicationName
        profiles[index].modifiedAt = .now
        save()
    }

    func profile(forBundleIdentifier bundleIdentifier: String) -> StoredProfile? {
        profiles.first { $0.assignedBundleIdentifier == bundleIdentifier }
    }

    private func uniqueName(_ base: String) -> String {
        let names = Set(profiles.map { $0.name.lowercased() })
        guard names.contains(base.lowercased()) else { return base }
        var index = 2
        while names.contains("\(base) \(index)".lowercased()) { index += 1 }
        return "\(base) \(index)"
    }

    private func load() {
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            profiles = try decoder.decode([StoredProfile].self, from: data)
                .sorted { $0.modifiedAt > $1.modifiedAt }
        } catch CocoaError.fileReadNoSuchFile {
            profiles = []
        } catch {
            lastError = "Could not load the profile library: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            let directory = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(profiles)
            try data.write(to: storageURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = "Could not save the profile library: \(error.localizedDescription)"
        }
    }

    private var storageURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root.appendingPathComponent("F87 Studio", isDirectory: true)
            .appendingPathComponent("profiles.json")
    }
}
