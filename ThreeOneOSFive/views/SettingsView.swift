import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    private let zaloURL = URL(string: "https://zalo.me/0833091543")!

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.darkCanvas.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        AppLogo(size: 92)

                        VStack(spacing: 6) {
                            Text("Aujunpeak VN")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Hà Văn Huấn")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.78))
                        }

                        AppGlassPanel(cornerRadius: 22, tint: AppTheme.secondaryAccent) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Thông tin")
                                    .font(.headline.weight(.bold))
                                InfoRow(title: "Ứng dụng", value: "Aujunpeak")
                                InfoRow(title: "Thương hiệu", value: "Aujunpeak VN")
                                InfoRow(title: "Quản trị", value: "Hà Văn Huấn")
                            }
                            .foregroundStyle(.white)
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Link(destination: zaloURL) {
                            HStack(spacing: 12) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 18, weight: .bold))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Liên hệ Zalo")
                                        .font(.headline.weight(.bold))
                                    Text("0833 091 543")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.78))
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.headline.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.accent, AppTheme.hotPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Aujunpeak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(AppTheme.accent)
    }
}

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(.white.opacity(0.62))
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline.weight(.semibold))
    }
}
