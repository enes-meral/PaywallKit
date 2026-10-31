import SwiftUI

// Large, code-drawn visuals for the demo story pages. No external images.

/// Before / after comparison: drag the handle to reveal the edited ("after") scene.
struct BeforeAfterSlider: View {
    @State private var split: CGFloat = 0.5

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                LandscapeScene()                                   // after
                LandscapeScene()                                   // before
                    .saturation(0.05)
                    .contrast(0.7)
                    .brightness(-0.08)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: width * split)
                    }

                HStack {
                    chip("Before")
                    Spacer()
                    chip("After")
                }
                .padding(12)
                .frame(maxHeight: .infinity, alignment: .top)

                Rectangle()
                    .fill(.white)
                    .frame(width: 3)
                    .offset(x: width * split - 1.5)
                Circle()
                    .fill(.white)
                    .frame(width: 38, height: 38)
                    .overlay(Image(systemName: "arrow.left.and.right").font(.subheadline.weight(.bold)).foregroundStyle(.black))
                    .shadow(color: .black.opacity(0.3), radius: 6)
                    .offset(x: width * split - 19)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.25)))
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    split = min(max(value.location.x / max(width, 1), 0.05), 0.95)
                }
            )
        }
        .frame(height: 210)
        .accessibilityElement()
        .accessibilityLabel(Text("Before and after comparison"))
        .accessibilityValue(Text("\(Int((1 - split) * 100))% after"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: split = max(split - 0.1, 0.05)
            case .decrement: split = min(split + 0.1, 0.95)
            @unknown default: break
            }
        }
    }

    private func chip(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.black.opacity(0.45), in: Capsule())
            .foregroundStyle(.white)
    }
}

/// Sunset over mountains and a lake, drawn with gradients and paths.
struct LandscapeScene: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(colors: [Color(red: 1.0, green: 0.62, blue: 0.30),
                                        Color(red: 0.95, green: 0.35, blue: 0.50),
                                        Color(red: 0.45, green: 0.22, blue: 0.70)],
                               startPoint: .top, endPoint: .bottom)
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.95, blue: 0.6), Color(red: 1, green: 0.7, blue: 0.3)],
                                         center: .center, startRadius: 2, endRadius: size.width * 0.12))
                    .frame(width: size.width * 0.24)
                    .position(x: size.width * 0.66, y: size.height * 0.42)
                Mountains(peaks: [0.0: 0.62, 0.22: 0.34, 0.45: 0.55, 0.7: 0.30, 1.0: 0.58])
                    .fill(Color(red: 0.42, green: 0.20, blue: 0.55))
                Mountains(peaks: [0.0: 0.72, 0.3: 0.50, 0.55: 0.68, 0.82: 0.46, 1.0: 0.70])
                    .fill(Color(red: 0.20, green: 0.10, blue: 0.38))
                LinearGradient(colors: [Color(red: 0.30, green: 0.15, blue: 0.50), Color(red: 0.08, green: 0.05, blue: 0.20)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: size.height * 0.24)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                Capsule()
                    .fill(Color(red: 1, green: 0.8, blue: 0.45).opacity(0.55))
                    .frame(width: size.width * 0.18, height: 3)
                    .position(x: size.width * 0.66, y: size.height * 0.84)
            }
        }
    }
}

/// A mountain ridge through (x, y) points in unit coordinates.
struct Mountains: Shape {
    let peaks: KeyValuePairs<CGFloat, CGFloat>

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for (x, y) in peaks {
            path.addLine(to: CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Three fanned-out project cards.
struct StackedProjectsVisual: View {
    private let cards: [(colors: [Color], icon: String, angle: Double, x: CGFloat)] = [
        ([Color(red: 0.35, green: 0.85, blue: 0.95), Color(red: 0.20, green: 0.45, blue: 0.95)], "doc.richtext.fill", -10, -70),
        ([Color(red: 1.0, green: 0.70, blue: 0.35), Color(red: 0.95, green: 0.35, blue: 0.45)], "music.note", 9, 70),
        ([Color(red: 0.75, green: 0.55, blue: 1.0), Color(red: 0.45, green: 0.25, blue: 0.90)], "photo.fill.on.rectangle.fill", 0, 0)
    ]

    var body: some View {
        ZStack {
            ForEach(cards.indices, id: \.self) { index in
                let card = cards[index]
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: card.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: card.icon).font(.title2.weight(.semibold))
                            Spacer()
                            Capsule().frame(width: 90, height: 8).opacity(0.85)
                            Capsule().frame(width: 60, height: 8).opacity(0.55)
                        }
                        .foregroundStyle(.white)
                        .padding(16)
                    }
                    .frame(width: 150, height: 190)
                    .shadow(color: .black.opacity(0.3), radius: 14, y: 8)
                    .rotationEffect(.degrees(card.angle))
                    .offset(x: card.x)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 210)
        .accessibilityHidden(true)
    }
}

/// A grid of theme swatches.
struct ThemeGridVisual: View {
    private let themes: [[Color]] = [
        [Color(red: 1.0, green: 0.55, blue: 0.35), Color(red: 0.90, green: 0.25, blue: 0.50)],
        [Color(red: 0.30, green: 0.85, blue: 0.75), Color(red: 0.10, green: 0.45, blue: 0.70)],
        [Color(red: 0.95, green: 0.85, blue: 0.40), Color(red: 0.95, green: 0.50, blue: 0.20)],
        [Color(red: 0.60, green: 0.45, blue: 1.0), Color(red: 0.25, green: 0.20, blue: 0.65)],
        [Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.70, green: 0.72, blue: 0.80)],
        [Color(red: 0.25, green: 0.25, blue: 0.30), Color(red: 0.05, green: 0.05, blue: 0.08)]
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(themes.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: themes[index], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        Text("Aa")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(index == 4 ? Color.black.opacity(0.75) : .white)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.2)))
                    .frame(height: 92)
            }
        }
        .frame(height: 210)
        .accessibilityHidden(true)
    }
}
