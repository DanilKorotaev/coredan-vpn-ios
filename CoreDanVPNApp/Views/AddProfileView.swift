import SwiftUI

struct AddProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mode: AddMode = .importLink

    @State private var linkText = ""
    @State private var name = ""
    @State private var host = ""
    @State private var port = "8388"
    @State private var method = "aes-256-gcm"
    @State private var password = ""
    @State private var pluginKind: PluginKind = .none
    @State private var obfsHost = "www.bing.com"
    @State private var obfsMode = "tls"
    @State private var v2rayHost = ""
    @State private var v2rayPath = "/vpn"
    @State private var v2rayTLS = true

    let onSave: (ServerProfile) -> Void

    private let parser = SSURLParser()

    var body: some View {
        NavigationStack {
            Form {
                Picker("Способ", selection: $mode) {
                    Text("Ссылка ss://").tag(AddMode.importLink)
                    Text("Вручную").tag(AddMode.manual)
                }
                .pickerStyle(.segmented)

                switch mode {
                case .importLink:
                    Section("Ключ доступа") {
                        TextField("ss://…", text: $linkText, axis: .vertical)
                            .lineLimit(3...8)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Вставить из буфера") {
                            linkText = UIPasteboard.general.string ?? ""
                        }
                    }
                case .manual:
                    Section("Профиль") {
                        TextField("Название", text: $name)
                        TextField("Адрес", text: $host)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Порт", text: $port)
                            .keyboardType(.numberPad)
                        TextField("Метод", text: $method)
                            .textInputAutocapitalization(.never)
                        SecureField("Пароль", text: $password)
                    }
                    Section("Плагин") {
                        Picker("Тип", selection: $pluginKind) {
                            ForEach(PluginKind.allCases, id: \.self) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        switch pluginKind {
                        case .none:
                            EmptyView()
                        case .obfsLocal:
                            TextField("obfs-host", text: $obfsHost)
                            TextField("obfs (режим)", text: $obfsMode)
                        case .v2rayPlugin:
                            TextField("host", text: $v2rayHost)
                            TextField("path", text: $v2rayPath)
                            Toggle("TLS", isOn: $v2rayTLS)
                        }
                    }
                }
            }
            .scrollContentBackground(.visible)
            .navigationTitle("Новый профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        switch mode {
        case .importLink: !linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .manual:
            !host.isEmpty && Int(port) != nil && !method.isEmpty && !password.isEmpty
        }
    }

    private func save() {
        do {
            let profile: ServerProfile
            switch mode {
            case .importLink:
                profile = try parser.parse(linkText)
            case .manual:
                let displayName = name.isEmpty ? host : name
                profile = ServerProfile(
                    name: displayName,
                    host: host,
                    port: Int(port) ?? 8388,
                    method: method,
                    password: password,
                    plugin: buildPlugin()
                )
            }
            onSave(profile)
            dismiss()
        } catch {
            // Simple alert via notification — parent handles errors on connect; here use name field flash
            name = "Ошибка: \(error.localizedDescription)"
        }
    }

    private func buildPlugin() -> ProxyPlugin? {
        switch pluginKind {
        case .none: return nil
        case .obfsLocal: return .obfsLocal(mode: obfsMode, host: obfsHost)
        case .v2rayPlugin: return .v2rayPlugin(host: v2rayHost, path: v2rayPath, tls: v2rayTLS)
        }
    }
}

private enum AddMode {
    case importLink
    case manual
}

private enum PluginKind: CaseIterable {
    case none
    case obfsLocal
    case v2rayPlugin

    var title: String {
        switch self {
        case .none: "Нет"
        case .obfsLocal: "obfs-local"
        case .v2rayPlugin: "v2ray-plugin"
        }
    }
}
