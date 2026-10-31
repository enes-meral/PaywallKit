import SwiftUI

/// Close ("X") button.
///
/// App Review: the paywall must be dismissible right away. This button has no delay,
/// fade-in or hidden state — it is rendered in the very first frame, with a 44×44 pt
/// hit area and a VoiceOver label.
public struct CloseButton: View {
    @Environment(\.locale) private var locale
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background(.thinMaterial, in: Circle())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n(locale: locale).string("button.close"))
        .accessibilityIdentifier("paywall.close")
        .transaction { $0.animation = nil }
    }
}
