import SwiftUI

/// Close ("X") button.
///
/// App Review: the paywall must be dismissible right away. This button has no delay,
/// fade-in or hidden state — it is rendered in the very first frame, with a 44×44 pt
/// hit area and a VoiceOver label.
public struct CloseButton: View {
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 32
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: min(diameter, 52), height: min(diameter, 52))
                .background(.thinMaterial, in: Circle())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Fixed chrome: scale with Dynamic Type, but cap so it never covers the content.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityLabel(L10n(locale: locale).string("button.close"))
        .accessibilityIdentifier("paywall.close")
        .transaction { $0.animation = nil }
    }
}
