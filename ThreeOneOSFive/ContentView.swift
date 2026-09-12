import Foundation
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage(FeatureVisibility.developerModeStorageKey)
    private var developerModeEnabled = false
    @State private var tabNavigation: AppTabNavigationState
    @State private var showSettings = false
    @AppStorage("feature.cleaner.enabled") private var cleanerEnabled = false
    @AppStorage("feature.wallpapers.enabled") private var wallpapersEnabled = false
    @AppStorage("aujunpeak.selected.game") private var selectedGameKey = "freefire"
    @State private var sideMenuExpanded = false

    init() {
        _tabNavigation = State(initialValue: AppTabNavigationState())
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.installed.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.installed.rawValue) }
        }
        .onChange(of: developerModeEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onAppear {
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .patchStorePresentation(patchStore)
        .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
    }

    private var compactLayout: some View {
        ZStack(alignment: .leading) {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            AppSideNavigation(
                sections: featureVisibility.visibleSections,
                selectedTab: tabNavigation.selectedTab,
                isExpanded: $sideMenuExpanded,
                onSelect: { section in
                    tabNavigation.select(section.rawValue)
                    sideMenuExpanded = false
                }
            )
            .padding(.leading, 8)
            .frame(maxHeight: .infinity, alignment: .center)
            .zIndex(80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.18), value: selectedVisibleSection.rawValue)
        .animation(.easeInOut(duration: 0.18), value: sideMenuExpanded)
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .navigationTitle("Aujunpeak")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            DashboardView(
                cleanerEnabled: $cleanerEnabled,
                wallpapersEnabled: $wallpapersEnabled,
                wallpapersSupported: false,
                onOpenGame: { gameKey in
                    tabNavigation.select(AppSection.files.rawValue)
                    selectedGameKey = gameKey
                }
            )
        case .installed:
            ZStack {
                PatchProjectsView(
                    onOpenSettings: openSettings,
                    onOpenLogs: {}
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                KeyInfoOverlayView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .files:
            ZStack {
                AppDataBrowserView(
                    tabSession: filesTabSession,
                    onOpenSettings: openSettings,
                    onOpenLogs: {}
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                FunctionOverlayView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(developerModeEnabled: developerModeActive)
    }

    private var developerModeActive: Bool {
#if targetEnvironment(simulator)
        developerModeEnabled
            || ProcessInfo.processInfo.arguments.contains("--simulate-developer-mode")
            || ProcessInfo.processInfo.arguments.contains("--simulate-files-tab")
#else
        developerModeEnabled
#endif
    }

    private var selectedVisibleSection: AppSection {
        let selected = AppSection(rawValue: tabNavigation.selectedTab)
        return selected.flatMap {
            featureVisibility.isVisible($0) ? $0 : nil
        } ?? .home
    }

    private func openSettings() {
        showSettings = true
    }

}

private struct CompactTabLabel: View
 {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .installed: return "tab.installed"
        case .files: return "tab.files"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .installed: return "key.fill"
        case .files: return "wand.and.stars"
        }
    }

    var displayTitle: String {
        switch self {
        case .home: return "Home"
        case .installed: return "Key Center"
        case .files: return "Function"
        }
    }
}
private struct AppSideNavigation: View {
    let sections: [AppSection]
    let selectedTab: Int
    @Binding var isExpanded: Bool
    let onSelect: (AppSection) -> Void

    var body: some View {
        VStack(spacing: 8) {
            if isExpanded {
                ForEach(sections) { section in
                    Button { onSelect(section) } label: {
                        Image(systemName: section.systemImage)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(selectedTab == section.rawValue ? AppTheme.secondaryAccent : .white.opacity(0.78))
                            .frame(width: 38, height: 38)
                            .background(
                                selectedTab == section.rawValue ? AppTheme.secondaryAccent.opacity(0.18) : Color.black.opacity(0.48),
                                in: Circle()
                            )
                            .overlay { Circle().stroke(Color.white.opacity(0.12), lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(section.displayTitle)
                    .transition(.scale.combined(with: .opacity))
                }
            }

            Button {
                isExpanded.toggle()
            } label: {
                Image(systemName: isExpanded ? "chevron.left" : "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.accent.opacity(0.88), in: Circle())
                    .overlay { Circle().stroke(Color.white.opacity(0.18), lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Đóng menu" : "Mở menu")
        }
        .padding(6)
        .background(Color.black.opacity(isExpanded ? 0.32 : 0.12), in: Capsule())
        .overlay { Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1) }
        .shadow(color: Color.black.opacity(0.28), radius: 10, y: 4)
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var licenseSession: LicenseSession
    @State private var showSettings = false
    @State private var contentAppeared = false
    @Binding var cleanerEnabled: Bool
    @Binding var wallpapersEnabled: Bool
    let wallpapersSupported: Bool
    let onOpenGame: (String) -> Void
    @AppStorage("aujunpeak.selected.game") private var selectedGameKey = "freefire"

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppNeonBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        Color.clear.frame(height: 68)
                        shopBannerSection
                        gameGridSection
                        deviceMiniSection
                    }
                    .frame(maxWidth: 860, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 28)
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 14)
                }

                HomeAdminOverlayCard()
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .zIndex(10)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .task {
                await licenseSession.refreshStatus()
            }
            .onAppear {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.82).delay(0.08)) {
                    contentAppeared = true
                }
            }
        }
    }

    private var shopBannerSection: some View {
        Link(destination: URL(string: "https://huanha.shop/")!) {
            ZStack(alignment: .bottomLeading) {
                if UIImage(named: "AujunpeakPromo") != nil {
                    Image("AujunpeakPromo")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 188)
                        .clipped()
                } else {
                    LinearGradient(colors: [Color.blue, Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(height: 188)
                }

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.84)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("AUJUNPEAK VN")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Panel game • hiệu ứng sáng • nhấn để mở huanha.shop")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                    HStack(spacing: 8) {
                        Label("Shop chính thức", systemImage: "checkmark.seal.fill")
                        Label("24/7", systemImage: "bolt.fill")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.92))
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color.cyan.opacity(0.75), Color.blue.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
            }
            .shadow(color: Color.blue.opacity(0.24), radius: 22, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var gameGridSection: some View {
        let games = homeGames
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Game Center")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                    Text("Chạm để mở Function theo từng game")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(games) { game in
                    Button {
                        selectedGameKey = game.gameKey
                        onOpenGame(game.gameKey)
                    } label: {
                        HomeGameCard(
                            game: game,
                            iconURL: resolvedIconURL(for: game),
                            isSelected: selectedGameKey == game.gameKey
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var deviceMiniSection: some View {
        HStack(spacing: 12) {
            MiniInfoChip(icon: "iphone.gen3", title: "Thiết bị", value: AppInfo.displayMachineName)
            MiniInfoChip(icon: "checkmark.shield.fill", title: "Key", value: licenseSession.license?.status.uppercased() ?? "SYNC")
        }
    }

    private var homeGames: [RemoteGameSection] {
        let defaults = RemoteGameSection.fallbackGames
        if licenseSession.games.isEmpty { return defaults }
        var merged = licenseSession.games
        for item in defaults where !merged.contains(where: { $0.gameKey == item.gameKey }) {
            merged.append(item)
        }
        return merged.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func resolvedIconURL(for game: RemoteGameSection) -> String? {
        if let url = game.iconURL?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            return url
        }
        return licenseSession.switches.first(where: {
            ($0.gameKey.isEmpty ? "freefire" : $0.gameKey) == game.gameKey &&
            !($0.gameIconURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })?.gameIconURL
    }
}

private struct MiniInfoChip: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.accent)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        }
    }
}

private struct HomeGameCard: View {
    let game: RemoteGameSection
    let iconURL: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            GameIconView(gameKey: game.gameKey, remoteURL: iconURL, size: 50, cornerRadius: 14)
            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
                Text(game.bundleID)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Mở nhanh")
                        .lineLimit(1)
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(isSelected ? Color.orange : Color.white.opacity(0.72))
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: isSelected
                    ? [Color.orange.opacity(0.30), Color.red.opacity(0.16)]
                    : [Color.white.opacity(0.12), Color.white.opacity(0.055)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? Color.orange.opacity(0.55) : Color.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
    }
}

private struct HomeAdminOverlayCard: View {
    private let zaloURL = URL(string: "https://zalo.me/0833091543")!

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [AppTheme.accent, AppTheme.accent.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text("GAME CENTER")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .lineLimit(1)
                Text("Hà Văn Huấn • Aujunpeak VN")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Color.green)
                }
                Link(destination: zaloURL) {
                    Image(systemName: "message.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 30)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(12)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppTheme.secondaryAccent.opacity(0.30), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.24), radius: 10, y: 5)
    }
}

private struct FunctionOverlayView: View {
    @EnvironmentObject private var licenseSession: LicenseSession
    @AppStorage("aujunpeak.selected.game") private var selectedGameKey = "freefire"
    @State private var refreshToken = 0
    @State private var contentAppeared = false

    private var availableGames: [RemoteGameSection] {
        let defaults = RemoteGameSection.fallbackGames
        if licenseSession.games.isEmpty { return defaults }
        var merged = licenseSession.games
        for item in defaults where !merged.contains(where: { $0.gameKey == item.gameKey }) {
            merged.append(item)
        }
        return merged.filter(\.enabled).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var currentGame: RemoteGameSection {
        availableGames.first(where: { $0.gameKey == selectedGameKey }) ?? availableGames.first ?? RemoteGameSection.fallbackGames[0]
    }

    private var visibleSwitches: [RemoteAdminSwitch] {
        let matched = licenseSession.switches.filter { ($0.gameKey.isEmpty ? "freefire" : $0.gameKey) == currentGame.gameKey }
        if matched.isEmpty && currentGame.gameKey == "freefire" { return licenseSession.switches }
        return matched
    }

    private func resolvedIconURL(for game: RemoteGameSection) -> String? {
        if let url = game.iconURL?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            return url
        }
        return licenseSession.switches.first(where: {
            ($0.gameKey.isEmpty ? "freefire" : $0.gameKey) == game.gameKey &&
            !($0.gameIconURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })?.gameIconURL
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Opaque base layer prevents the File/Data Browser from
                // showing through below the Function content.
                Color.black
                    .ignoresSafeArea()

                AppNeonBackground()
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    let viewportWidth = max(proxy.size.width, 1)
                    let horizontalInset: CGFloat = viewportWidth < 430 ? 12 : 18
                    let maxContentWidth: CGFloat = 620
                    let contentWidth = min(max(viewportWidth - (horizontalInset * 2), 0), maxContentWidth)

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .center, spacing: 10) {
                                functionHeader
                                gameSelector
                                functionTargetCard
                                remoteFunctions
                                statusCard
                                    .id(refreshToken)
                            }
                            .frame(width: contentWidth)
                            .clipped()
                        }
                        .frame(width: viewportWidth, alignment: .center)
                        .padding(.bottom, 28)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 10)
                    }
                    .frame(width: viewportWidth, height: proxy.size.height, alignment: .top)
                    .scrollIndicators(.visible)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Function")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await licenseSession.refreshStatus() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.58, dampingFraction: 0.84).delay(0.05)) {
                    contentAppeared = true
                }
                if !availableGames.contains(where: { $0.gameKey == selectedGameKey }) {
                    selectedGameKey = availableGames.first?.gameKey ?? "freefire"
                }
                Task { await licenseSession.refreshStatus() }
            }
            .animation(.easeInOut(duration: 0.22), value: refreshToken)
            .refreshable { await licenseSession.refreshStatus() }
        }
    }

    private var gameSelector: some View {
        let columns = [
            GridItem(.flexible(minimum: 0), spacing: 10),
            GridItem(.flexible(minimum: 0), spacing: 10)
        ]

        return LazyVGrid(columns: columns, alignment: .center, spacing: 8) {
            ForEach(availableGames) { game in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedGameKey = game.gameKey
                    }
                } label: {
                    HStack(spacing: 8) {
                        GameIconView(
                            gameKey: game.gameKey,
                            remoteURL: resolvedIconURL(for: game),
                            size: 38,
                            cornerRadius: 11
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(game.title)
                                .font(.system(size: 12.5, weight: .bold))
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Text(game.bundleID)
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 66, maxHeight: 66, alignment: .leading)
                    .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .background(
                        selectedGameKey == game.gameKey
                            ? Color.orange.opacity(0.18)
                            : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(
                                selectedGameKey == game.gameKey
                                    ? Color.orange.opacity(0.42)
                                    : Color.white.opacity(0.07),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var remoteFunctions: some View {
        VStack(spacing: 7) {
            if visibleSwitches.isEmpty {
                VStack(spacing: 8) {
                    GameIconView(gameKey: currentGame.gameKey, remoteURL: resolvedIconURL(for: currentGame), size: 56, cornerRadius: 16)
                    Text("Chưa có chức năng cho \(currentGame.title)")
                        .font(.headline.weight(.bold))
                    Text("Admin có thể thêm switch riêng, gắn package .3105 và đồng bộ trực tiếp cho game này.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                }
            } else {
                ForEach(visibleSwitches) { item in
                    RemoteFunctionSwitchCard(
                        item: item,
                        onChange: { refreshToken &+= 1 }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if licenseSession.switches.isEmpty && licenseSession.lastError != nil {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundStyle(.orange)
                    Text("Chức năng từ Admin tạm thời chưa đồng bộ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var functionHeader: some View {
        ZStack(alignment: .topLeading) {
            if let data = functionBannerData {
                AnimatedGIFView(data: data)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [Color(red: 0.02, green: 0.12, blue: 0.18), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            LinearGradient(
                colors: [Color.black.opacity(0.00), Color.black.opacity(0.24), Color.black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text("FUNCTION CENTER")
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)

                    Spacer(minLength: 0)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.15), in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.cyan.opacity(0.60), lineWidth: 1)
                    }
                }

                Spacer(minLength: 0)

                Text("Aujunpeak VN")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text("Chọn game và bật chức năng bạn cần")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 154, alignment: .center)
        .background(Color.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.cyan.opacity(0.38), lineWidth: 1)
        }
        .shadow(color: Color.cyan.opacity(0.10), radius: 10, y: 5)
    }

    private var functionBannerData: Data? {
        guard let url = Bundle.main.url(forResource: "FunctionLiveBanner", withExtension: "gif") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    private var functionTargetCard: some View {
        HStack(spacing: 9) {
            GameIconView(
                gameKey: currentGame.gameKey,
                remoteURL: resolvedIconURL(for: currentGame),
                size: 38,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(currentGame.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(currentGame.bundleID)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Text(licenseSession.license?.status.uppercased() ?? "SYNC")
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.10), in: Capsule())
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .clipped()
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.red.opacity(0.16), lineWidth: 1)
        }
    }

    private var statusCard: some View {
        let activeCount = visibleSwitches.filter { $0.enabled && LocalRemoteSwitchService.isEnabled($0) }.count
        return HStack(alignment: .center, spacing: 8) {
            Image(systemName: activeCount > 0 ? "checkmark.seal.fill" : "circle.dashed")
                .foregroundStyle(activeCount > 0 ? Color.green : Color.secondary)
                .font(.system(size: 15, weight: .semibold))

            VStack(alignment: .leading, spacing: 2) {
                Text("Trạng thái")
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)
                Text("\(currentGame.title): đang bật \(activeCount)/\(max(visibleSwitches.count, 1)) chức năng")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Text(activeCount > 0 ? "ACTIVE" : "READY")
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(activeCount > 0 ? Color.green : Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background((activeCount > 0 ? Color.green : Color.secondary).opacity(0.10), in: Capsule())
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct RemoteFunctionSwitchCard: View {
    @EnvironmentObject private var licenseSession: LicenseSession
    let item: RemoteAdminSwitch
    let onChange: () -> Void
    @State private var isOn: Bool
    @State private var operationMessage: String?
    @State private var isBusy = false

    init(item: RemoteAdminSwitch, onChange: @escaping () -> Void) {
        self.item = item
        self.onChange = onChange
        _isOn = State(initialValue: item.enabled && LocalRemoteSwitchService.isEnabled(item))
    }

    private var displaySubtitle: String {
        if !item.enabled { return "Admin đang tắt chức năng này" }
        if item.hasPackage { return item.subtitle }
        return item.subtitle.isEmpty ? "Chưa có dữ liệu chức năng từ Admin" : item.subtitle
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isOn ? Color.red.opacity(0.18) : Color(uiColor: .tertiarySystemFill))
                if isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: item.icon.isEmpty ? "bolt.fill" : item.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isOn ? Color.red : Color.secondary)
                }
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(operationMessage ?? displaySubtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(operationMessage?.hasPrefix("Lỗi:") == true ? Color.red : (item.enabled ? Color.secondary : Color.orange))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.8)
            }
            .layoutPriority(1)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    guard item.enabled, !isBusy else { return }
                    if newValue && !item.hasPackage {
                        operationMessage = "Lỗi: Admin chưa gắn dữ liệu chức năng"
                        return
                    }
                    updateSwitch(newValue)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(isOn ? Color.red : AppTheme.accent)
            .frame(width: 46, alignment: .trailing)
            .fixedSize(horizontal: true, vertical: false)
            .disabled(!item.enabled || isBusy)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 64, alignment: .leading)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isOn ? Color.red.opacity(0.42) : Color.white.opacity(0.10), lineWidth: 1)
        }
        .opacity(item.enabled ? 1 : 0.65)
        .onAppear { isOn = item.enabled && LocalRemoteSwitchService.isEnabled(item) }
        .onChange(of: item.enabled) { enabled in
            if !enabled {
                // An Admin-side disable must follow the same safety path as a
                // user turning the switch off: restore the exact originals
                // before removing the downloaded package.
                guard isOn || LocalRemoteSwitchService.hasInstalledState(for: item) else {
                    operationMessage = "Admin đã tắt chức năng"
                    onChange()
                    return
                }
                isBusy = true
                operationMessage = "Admin đã tắt • đang Restore Originals…"
                Task {
                    do {
                        try await Task.detached(priority: .userInitiated) {
                            try LocalRemoteSwitchService.setEnabled(false, for: item, package: nil)
                        }.value
                        await MainActor.run {
                            isOn = false
                            isBusy = false
                            operationMessage = "Admin đã tắt • Đã Restore Originals"
                            onChange()
                        }
                    } catch {
                        await MainActor.run {
                            isBusy = false
                            operationMessage = "Lỗi: Không thể Restore Originals — \(error.localizedDescription)"
                            onChange()
                        }
                    }
                }
            }
        }
        .onChange(of: item.packageVersion) { _ in
            if isOn && item.hasPackage && !LocalRemoteSwitchService.matchesInstalledVersion(item) {
                operationMessage = "Admin vừa cập nhật • đang Restore bản cũ và Apply bản mới…"
                updateSwitch(true)
            }
        }
        .onChange(of: item.hasPackage) { hasPackage in
            if !hasPackage && isOn {
                isBusy = true
                operationMessage = "Admin đã gỡ dữ liệu • đang Restore Originals…"
                Task {
                    do {
                        try await Task.detached(priority: .userInitiated) {
                            try LocalRemoteSwitchService.setEnabled(false, for: item, package: nil)
                        }.value
                        await MainActor.run {
                            isOn = false
                            isBusy = false
                            operationMessage = "Admin đã gỡ dữ liệu • Đã Restore Originals"
                            onChange()
                        }
                    } catch {
                        await MainActor.run {
                            isBusy = false
                            operationMessage = "Lỗi: Không thể Restore Originals — \(error.localizedDescription)"
                            onChange()
                        }
                    }
                }
            }
        }
    }

    private func updateSwitch(_ newValue: Bool) {
        isBusy = true
        operationMessage = newValue
            ? "Đang tải dữ liệu chức năng và Apply Patch…"
            : "Đang Restore Originals…"
        Task {
            do {
                if newValue {
                    let package = try await licenseSession.downloadPackage(for: item)
                    try await Task.detached(priority: .userInitiated) {
                        try LocalRemoteSwitchService.enableAndApply(for: item, package: package)
                    }.value
                } else {
                    try await Task.detached(priority: .userInitiated) {
                        try LocalRemoteSwitchService.setEnabled(false, for: item, package: nil)
                    }.value
                }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.18)) { isOn = newValue }
                    operationMessage = newValue
                        ? "\(LocalRemoteSwitchService.statusText(for: item)) • Đã tự động Apply Patch"
                        : "Đã tắt chức năng • Đã Restore Originals"
                    isBusy = false
                    onChange()
                }
            } catch {
                await MainActor.run {
                    isOn = LocalRemoteSwitchService.isEnabled(item)
                    isBusy = false
                    operationMessage = newValue
                        ? "Lỗi Apply Patch: \(error.localizedDescription)"
                        : "Lỗi Restore Originals: \(error.localizedDescription)"
                    onChange()
                }
            }
        }
    }
}

private enum LocalRemoteSwitchService {
    static func isEnabled(_ item: RemoteAdminSwitch) -> Bool {
        guard UserDefaults.standard.bool(forKey: storageKey(item)),
              localPackageExists(for: item),
              let projectID = packageID(for: item) else {
            return false
        }
        // The switch represents the device state, not merely a downloaded
        // package. A restored journal must therefore make the switch appear
        // off after relaunch or after a manual restore from Patch Projects.
        return DevicePatchService.latestReceipt(projectID: projectID) != nil
    }

    static func hasInstalledState(for item: RemoteAdminSwitch) -> Bool {
        UserDefaults.standard.bool(forKey: storageKey(item)) || localPackageExists(for: item)
    }

    static func matchesInstalledVersion(_ item: RemoteAdminSwitch) -> Bool {
        UserDefaults.standard.integer(forKey: versionKey(item)) == item.packageVersion
    }

    static func statusText(for item: RemoteAdminSwitch) -> String {
        guard let projectID = packageID(for: item),
              let existing = PatchProjectLibrary.load().first(where: { $0.id == projectID }),
              let project = existing.project else {
            return "Chức năng đã sẵn sàng"
        }
        return "Đã import • \(project.rules.count) rule • \(project.allBundleIdentifiers.first ?? item.gameBundleID ?? "game")"
    }

    static func applyInstalledPatch(for item: RemoteAdminSwitch) throws {
        guard let projectID = packageID(for: item),
              let installed = PatchProjectLibrary.load().first(where: { $0.id == projectID }),
              let baseProject = installed.project else {
            throw NSError(
                domain: "AujunpeakPatch",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy cấu hình patch đã cài."]
            )
        }

        let project = installed.summary.schemaVersion >= 2
            ? try PatchProjectLibrary.synchronizeWorkspace(item: installed)
            : baseProject
        _ = try DevicePatchService.apply(project: project)
    }

    /// Installs the downloaded package and applies it as one logical switch-on
    /// operation. If Apply fails, the package and local enabled marker are
    /// removed so the UI cannot claim that a non-applied patch is active.
    static func enableAndApply(for item: RemoteAdminSwitch, package: RemotePackagePayload) throws {
        do {
            try setEnabled(true, for: item, package: package)
            try applyInstalledPatch(for: item)
        } catch {
            // This also covers a package-install failure after an older
            // transaction was restored. Never leave an enabled marker that
            // does not correspond to an applied transaction.
            try? setEnabled(false, for: item, package: nil)
            throw error
        }
    }

    static func setEnabled(_ enabled: Bool, for item: RemoteAdminSwitch, package: RemotePackagePayload?) throws {
        if enabled {
            guard let package else {
                throw NSError(domain: "AujunpeakPackage", code: 400, userInfo: [NSLocalizedDescriptionKey: "Thiếu dữ liệu chức năng từ Admin Server."])
            }
            // A package update must never be applied over the previous
            // replacement. Restore the transaction that owns the originals
            // before replacing the local package or creating a new journal.
            try restoreActivePatch(for: item)
            try installDownloadedPackage(package, for: item)
            try writeMarker(for: item)
            UserDefaults.standard.set(true, forKey: storageKey(item))
            UserDefaults.standard.set(package.version, forKey: versionKey(item))
            UserDefaults.standard.set(package.sha256, forKey: hashKey(item))
        } else {
            // Restore first. If this throws, keep the package and enabled
            // marker intact so the user can retry instead of losing the only
            // safe path back to the originals.
            try restoreActivePatch(for: item)
            try uninstallDownloadedPackage(for: item)
            try removeMarker(for: item)
            UserDefaults.standard.set(false, forKey: storageKey(item))
            UserDefaults.standard.removeObject(forKey: versionKey(item))
            UserDefaults.standard.removeObject(forKey: hashKey(item))
        }
    }

    private static func restoreActivePatch(for item: RemoteAdminSwitch) throws {
        guard let projectID = packageID(for: item),
              let receipt = DevicePatchService.latestReceipt(projectID: projectID) else {
            return
        }
        try DevicePatchService.restore(receipt: receipt)
    }

    static func packageID(for item: RemoteAdminSwitch) -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: packageIDKey(item)) else { return nil }
        return UUID(uuidString: raw)
    }

    private static func installDownloadedPackage(_ package: RemotePackagePayload, for item: RemoteAdminSwitch) throws {
        let data = package.data
        let summary = try PatchPackageCodec.inspect(data)
        let decoded = try decodePackage(data: data, summary: summary, password: package.password, item: item)

        if let previousID = packageID(for: item), previousID != summary.packageID,
           let previous = PatchProjectLibrary.load().first(where: { $0.id == previousID }) {
            try? PatchProjectLibrary.delete(previous)
        }

        let existing = PatchProjectLibrary.load().first(where: { $0.id == summary.packageID })
        try PatchProjectLibrary.installImportedPackage(data: data, decoded: decoded, summary: summary, existingURL: existing?.packageURL)
        // Record the package identity before the Keychain write so the
        // enableAndApply cleanup path can still find and remove a package if
        // Keychain storage fails after the file was installed.
        UserDefaults.standard.set(summary.packageID.uuidString, forKey: packageIDKey(item))
        try PatchKeyStore.store(decoded.contentKey, for: summary)
    }

    private static func decodePackage(data: Data, summary: PatchPackageSummary, password: String?, item: RemoteAdminSwitch) throws -> DecodedPatchPackage {
        if let storedKey = try PatchKeyStore.load(for: summary) {
            return try PatchPackageCodec.decode(data, contentKey: storedKey)
        }
        if !summary.isPasswordProtected {
            return try PatchPackageCodec.decode(data, password: nil)
        }

        var candidates: [String] = []
        if let password, !password.isEmpty { candidates.append(password) }
        if ["builtin_drag", "builtin_nhe", "builtin_magic"].contains(item.configKey), !candidates.contains("james") {
            candidates.append("james")
        }
        if ["function_01", "function_02"].contains(item.configKey), !candidates.contains("huanha") {
            candidates.append("huanha")
        }
        for candidate in candidates {
            if let decoded = try? PatchPackageCodec.decode(data, password: candidate) {
                return decoded
            }
        }
        throw PatchPackageError.invalidPasswordOrCorruptedPackage
    }

    private static func uninstallDownloadedPackage(for item: RemoteAdminSwitch) throws {
        if let projectID = packageID(for: item), let existing = PatchProjectLibrary.load().first(where: { $0.id == projectID }) {
            try PatchProjectLibrary.delete(existing)
        }
        UserDefaults.standard.removeObject(forKey: packageIDKey(item))
    }

    private static func localPackageExists(for item: RemoteAdminSwitch) -> Bool {
        guard let projectID = packageID(for: item) else { return false }
        return PatchProjectLibrary.load().contains(where: { $0.id == projectID })
    }

    private static func writeMarker(for item: RemoteAdminSwitch) throws {
        let folder = try markerFolderURL()
        let marker = folder.appendingPathComponent(item.configKey + ".json")
        let payload: [String: Any] = [
            "config_key": item.configKey,
            "title": item.title,
            "enabled": true,
            "package_version": item.packageVersion,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try data.write(to: marker, options: [.atomic, .completeFileProtection])
    }

    private static func removeMarker(for item: RemoteAdminSwitch) throws {
        let marker = try markerFolderURL().appendingPathComponent(item.configKey + ".json")
        if FileManager.default.fileExists(atPath: marker.path) {
            try FileManager.default.removeItem(at: marker)
        }
    }

    private static func storageKey(_ item: RemoteAdminSwitch) -> String { "aujunpeak.remote.switch." + item.configKey }
    private static func packageIDKey(_ item: RemoteAdminSwitch) -> String { storageKey(item) + ".packageID" }
    private static func versionKey(_ item: RemoteAdminSwitch) -> String { storageKey(item) + ".version" }
    private static func hashKey(_ item: RemoteAdminSwitch) -> String { storageKey(item) + ".sha256" }

    private static func markerFolderURL() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("RemoteFunctions", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}

private struct KeyInfoOverlayView: View {
    @EnvironmentObject private var licenseSession: LicenseSession
    @State private var contentAppeared = false
    private let zaloURL = URL(string: "https://zalo.me/0833091543")!

    var body: some View {
        NavigationStack {
            ZStack {
                AppNeonBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        keyHeader
                        keyDetails
                        deviceDetails
                        adminCard
                    }
                    .frame(maxWidth: 860, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 12)
                }
                .refreshable { await licenseSession.refreshStatus() }
            }
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await licenseSession.refreshStatus() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.58, dampingFraction: 0.84).delay(0.05)) {
                    contentAppeared = true
                }
            }
        }
    }

    private var keyHeader: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.05, blue: 0.20),
                                Color(red: 0.04, green: 0.10, blue: 0.22),
                                Color.black
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 17) {
                    HStack(spacing: 11) {
                        AppLogo(size: 52)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("AUJUNPEAK VN")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("LICENSE CENTER")
                                .font(.caption2.weight(.bold))
                                .tracking(1.4)
                                .foregroundStyle(.white.opacity(0.62))
                        }

                        Spacer()

                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.secondaryAccent)
                    }

                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("KEY INFORMATION")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.76)
                            Text("Thông tin kích hoạt và thiết bị")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.68))
                                .lineLimit(2)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                        Spacer(minLength: 8)

                        Text(licenseStatusText)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(licenseStatusColor)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(licenseStatusColor.opacity(0.16), in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(licenseStatusColor.opacity(0.30), lineWidth: 1)
                            }
                    }
                }
                .padding(18)
            }
            .frame(height: 168)

            HStack(spacing: 0) {
                InfoHeroStat(
                    title: "THIẾT BỊ",
                    value: "\(licenseSession.license?.deviceCount ?? 0)/\(licenseSession.license?.maxDevices ?? 0)",
                    icon: "iphone"
                )

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 30)

                InfoHeroStat(
                    title: "THỜI HẠN",
                    value: "\(licenseSession.license?.durationDays ?? 0) ngày",
                    icon: "calendar"
                )

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 30)

                InfoHeroStat(
                    title: "VERSION",
                    value: AppUpdateChecker.currentVersion,
                    icon: "bolt.fill"
                )
            }
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.24))
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppTheme.accent.opacity(0.62), Color.blue.opacity(0.32), Color.white.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.22), radius: 10, y: 5)
    }

    private var keyDetails: some View {
        InfoCard(title: "KEY", icon: "key.horizontal.fill") {
            InfoLine(title: "Key", value: licenseSession.license?.key ?? licenseSession.storedKey, monospaced: true)
            Divider()
            InfoLine(title: "Trạng thái", value: licenseStatusText)
            Divider()
            InfoLine(title: "Kích hoạt", value: displayDate(licenseSession.license?.activatedAt))
            Divider()
            InfoLine(title: "Hết hạn", value: displayDate(licenseSession.license?.expiresAt))
            Divider()
            InfoLine(title: "Thời hạn", value: "\(licenseSession.license?.durationDays ?? 0) ngày")
            Divider()
            InfoLine(title: "Thiết bị", value: "\(licenseSession.license?.deviceCount ?? 0) / \(licenseSession.license?.maxDevices ?? 0)")

            Button {
                UIPasteboard.general.string = licenseSession.license?.key ?? licenseSession.storedKey
            } label: {
                Label("Sao chép Key", systemImage: "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .padding(.top, 4)
        }
    }

    private var deviceDetails: some View {
        InfoCard(title: "THIẾT BỊ", icon: "iphone") {
            InfoLine(title: "Model", value: AppInfo.hardwareDisplayName)
            Divider()
            InfoLine(title: "iOS", value: AppInfo.osVersion)
            Divider()
            InfoLine(title: "Build", value: AppInfo.osBuild, monospaced: true)
            Divider()
            InfoLine(title: "App version", value: AppUpdateChecker.currentVersion)
            Divider()
            InfoLine(title: "Device ID", value: licenseSession.deviceID, monospaced: true)
        }
    }

    private var adminCard: some View {
        InfoCard(title: "HỖ TRỢ", icon: "person.crop.circle.badge.checkmark") {
            HStack {
                Text("Admin").foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 5) {
                    Text("Hà Văn Huấn")
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue)
                }
            }
            Divider()
            InfoLine(title: "Panel", value: "Aujunpeak VN License")
            Divider()
            InfoLine(title: "Kênh liên hệ", value: "Zalo")
            Link(destination: zaloURL) {
                Label("Liên hệ Admin qua Zalo", systemImage: "message.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.top, 4)

            Button(role: .destructive) {
                licenseSession.forgetKey()
            } label: {
                Label("Đổi / đăng xuất Key", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
    }

    private var licenseIsActive: Bool { licenseSession.license?.status == "active" }
    private var licenseStatusColor: Color { licenseIsActive ? .green : .orange }

    private var licenseStatusText: String {
        switch licenseSession.license?.status {
        case "active": return "ĐANG HOẠT ĐỘNG"
        case "expired": return "ĐÃ HẾT HẠN"
        case "revoked": return "ĐÃ BỊ KHÓA"
        case "unused": return "CHƯA KÍCH HOẠT"
        default: return licenseSession.storedKey.isEmpty ? "CHƯA CÓ KEY" : "ĐANG ĐỒNG BỘ"
        }
    }

    private func displayDate(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "Chưa" }
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = input.date(from: raw) else { return raw }
        let output = DateFormatter()
        output.locale = Locale(identifier: "vi_VN")
        output.dateFormat = "dd/MM/yyyy HH:mm"
        return output.string(from: date)
    }
}

private struct InfoHeroStat: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.52))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct InfoCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.secondaryAccent.opacity(0.14))
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryAccent)
                }
                .frame(width: 28, height: 28)
                Text(title)
                    .font(.caption.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(0.72))
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(15)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            Capsule()
                .fill(AppTheme.secondaryAccent)
                .frame(width: 3)
                .padding(.vertical, 16)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 10, y: 5)
    }
}

private struct InfoLine: View {
    let title: String
    let value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 10)
            Text(value)
                .font(monospaced ? .caption.monospaced() : .subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
                .minimumScaleFactor(0.62)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct GameIconView: View {
    let gameKey: String
    let remoteURL: String?
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.06))

            if let url = normalizedRemoteURL {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.18))) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            fallbackImage
                                .opacity(0.34)
                            ProgressView()
                                .controlSize(.small)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    case .failure:
                        fallbackImage
                    @unknown default:
                        fallbackImage
                    }
                }
            } else {
                fallbackImage
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var fallbackImage: some View {
        if let asset = builtinAssetName {
            Image(asset)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: size * 0.35, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var normalizedRemoteURL: URL? {
        guard let raw = remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if let direct = URL(string: raw), direct.scheme != nil {
            return direct
        }
        if let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
           let url = URL(string: encoded), url.scheme != nil {
            return url
        }
        return nil
    }

    private var builtinAssetName: String? {
        switch gameKey {
        case "freefire": return "GameIconFreeFire"
        case "freefiremax": return "GameIconFreeFireMax"
        case "pubg": return "GameIconPUBG"
        case "lienquan": return "GameIconLienQuan"
        default: return nil
        }
    }
}


private struct SnowParticlesOverlay: View {
    private struct Flake {
        let seed: Double
        let size: CGFloat
        let speed: Double
        let sway: CGFloat
        let opacity: Double
        let drift: Double
    }

    private static let flakes: [Flake] = (0..<78).map { index in
        let i = Double(index)
        let seed = (i * 0.61803398875).truncatingRemainder(dividingBy: 1.0)
        let size = CGFloat(1.5 + ((i * 1.37).truncatingRemainder(dividingBy: 4.5)))
        let speed = 0.055 + ((i * 0.017).truncatingRemainder(dividingBy: 0.075))
        let sway = CGFloat(5 + ((i * 1.9).truncatingRemainder(dividingBy: 18)))
        let opacity = 0.18 + ((i * 0.071).truncatingRemainder(dividingBy: 0.52))
        let drift = 0.6 + ((i * 0.11).truncatingRemainder(dividingBy: 1.8))
        return Flake(seed: seed, size: size, speed: speed, sway: sway, opacity: opacity, drift: drift)
    }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                Canvas { context, size in
                    let width = max(size.width, 1)
                    let height = max(size.height, 1)
                    let time = timeline.date.timeIntervalSince1970

                    for flake in Self.flakes {
                        let cycle = (time * flake.speed + flake.seed).truncatingRemainder(dividingBy: 1.0)
                        let baseY = cycle * (height + 60) - 30
                        let wave = sin((time * flake.drift) + flake.seed * 12.0)
                        let xRatio = (flake.seed + wave * 0.018).truncatingRemainder(dividingBy: 1.0)
                        let x = ((xRatio < 0 ? xRatio + 1 : xRatio) * width)
                        let y = baseY
                        let rect = CGRect(
                            x: x,
                            y: y,
                            width: flake.size,
                            height: flake.size
                        )

                        context.opacity = flake.opacity
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(.white)
                        )

                        if flake.size >= 4.0 {
                            let arm = flake.size * 1.25
                            let center = CGPoint(x: x + flake.size / 2, y: y + flake.size / 2)
                            var sparkle = Path()
                            sparkle.move(to: CGPoint(x: center.x - arm, y: center.y))
                            sparkle.addLine(to: CGPoint(x: center.x + arm, y: center.y))
                            sparkle.move(to: CGPoint(x: center.x, y: center.y - arm))
                            sparkle.addLine(to: CGPoint(x: center.x, y: center.y + arm))
                            context.stroke(sparkle, with: .color(.white.opacity(0.45)), lineWidth: 0.6)
                        }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct AppNeonBackground: View {
    var body: some View {
        AppAnimatedBackground(opacity: 0.42)
    }
}
