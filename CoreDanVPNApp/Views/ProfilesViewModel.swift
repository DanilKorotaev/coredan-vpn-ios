import Foundation

@MainActor
final class ProfilesViewModel: ObservableObject {
    @Published var profiles: [ServerProfile] = []
    @Published var selectedID: UUID?
    @Published var status: VPNStatus = .disconnected
    @Published var isPresentingAdd = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var isBusy = false

    private let log = makeLogger(tag: .profile)
    private let repository: ProfileRepositoryProtocol
    private let vpn: VPNControllerProtocol
    private let configBuilder: SingBoxConfigBuilder

    init(
        repository: ProfileRepositoryProtocol = ProfileRepository(),
        vpn: VPNControllerProtocol = VPNController(),
        configBuilder: SingBoxConfigBuilder = SingBoxConfigBuilder()
    ) {
        self.repository = repository
        self.vpn = vpn
        self.configBuilder = configBuilder
        load()
    }

    var selectedProfile: ServerProfile? {
        profiles.first { $0.id == selectedID }
    }

    var connectButtonTitle: String {
        switch status {
        case .connected, .connecting: "Отключить"
        default: "Подключить"
        }
    }

    func load() {
        profiles = (try? repository.loadProfiles()) ?? []
        selectedID = repository.loadSelectedProfileID() ?? profiles.first?.id
    }

    func add(_ profile: ServerProfile) {
        profiles.append(profile)
        selectedID = profile.id
        persist()
    }

    func select(_ profile: ServerProfile) {
        selectedID = profile.id
        repository.saveSelectedProfileID(profile.id)
    }

    func delete(at offsets: IndexSet) {
        profiles.remove(atOffsets: offsets)
        if let selectedID, !profiles.contains(where: { $0.id == selectedID }) {
            self.selectedID = profiles.first?.id
            repository.saveSelectedProfileID(self.selectedID)
        }
        persist()
    }

    func refreshStatus() async {
        status = await vpn.status()
    }

    func toggleConnection() async {
        isBusy = true
        defer { isBusy = false }
        switch status {
        case .connected, .connecting:
            do {
                try await vpn.disconnect()
                status = .disconnected
            } catch {
                present(error)
            }
        default:
            guard let profile = selectedProfile else { return }
            do {
                let json = try configBuilder.build(profile: profile)
                log.debugInfo("sing-box config built (\(json.count) bytes)")
                try await vpn.connect(profile: profile, singBoxJSON: json)
                status = await vpn.status()
                if case .disconnected = status, let tunnelError = await vpn.lastTunnelError() {
                    status = .error(tunnelError)
                    present(VPNControllerError.tunnelFailed(tunnelError))
                }
            } catch {
                present(error)
                status = .error(error.localizedDescription)
            }
        }
    }

    private func persist() {
        try? repository.saveProfiles(profiles)
        if let selectedID {
            repository.saveSelectedProfileID(selectedID)
        }
    }

    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
