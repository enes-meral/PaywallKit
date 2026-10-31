import SwiftUI

/// "Restore Purchases" button. Shows a spinner while `action` runs.
public struct RestoreButton: View {
    @Environment(\.locale) private var locale
    @State private var isRestoring = false
    private let action: () async -> Void

    public init(action: @escaping () async -> Void) {
        self.action = action
    }

    public var body: some View {
        let title = L10n(locale: locale).string("button.restore")
        Button {
            Task {
                isRestoring = true
                await action()
                isRestoring = false
            }
        } label: {
            ZStack {
                Text(title).opacity(isRestoring ? 0 : 1)
                if isRestoring { ProgressView() }
            }
        }
        .font(.footnote.weight(.semibold))
        .disabled(isRestoring)
        .accessibilityLabel(title)
        .accessibilityIdentifier("paywall.restore")
    }
}
