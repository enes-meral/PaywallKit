import SwiftUI

/// Small capsule describing an introductory offer: "3 gün ücretsiz" / "3 days free".
/// Deliberately caption-sized so it never competes with the billed price.
public struct TrialBadge: View {
    @Environment(\.locale) private var locale
    private let offer: IntroductoryOffer

    public init(offer: IntroductoryOffer) {
        self.offer = offer
    }

    public var body: some View {
        Text(PriceFormatter(locale: locale).badgeText(for: offer))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.tint.opacity(0.15), in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }
}
