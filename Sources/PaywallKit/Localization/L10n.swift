import Foundation

/// Looks up PaywallKit's own strings for an explicit locale.
///
/// SwiftUI's `\.locale` environment value is passed in, so previews and tests can render
/// any supported language deterministically. Unsupported languages fall back to English.
struct L10n {
    let locale: Locale
    private let bundle: Bundle

    init(locale: Locale) {
        self.locale = locale
        self.bundle = Self.bundle(for: locale)
    }

    func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }

    private static func bundle(for locale: Locale) -> Bundle {
        var candidates = [locale.identifier]
        if let language = locale.language.languageCode?.identifier { candidates.append(language) }
        candidates.append("en")
        for candidate in candidates {
            if let url = Bundle.module.url(forResource: candidate, withExtension: "lproj"),
               let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return Bundle.module
    }
}
