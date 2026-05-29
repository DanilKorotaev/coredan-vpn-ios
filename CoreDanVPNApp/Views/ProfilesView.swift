import SwiftUI

struct ProfilesView: View {
    @StateObject private var viewModel = ProfilesViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.profiles.isEmpty {
                    ContentUnavailableView(
                        "Нет профилей",
                        systemImage: "network",
                        description: Text("Добавьте ss:// ссылку или заполните поля вручную.")
                    )
                } else {
                    List {
                        ForEach(viewModel.profiles) { profile in
                            ProfileRow(
                                profile: profile,
                                isSelected: viewModel.selectedID == profile.id,
                                status: viewModel.status
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { viewModel.select(profile) }
                        }
                        .onDelete(perform: viewModel.delete)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("CoreDan VPN")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.isPresentingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(viewModel.connectButtonTitle) {
                    Task { await viewModel.toggleConnection() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .disabled(viewModel.selectedProfile == nil || viewModel.isBusy)
            }
            .sheet(isPresented: $viewModel.isPresentingAdd) {
                AddProfileView { profile in
                    viewModel.add(profile)
                }
            }
            .alert("Ошибка", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                await viewModel.refreshStatus()
            }
        }
        .background(Color(uiColor: .systemBackground))
    }
}

private struct ProfileRow: View {
    let profile: ServerProfile
    let isSelected: Bool
    let status: VPNStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(profile.name).font(.headline)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            Text("\(profile.host):\(profile.port) · \(profile.method)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let plugin = profile.plugin {
                Text(plugin.pluginName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if isSelected {
                Text(statusLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusLabel: String {
        switch status {
        case .connected: "Подключено"
        case .connecting: "Подключение…"
        case .disconnecting: "Отключение…"
        case .disconnected: "Не подключено"
        case .error(let msg): "Ошибка: \(msg)"
        }
    }
}
