import Foundation
import SwiftUI
import UIKit
import CryptoKit

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @StateObject private var patchStore = PatchProjectStore()
    @StateObject private var repositoryStore = PackageRepositoryStore()
    @StateObject private var licenseSession = LicenseSession()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.vietnamese.rawValue
    @AppStorage("aujunpeak.appearance") private var appearanceMode = "system"
    @State private var showOnboarding = OnboardingStore.shouldShow()
    @State private var showAttribution = false
    @State private var showLicenseCheck = false
    @State private var licenseCheckSucceeded = false
    @State private var updateOffer: AppUpdateChecker.Offer?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        setupLogCapture()
        log("app: 3105 + Aujunpeak VN launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .vietnamese
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private func checkForUpdate() {
        Task {
            guard let offer = await AppUpdateChecker.check() else { return }
            await MainActor.run { updateOffer = offer }
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(appState)
                    .environmentObject(patchDraftCoordinator)
                    .environmentObject(fileOperationCoordinator)
                    .environmentObject(patchStore)
                    .environmentObject(repositoryStore)
                    .environmentObject(licenseSession)
                    .environment(\.appLanguage, language)
                    .environment(\.locale, language.locale)
                    .opacity(showOnboarding ? 0 : 1)
                    .allowsHitTesting(!showOnboarding)

                if let notice = licenseSession.failureNotice {
                    LicenseFailureOverlay(notice: notice) {
                        licenseSession.completeFailureLogout()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(100)
                }

                if showLicenseCheck {
                    LicenseCheckOverlay(
                        succeeded: licenseCheckSucceeded,
                        hasStoredKey: !licenseSession.storedKey.isEmpty
                    )
                    .transition(.opacity)
                    .zIndex(120)
                }

                if showOnboarding {
                    OnboardingView {
                        OnboardingStore.markCompleted()
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            showOnboarding = false
                        }
                        appState.detectSupport()
                        checkForUpdate()
                        Task { await licenseSession.bootstrap() }
                    }
                    .environment(\.appLanguage, language)
                    .environment(\.locale, language.locale)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(1)
                }
            }
            .preferredColorScheme(preferredColorScheme)
            .displayIdentityAttribution(isPresented: $showAttribution, enabled: !showOnboarding)
            .sheet(isPresented: $showAttribution) { DisplayAttributionSheet() }
            .alert(item: $updateOffer) { offer in
                Alert(
                    title: Text(language.text("update.title")),
                    message: Text(language.text("update.message", offer.version)),
                    primaryButton: .default(Text(language.text("update.agree"))) {
                        UIApplication.shared.open(offer.url)
                    },
                    secondaryButton: .cancel(Text(language.text("update.dismiss"))) {
                        AppUpdateChecker.dismiss(version: offer.version)
                    }
                )
            }
            .fullScreenCover(isPresented: Binding(
                get: { !showOnboarding && licenseSession.requiresActivation },
                set: { _ in }
            )) {
                LicenseActivationView()
                    .environmentObject(licenseSession)
                    .interactiveDismissDisabled(true)
            }
            .onAppear {
                if !showOnboarding {
                    appState.detectSupport()
                    checkForUpdate()
                    runLicenseCheck()
                }
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active, !showOnboarding else { return }
                appState.detectSupport()
                Task { await licenseSession.refreshStatus() }
            }
            .onOpenURL { url in
                patchDraftCoordinator.presentImport(url)
            }
        }
    }

    private func runLicenseCheck() {
        guard !showLicenseCheck else { return }
        showLicenseCheck = true
        licenseCheckSucceeded = false
        Task {
            await licenseSession.bootstrap()
            try? await Task.sleep(nanoseconds: 650_000_000)
            await MainActor.run {
                licenseCheckSucceeded = !licenseSession.storedKey.isEmpty && licenseSession.license != nil
            }
            try? await Task.sleep(nanoseconds: 850_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.18)) { showLicenseCheck = false }
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false

    private var autoRunAttempted = false

    var kernelExploitApplicable: Bool {
        KernelExploit.isApplicable(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        )
    }

    var isSupported: Bool { unsupportedMessage == nil }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            return
        }

        let applicable = KernelExploit.isApplicable(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        guard applicable else { return }

        refreshKernelExploitStatus()
        maybeAutoRunKernelExploit()
    }

    private func maybeAutoRunKernelExploit() {
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed,
              !autoRunAttempted else { return }
        autoRunAttempted = true
        log("app: starting kernel exploit automatically")
        runKernelExploitIfNeeded()
    }

    private func refreshKernelExploitStatus() {
        guard !kernelExploitRunning else { return }

        // iOS < 26: kernel R/W success persists (no sandbox probe)
        // iOS >= 26: verify full sandbox escape is still active
        if KernelExploit.requiresSandboxEscape {
            if KernelExploit.hasSandboxAccess() {
                if !exploitStatus.isSuccess {
                    exploitStatus = .success(method: "kexploit")
                    log("app: existing sandbox access is still active; skipping kernel exploit")
                }
            } else if exploitStatus.isSuccess {
                exploitStatus = .notStarted
                log("app: sandbox access is no longer active")
            }
        }
    }

    func runKernelExploitIfNeeded() {
        refreshKernelExploitStatus()
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed else { return }
        kernelExploitRunning = true
        exploitStatus = .notStarted
        log("app: running kernel exploit on background...")
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.kernelExploitRunning = false
                if ok {
                    self.exploitStatus = .success(method: "kexploit")
                    if KernelExploit.requiresSandboxEscape {
                        log("app: kernel exploit success — sandbox access verified")
                    } else {
                        log("app: kernel exploit success — kernel access active")
                    }
                } else {
                    self.exploitStatus = .failed(method: "kexploit", code: -1)
                    log("app: kernel exploit failed — relaunch the app before retrying")
                }
            }
        }
    }
}


// MARK: - Aujunpeak VN License / Admin Server

enum AdminServerConfig {
    // Upload thư mục `aujunpeak-admin` vào domain/VPS ở cùng đường dẫn này,
    // hoặc đổi URL tại đây nếu bạn dùng domain/path khác.
    static let apiBaseURL = URL(string: "http://103.140.249.74:8082/api")!
}


struct RemoteGameSection: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let gameKey: String
    let title: String
    let bundleID: String
    let iconURL: String?
    let enabled: Bool
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, title, enabled
        case gameKey = "game_key"
        case bundleID = "bundle_id"
        case iconURL = "icon_url"
        case sortOrder = "sort_order"
    }

    static let fallbackGames: [RemoteGameSection] = [
        .init(id: 1, gameKey: "freefire", title: "Free Fire", bundleID: "com.dts.freefireth", iconURL: nil, enabled: true, sortOrder: 10),
        .init(id: 2, gameKey: "freefiremax", title: "Free Fire Max", bundleID: "com.dts.freefiremax", iconURL: nil, enabled: true, sortOrder: 20),
        .init(id: 3, gameKey: "pubg", title: "PUBG Mobile", bundleID: "com.tencent.ig", iconURL: nil, enabled: true, sortOrder: 30),
        .init(id: 4, gameKey: "lienquan", title: "Liên Quân", bundleID: "com.garena.game.kgvn", iconURL: nil, enabled: true, sortOrder: 40)
    ]
}

struct RemoteAdminSwitch: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let configKey: String
    let title: String
    let subtitle: String
    let icon: String
    let enabled: Bool
    let sortOrder: Int
    let hasPackage: Bool
    let packageVersion: Int
    let packageHash: String?
    let gameKey: String
    let gameName: String?
    let gameBundleID: String?
    let gameIconURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, icon, enabled
        case configKey = "config_key"
        case sortOrder = "sort_order"
        case hasPackage = "has_package"
        case packageVersion = "package_version"
        case packageHash = "package_sha256"
        case gameKey = "game_key"
        case gameName = "game_name"
        case gameBundleID = "game_bundle_id"
        case gameIconURL = "game_icon_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        configKey = try c.decode(String.self, forKey: .configKey)
        title = try c.decode(String.self, forKey: .title)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "bolt.fill"
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        hasPackage = try c.decodeIfPresent(Bool.self, forKey: .hasPackage) ?? false
        packageVersion = try c.decodeIfPresent(Int.self, forKey: .packageVersion) ?? 0
        packageHash = try c.decodeIfPresent(String.self, forKey: .packageHash)
        gameKey = try c.decodeIfPresent(String.self, forKey: .gameKey) ?? "freefire"
        gameName = try c.decodeIfPresent(String.self, forKey: .gameName)
        gameBundleID = try c.decodeIfPresent(String.self, forKey: .gameBundleID)
        gameIconURL = try c.decodeIfPresent(String.self, forKey: .gameIconURL)
    }
}

struct RemotePackagePayload: Sendable {
    let data: Data
    let password: String?
    let sha256: String
    let version: Int
}

struct RemoteLicenseInfo: Codable, Equatable {
    let key: String
    let status: String
    let activatedAt: String?
    let expiresAt: String?
    let durationDays: Int
    let maxDevices: Int
    let deviceCount: Int

    enum CodingKeys: String, CodingKey {
        case key, status
        case activatedAt = "activated_at"
        case expiresAt = "expires_at"
        case durationDays = "duration_days"
        case maxDevices = "max_devices"
        case deviceCount = "device_count"
    }
}

struct RemoteUpdateConfig: Codable, Equatable, Sendable {
    let enabled: Bool
    let version: String
    let url: String
    let notes: String?
}

struct RemoteClientSettings: Codable, Equatable, Sendable {
    let supportURL: String?
    let update: RemoteUpdateConfig?

    enum CodingKeys: String, CodingKey {
        case supportURL = "support_url"
        case update
    }
}

private struct LicenseAPIResponse: Codable {
    let ok: Bool
    let code: String?
    let message: String?
    let license: RemoteLicenseInfo?
    let switches: [RemoteAdminSwitch]?
    let games: [RemoteGameSection]?
    let settings: RemoteClientSettings?
}

struct LicenseFailureNotice: Identifiable, Equatable {
    let id = UUID()
    let code: String
    let title: String
    let message: String
}

@MainActor
final class LicenseSession: ObservableObject {
    @Published private(set) var license: RemoteLicenseInfo?
    @Published private(set) var switches: [RemoteAdminSwitch] = []
    @Published private(set) var games: [RemoteGameSection] = []
    @Published private(set) var clientSettings: RemoteClientSettings?
    @Published private(set) var isLoading = false
    @Published var lastError: String?
    @Published private(set) var requiresActivation = false
    @Published private(set) var failureNotice: LicenseFailureNotice?

    private let keyStorageKey = "aujunpeak.remote.license.key"
    private let deviceStorageKey = "aujunpeak.remote.device.id"

    var storedKey: String {
        UserDefaults.standard.string(forKey: keyStorageKey) ?? ""
    }

    var deviceID: String {
        if let value = UserDefaults.standard.string(forKey: deviceStorageKey), !value.isEmpty {
            return value
        }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: deviceStorageKey)
        return value
    }

    var supportURL: URL {
        if let raw = clientSettings?.supportURL, let url = URL(string: raw) { return url }
        return URL(string: "https://zalo.me/0833091543")!
    }

    func bootstrap() async {
        guard !storedKey.isEmpty else {
            requiresActivation = true
            return
        }
        await refreshStatus()
    }

    func activate(key: String) async -> Bool {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            lastError = "Vui lòng nhập key."
            return false
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await request(endpoint: "activate.php", key: clean)
            guard response.ok, let info = response.license else {
                lastError = response.message ?? "Không thể kích hoạt key."
                return false
            }
            UserDefaults.standard.set(clean, forKey: keyStorageKey)
            license = info
            switches = (response.switches ?? []).sorted { $0.sortOrder < $1.sortOrder }
            games = (response.games ?? RemoteGameSection.fallbackGames).sorted { $0.sortOrder < $1.sortOrder }
            clientSettings = response.settings
            lastError = nil
            requiresActivation = false
            return true
        } catch {
            lastError = "Không kết nối được server: \(error.localizedDescription)"
            return false
        }
    }

    func refreshStatus() async {
        guard failureNotice == nil else { return }
        guard !storedKey.isEmpty else {
            requiresActivation = true
            license = nil
            switches = []
            games = RemoteGameSection.fallbackGames
            return
        }
        do {
            let response = try await request(endpoint: "status.php", key: storedKey)
            guard response.ok, let info = response.license else {
                let message = response.message ?? "Key không còn hợp lệ."
                lastError = message
                license = nil
                switches = []
                games = RemoteGameSection.fallbackGames
                requiresActivation = false
                failureNotice = LicenseFailureNotice(
                    code: response.code ?? "invalid",
                    title: failureTitle(for: response.code),
                    message: message
                )
                return
            }
            license = info
            switches = (response.switches ?? []).sorted { $0.sortOrder < $1.sortOrder }
            games = (response.games ?? RemoteGameSection.fallbackGames).sorted { $0.sortOrder < $1.sortOrder }
            clientSettings = response.settings
            requiresActivation = false
            lastError = nil
        } catch {
            lastError = "Mất kết nối server: \(error.localizedDescription)"
            if license == nil { requiresActivation = true }
        }
    }

    func forgetKey() {
        UserDefaults.standard.removeObject(forKey: keyStorageKey)
        license = nil
        switches = []
        games = []
        lastError = nil
        failureNotice = nil
        requiresActivation = true
    }

    func completeFailureLogout() {
        UserDefaults.standard.removeObject(forKey: keyStorageKey)
        license = nil
        switches = []
        games = []
        lastError = nil
        failureNotice = nil
        requiresActivation = true
    }

    func downloadPackage(for item: RemoteAdminSwitch) async throws -> RemotePackagePayload {
        guard item.hasPackage else {
            throw NSError(domain: "AujunpeakPackage", code: 404, userInfo: [NSLocalizedDescriptionKey: "Admin chưa gắn dữ liệu chức năng cho nút này."])
        }
        guard !storedKey.isEmpty else {
            throw NSError(domain: "AujunpeakPackage", code: 401, userInfo: [NSLocalizedDescriptionKey: "Phiên key không còn hợp lệ."])
        }

        let url = AdminServerConfig.apiBaseURL.appendingPathComponent("package.php")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "key": storedKey,
            "device_id": deviceID,
            "switch_id": item.id,
            "app_version": AppUpdateChecker.currentVersion
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let message = object["message"] as? String {
                throw NSError(domain: "AujunpeakPackage", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            }
            throw NSError(domain: "AujunpeakPackage", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Không thể tải dữ liệu chức năng từ Admin Server."])
        }

        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let expected = (item.packageHash ?? http.value(forHTTPHeaderField: "X-Aujunpeak-Package-SHA256") ?? "").lowercased()
        if !expected.isEmpty && expected != digest.lowercased() {
            throw NSError(domain: "AujunpeakPackage", code: 422, userInfo: [NSLocalizedDescriptionKey: "Dữ liệu chức năng không khớp chữ ký SHA-256."])
        }

        var password: String?
        if let encoded = http.value(forHTTPHeaderField: "X-Aujunpeak-Package-Password-B64"),
           let passwordData = Data(base64Encoded: encoded),
           let decodedPassword = String(data: passwordData, encoding: .utf8),
           !decodedPassword.isEmpty {
            password = decodedPassword
        }
        if password == nil && ["builtin_drag", "builtin_nhe", "builtin_magic"].contains(item.configKey) {
            password = "james"
        }

        let version = Int(http.value(forHTTPHeaderField: "X-Aujunpeak-Package-Version") ?? "") ?? item.packageVersion
        return RemotePackagePayload(data: data, password: password, sha256: digest, version: version)
    }

    private func failureTitle(for code: String?) -> String {
        switch code {
        case "revoked": return "KEY ĐÃ BỊ KHÓA"
        case "expired": return "KEY ĐÃ HẾT HẠN"
        case "device_not_bound": return "THIẾT BỊ ĐÃ BỊ RESET"
        case "invalid_key": return "KEY KHÔNG HỢP LỆ"
        case "not_activated": return "KEY CHƯA KÍCH HOẠT"
        default: return "PHIÊN ĐĂNG NHẬP THẤT BẠI"
        }
    }

    private func request(endpoint: String, key: String) async throws -> LicenseAPIResponse {
        let url = AdminServerConfig.apiBaseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "key": key,
            "device_id": deviceID,
            "device_name": UIDevice.current.model + " / " + AppInfo.displayMachineName,
            "app_version": AppUpdateChecker.currentVersion
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard response is HTTPURLResponse else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(LicenseAPIResponse.self, from: data)
    }
}
private struct LicenseFailureOverlay: View {
    let notice: LicenseFailureNotice
    let onFinished: () -> Void
    @State private var appeared = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.96)
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color.red.opacity(pulse ? 0.28 : 0.10), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.14))
                        .frame(width: 112, height: 112)
                    Circle()
                        .stroke(Color.red.opacity(0.45), lineWidth: 2)
                        .frame(width: appeared ? 126 : 86, height: appeared ? 126 : 86)
                        .opacity(appeared ? 0.1 : 0.8)
                    Image(systemName: "xmark.shield.fill")
                        .font(.system(size: 52, weight: .black))
                        .foregroundStyle(.red)
                }

                Text("FAILED")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.red)

                VStack(spacing: 7) {
                    Text(notice.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(notice.message)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.64))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("Đang đăng xuất khỏi thiết bị…")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.top, 6)
            }
            .padding(28)
            .scaleEffect(appeared ? 1 : 0.86)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.72)) {
                appeared = true
            }
            pulse = true
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            onFinished()
        }
    }
}

private struct LicenseCheckOverlay: View {
    let succeeded: Bool
    let hasStoredKey: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.90)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill((succeeded ? AppTheme.secondaryAccent : AppTheme.accent).opacity(0.14))
                        .frame(width: 92, height: 92)

                    if succeeded {
                        Image(systemName: "checkmark")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(AppTheme.secondaryAccent)
                    } else {
                        ProgressView()
                            .controlSize(.large)
                            .tint(AppTheme.secondaryAccent)
                    }
                }

                Text(succeeded ? "KEY ĐÃ XÁC THỰC" : "ĐANG KIỂM TRA KEY")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(
                    succeeded
                    ? "Thiết bị đã sẵn sàng sử dụng"
                    : (hasStoredKey ? "Đang đồng bộ trạng thái thiết bị…" : "Đang chuẩn bị hệ thống…")
                )
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
            }
            .padding(28)
            .frame(maxWidth: 290)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        (succeeded ? AppTheme.secondaryAccent : AppTheme.accent).opacity(0.34),
                        lineWidth: 1
                    )
            }
        }
    }
}

private struct LicenseActivationView: View {
    @EnvironmentObject private var licenseSession: LicenseSession
    private let zaloURL = URL(string: "https://zalo.me/0833091543")!
    @State private var keyText = ""
    @State private var shake = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppAuroraBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        logo

                        AppGlassPanel(cornerRadius: 20, tint: AppTheme.secondaryAccent) {
                            VStack(spacing: 14) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("LICENSE KEY")
                                            .font(.caption.weight(.black))
                                            .tracking(1.4)
                                            .foregroundStyle(.white.opacity(0.52))
                                        Text("Nhập key để đồng bộ thiết bị")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.title3)
                                        .foregroundStyle(AppTheme.secondaryAccent)
                                }

                            HStack(spacing: 11) {
                                ZStack {
                                    Circle().fill(AppTheme.accent.opacity(0.18))
                                    Image(systemName: "key.fill")
                                        .foregroundStyle(AppTheme.accent)
                                }
                                .frame(width: 38, height: 38)

                                TextField("AJP-XXXXX-XXXXX-XXXXX-XXXXX", text: $keyText)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled(true)
                                    .foregroundStyle(.white)
                                    .font(.system(.body, design: .monospaced))
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 58)
                            .background(Color.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(AppTheme.accent.opacity(0.42), lineWidth: 1)
                            }

                            HStack(spacing: 8) {
                                Image(systemName: "iphone.gen3")
                                Text("Device ID  •  \(licenseSession.deviceID.prefix(18))…")
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            }
                            .font(.caption.monospaced())
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if let error = licenseSession.lastError, !error.isEmpty {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "xmark.octagon.fill")
                                        .foregroundStyle(.red)
                                    Text(error)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.55))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(12)
                                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            Button {
                                Task {
                                    let ok = await licenseSession.activate(key: keyText)
                                    if !ok {
                                        await MainActor.run {
                                            withAnimation(.default.repeatCount(3, autoreverses: true)) { shake.toggle() }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    if licenseSession.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "checkmark.shield.fill")
                                    }
                                    Text(licenseSession.isLoading ? "Đang xác thực…" : "Kích hoạt Key")
                                }
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(AppGradientButtonStyle(colors: [AppTheme.secondaryAccent, AppTheme.accent]))
                            .disabled(licenseSession.isLoading || keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

                            Link(destination: zaloURL) {
                                HStack(spacing: 9) {
                                    Image(systemName: "message.fill")
                                    Text("Liên hệ mua Key")
                                }
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                 .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                         .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
                                }
                            }
                            .padding(16)
                        }
                        .offset(x: shake ? -7 : 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 22)
                    .padding(.top, 28)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    }

    private var logo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.accent.opacity(0.28), AppTheme.hotPink.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if UIImage(named: "AujunpeakLogo") != nil {
                Image("AujunpeakLogo")
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .frame(width: 112, height: 112)
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(AppTheme.secondaryAccent.opacity(0.52), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.26), radius: 12, y: 6)
    }
}
