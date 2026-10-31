import SwiftUI

/// Terms of Use and Privacy Policy links. Both URLs are required.
public struct LegalLinks: View {
    @Environment(\.locale) private var locale
    private let termsURL: URL
    private let privacyURL: URL

    public init(termsURL: URL, privacyURL: URL) {
        self.termsURL = termsURL
        self.privacyURL = privacyURL
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                terms
                Text("·").foregroundStyle(.secondary).accessibilityHidden(true)
                privacy
            }
            VStack(spacing: 8) {
                terms
                privacy
            }
        }
        .font(.footnote)
    }

    private var terms: some View {
        Link(L10n(locale: locale).string("link.terms"), destination: termsURL)
            .accessibilityIdentifier("paywall.terms")
    }

    private var privacy: some View {
        Link(L10n(locale: locale).string("link.privacy"), destination: privacyURL)
            .accessibilityIdentifier("paywall.privacy")
    }
}
