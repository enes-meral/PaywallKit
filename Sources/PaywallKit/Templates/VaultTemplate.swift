import SwiftUI

/// `.vault`: dark background, glowing gold lock with two orbit rings, two-part plan
/// segment and `SlideToConfirm` instead of a button.
struct VaultTemplate<Header: View>: View {
    @ObservedObject var model: PaywallViewModel
    let traits: PaywallTemplateTraits
    let header: Header

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var closeButtonClearance: CGFloat = 56

    @State private var isUnlocked = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VaultLockArt(isUnlocked: isUnlocked)
                header
                PlanSelection(model: model, variant: traits.planCardVariant)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                SubscriptionDisclosure(product: model.selectedProduct)
            }
            .padding(.horizontal, 20)
            .padding(.top, min(closeButtonClearance, 76))
            .padding(.bottom, 16)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(backdrop.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PinnedPaywallFooter(fill: traits.footerFill) {
                let titles = PurchaseTitles(locale: locale, product: model.selectedProduct)
                SlideToConfirm(title: titles.slide, buttonTitle: titles.button) {
                    await unlockAndPurchase()
                }
                .disabled(model.selectedProduct == nil)
                PaywallFooterLinks(model: model, items: traits.footerItems)
            }
        }
    }

    private var backdrop: some View {
        ZStack {
            PaywallPalette.night
            RadialGradient(colors: [PaywallPalette.amber.opacity(0.22), .clear],
                           center: UnitPoint(x: 0.5, y: 0.22), startRadius: 0, endRadius: 420)
        }
    }

    /// Opens the shackle, then starts the purchase. The lock closes again if the purchase
    /// doesn't complete (cancelled, failed, pending).
    @MainActor private func unlockAndPurchase() async {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.55)) {
            isUnlocked = true
        }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 650))
        await model.purchaseSelected()
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.7)) {
            isUnlocked = false
        }
    }
}

/// Glowing lock with two slowly rotating orbit rings. Decorative (hidden from VoiceOver).
/// The rings only rotate while the view is on screen and Reduce Motion is off.
struct VaultLockArt: View {
    let isUnlocked: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    private var rotates: Bool { isVisible && !reduceMotion }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [PaywallPalette.amber.opacity(0.55), PaywallPalette.amber.opacity(0.12), .clear],
                    center: .center, startRadius: 8, endRadius: 150))
                .frame(width: 300, height: 300)

            OrbitRing(diameter: 236, dotSize: 7, period: 30, clockwise: true, rotates: rotates)
            OrbitRing(diameter: 172, dotSize: 5, period: 20, clockwise: false, rotates: rotates)

            VaultLockGlyph(isUnlocked: isUnlocked)
        }
        .frame(height: 250)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .accessibilityHidden(true)
    }
}

/// A thin ring with one bright dot, rotating with `repeatForever` while `rotates` is true.
struct OrbitRing: View {
    let diameter: CGFloat
    let dotSize: CGFloat
    let period: Double
    let clockwise: Bool
    let rotates: Bool

    @State private var angle: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(PaywallPalette.gold.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
            Circle()
                .fill(PaywallPalette.gold)
                .frame(width: dotSize, height: dotSize)
                .shadow(color: PaywallPalette.gold, radius: 6)
                .offset(y: -diameter / 2)
        }
        .frame(width: diameter, height: diameter)
        .rotationEffect(.degrees(angle))
        .onAppear { update(rotates) }
        .onChange(of: rotates) { update($0) }
    }

    private func update(_ rotates: Bool) {
        if rotates {
            withAnimation(.linear(duration: period).repeatForever(autoreverses: false)) {
                angle = clockwise ? 360 : -360
            }
        } else {
            // Stop: jump back without animating.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { angle = 0 }
        }
    }
}

/// Gold padlock. When `isUnlocked`, the shackle lifts and swings open around its right leg.
/// With Reduce Motion the locked and unlocked states crossfade instead of moving.
struct VaultLockGlyph: View {
    let isUnlocked: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            ZStack {
                PadlockShape(shackleOpen: false).opacity(isUnlocked ? 0 : 1)
                PadlockShape(shackleOpen: true).opacity(isUnlocked ? 1 : 0)
            }
        } else {
            PadlockShape(shackleOpen: isUnlocked)
        }
    }
}

/// The padlock drawing in a fixed state.
struct PadlockShape: View {
    let shackleOpen: Bool

    private let gold = LinearGradient(colors: [PaywallPalette.gold, PaywallPalette.goldDeep],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)

    var body: some View {
        ZStack(alignment: .top) {
            Shackle()
                .stroke(gold, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .frame(width: 62, height: 74)
                .rotationEffect(.degrees(shackleOpen ? -32 : 0), anchor: .bottomTrailing)
                .offset(y: shackleOpen ? -16 : 0)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(gold)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                )
                .overlay(keyhole)
                .frame(width: 106, height: 86)
                .shadow(color: PaywallPalette.amber.opacity(0.7), radius: 26)
                .offset(y: 58)
        }
        .frame(width: 110, height: 150, alignment: .top)
    }

    private var keyhole: some View {
        VStack(spacing: -2) {
            Circle().frame(width: 16, height: 16)
            RoundedRectangle(cornerRadius: 2).frame(width: 7, height: 16)
        }
        .foregroundStyle(Color.black.opacity(0.55))
    }
}

/// U-shaped shackle path.
struct Shackle: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = rect.width / 2
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(center: CGPoint(x: rect.midX, y: rect.minY + radius), radius: radius,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}
