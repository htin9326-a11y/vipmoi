import SwiftUI
import ImageIO


enum AppTheme {
    static let accent = Color(red: 0.16, green: 0.42, blue: 0.86)
    static let secondaryAccent = Color(red: 0.08, green: 0.61, blue: 0.61)
    static let hotPink = Color(red: 0.90, green: 0.34, blue: 0.48)
    static let darkCanvas = Color(red: 0.95, green: 0.97, blue: 0.98)
    static let panel = Color.white
    static let panelBorder = Color(red: 0.83, green: 0.88, blue: 0.91)
    static let primaryText = Color(red: 0.08, green: 0.12, blue: 0.18)
    static let secondaryText = Color(red: 0.38, green: 0.44, blue: 0.50)
    static let softBlue = Color(red: 0.91, green: 0.95, blue: 1.00)
    static let softMint = Color(red: 0.90, green: 0.97, blue: 0.96)
    static let contentMaxWidth: CGFloat = 860
    static let compactPageInset: CGFloat = 14
    static let pageBackground = Color(red: 0.95, green: 0.97, blue: 0.97)
    static let consoleBackground = Color(red: 0.91, green: 0.94, blue: 0.95)
    static let pageInset: CGFloat = 16
    static let rowIconSize: CGFloat = 17
    static let rowIconFrame: CGFloat = 28
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 30
    static let fileRowHeight: CGFloat = 60
    static let appIconSize: CGFloat = 32
    static let emptyIconSize: CGFloat = 30
    static let selectionIconSize: CGFloat = 18
    static let contentCardCornerRadius: CGFloat = 20
    static let contentCardInset: CGFloat = 16
    static let contentCardPadding: CGFloat = 16
}

struct AppCardBorder: View {
    var body: some View {
        RoundedRectangle(
            cornerRadius: AppTheme.contentCardCornerRadius,
            style: .continuous
        )
        .strokeBorder(
            Color(uiColor: .separator).opacity(0.22),
            lineWidth: 0.5
        )
        .accessibilityHidden(true)
    }
}

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.12))
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: frameSize, height: frameSize)
        .accessibilityHidden(true)
    }
}

struct AppSearchField: View {
    @Binding var text: String
    let prompt: String
    let clearLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 36)
        .background(
            Color(uiColor: .secondarySystemFill),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let logo = UIImage(named: "AujunpeakLogo") {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFill()
            } else if let icon = UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }
}


// MARK: - Aujunpeak VN animated background
struct AnimatedGIFView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        configure(view)
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if !uiView.isAnimating {
            configure(uiView)
        }
    }

    private func configure(_ view: UIImageView) {
        let result = Self.frames(from: data)
        view.animationImages = result.images
        view.animationDuration = result.duration
        view.animationRepeatCount = 0
        view.startAnimating()
    }

    private static func frames(from data: Data) -> (images: [UIImage], duration: TimeInterval) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return ([], 0)
        }

        let count = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var duration: TimeInterval = 0

        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }

            var delay: TimeInterval = 0.08
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
               let gif = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                let clamped = gif[kCGImagePropertyGIFDelayTime as String] as? Double
                delay = max(unclamped ?? clamped ?? 0.08, 0.04)
            }

            images.append(UIImage(cgImage: cgImage))
            duration += delay
        }

        return (images, max(duration, 0.8))
    }
}

/// Shared surface used by the redesigned screens. Keeping the treatment here
/// means every tab feels like part of one app without touching any feature code.
struct AppGlassPanel<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 22
    var tint: Color = AppTheme.accent

    init(
        cornerRadius: CGFloat = 22,
        tint: Color = AppTheme.accent,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.panelBorder, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.07), radius: 16, y: 7)
    }
}

struct AppCapsuleBadge: View {
    let title: String
    let icon: String
    var tint: Color = AppTheme.secondaryAccent

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.12), in: Capsule())
            .overlay {
                Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 1)
            }
    }
}

struct AppGradientButtonStyle: ButtonStyle {
    var colors: [Color] = [AppTheme.secondaryAccent, AppTheme.accent]

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(color: colors.first?.opacity(0.18) ?? .clear, radius: 9, y: 4)
    }
}

struct AppAnimatedBackground: View {
    var opacity: Double = 0.48

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.pageBackground
                Circle()
                    .fill(AppTheme.softBlue.opacity(0.72))
                    .frame(width: min(proxy.size.width * 0.86, 440))
                    .blur(radius: 30)
                    .offset(x: proxy.size.width * 0.34, y: -proxy.size.height * 0.33)
                Circle()
                    .fill(AppTheme.softMint.opacity(0.76))
                    .frame(width: min(proxy.size.width * 0.78, 380))
                    .blur(radius: 34)
                    .offset(x: -proxy.size.width * 0.40, y: proxy.size.height * 0.36)
                LinearGradient(
                    colors: [Color.white.opacity(0.12), Color.clear, Color.white.opacity(0.22)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }
}

struct AppAuroraBackground: View {
    var body: some View {
        AppAnimatedBackground(opacity: 0.52)
    }
}
