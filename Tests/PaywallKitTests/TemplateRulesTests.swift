import SwiftUI
import XCTest
@testable import PaywallKit

/// The App Review guarantees must hold for every template, not just `.classic`.
final class TemplateRulesTests: XCTestCase {
    private let formatter = PriceFormatter(locale: Fixtures.tr)

    private var allStyles: [(name: String, style: PaywallStyle)] {
        [
            ("classic", .classic),
            ("comparison", .comparison(rows: [ComparisonRow(title: "Sync", free: .notIncluded, pro: .included)])),
            ("vault", .vault),
            ("stories", .stories(pages: [PaywallStoryPage(caption: "1", title: "Page", background: [.blue, .black])]))
        ]
    }

    private func configuration(typography: PriceTypography) -> PaywallConfiguration {
        PaywallConfiguration(
            productIDs: Fixtures.all.map(\.id),
            termsOfServiceURL: URL(string: "https://example.com/terms")!,
            privacyPolicyURL: URL(string: "https://example.com/privacy")!,
            equivalentPriceUnit: .week,
            typography: typography
        )
    }

    // MARK: Prices

    func testBilledAmountIsMostProminentInEveryTemplate() {
        var typographies: [PriceTypography] = [.default, .compact]
        for billed in Font.TextStyle.allIOSStyles {
            for secondary in Font.TextStyle.allIOSStyles {
                typographies.append(.clamped(billed: billed, secondary: secondary))
            }
        }

        for (name, style) in allStyles {
            for typography in typographies {
                let rendered = style.traits.priceTypography(for: configuration(typography: typography))
                for product in Fixtures.all {
                    let hierarchy = PriceHierarchy(product: product, formatter: formatter,
                                                   typography: rendered, equivalentUnit: .week)
                    XCTAssertTrue(hierarchy.satisfiesProminenceRule,
                                  "\(name) · \(typography) · \(product.id)")
                }
            }
        }
    }

    func testCompactCardsUseCompactTypographyByDefaultAndKeepCustomTypography() {
        XCTAssertEqual(PlanCard.Variant.compact.resolvedTypography(.default), .compact)
        XCTAssertEqual(PlanCard.Variant.regular.resolvedTypography(.default), .default)

        let custom = PriceTypography.clamped(billed: .title3, secondary: .footnote)
        XCTAssertEqual(PlanCard.Variant.compact.resolvedTypography(custom), custom)
    }

    func testCompactTypographyKeepsSecondarySmaller() {
        XCTAssertLessThan(PriceTypography.compact.secondary.sizeRank, PriceTypography.compact.billed.sizeRank)
    }

    func testTemplatesUseExpectedPlanCardVariant() {
        XCTAssertEqual(PaywallStyle.classic.traits.planCardVariant, .regular)
        XCTAssertEqual(PaywallStyle.comparison(rows: []).traits.planCardVariant, .regular)
        XCTAssertEqual(PaywallStyle.vault.traits.planCardVariant, .compact)
        XCTAssertEqual(PaywallStyle.stories(pages: []).traits.planCardVariant, .compact)
    }

    // MARK: Close button, footer, disclosure

    func testCloseButtonAppearsWithoutDelayInEveryTemplate() {
        for (name, style) in allStyles {
            XCTAssertEqual(style.traits.closeButtonAppearanceDelay, 0, name)
        }
    }

    func testEveryTemplatePinsRestoreTermsAndPrivacy() {
        for (name, style) in allStyles {
            XCTAssertEqual(style.traits.footerItems, [.restore, .termsOfUse, .privacyPolicy], name)
            XCTAssertTrue(style.traits.footerIsPinnedOutsideScrollView, name)
        }
    }

    func testDisclosureIsNextToPlansInEveryTemplate() {
        for (name, style) in allStyles {
            XCTAssertTrue(style.traits.disclosureIsNextToPlans, name)
        }
    }

    func testOnlyVaultUsesSlideToConfirm() {
        for (name, style) in allStyles {
            let expected: PaywallPurchaseControl = name == "vault" ? .slideToConfirm : .button
            XCTAssertEqual(style.traits.purchaseControl, expected, name)
        }
    }

    func testClassicFollowsSystemAppearanceAndOthersAreDark() {
        XCTAssertNil(PaywallStyle.classic.traits.forcedColorScheme)
        XCTAssertEqual(PaywallStyle.comparison(rows: []).traits.forcedColorScheme, .dark)
        XCTAssertEqual(PaywallStyle.vault.traits.forcedColorScheme, .dark)
        XCTAssertEqual(PaywallStyle.stories(pages: []).traits.forcedColorScheme, .dark)
    }
}

final class SlideToConfirmThresholdTests: XCTestCase {
    func testThresholdIs85Percent() {
        XCTAssertEqual(SlideToConfirmThreshold.completion, 0.85)
    }

    func testBelowThresholdDoesNotComplete() {
        XCTAssertFalse(SlideToConfirmThreshold.isComplete(0))
        XCTAssertFalse(SlideToConfirmThreshold.isComplete(0.5))
        XCTAssertFalse(SlideToConfirmThreshold.isComplete(0.849))
        XCTAssertFalse(SlideToConfirmThreshold.isComplete(0.8499999))
    }

    func testAtOrAboveThresholdCompletes() {
        XCTAssertTrue(SlideToConfirmThreshold.isComplete(0.85))
        XCTAssertTrue(SlideToConfirmThreshold.isComplete(0.9))
        XCTAssertTrue(SlideToConfirmThreshold.isComplete(1))
    }

    func testDragOffsetMapsToProgress() {
        // 300 pt of travel: 254 pt is 84.7% (not enough), 255 pt is exactly 85%.
        XCTAssertFalse(SlideToConfirmThreshold.isComplete(SlideToConfirmThreshold.progress(offset: 254, travel: 300)))
        XCTAssertTrue(SlideToConfirmThreshold.isComplete(SlideToConfirmThreshold.progress(offset: 255, travel: 300)))
        XCTAssertEqual(SlideToConfirmThreshold.progress(offset: 150, travel: 300), 0.5, accuracy: 0.0001)
    }

    func testProgressIsClampedAndSafe() {
        XCTAssertEqual(SlideToConfirmThreshold.progress(offset: -40, travel: 300), 0)
        XCTAssertEqual(SlideToConfirmThreshold.progress(offset: 900, travel: 300), 1)
        XCTAssertEqual(SlideToConfirmThreshold.progress(offset: 100, travel: 0), 0, "Zero-width track never completes")
        XCTAssertEqual(SlideToConfirmThreshold.progress(offset: .infinity, travel: 300), 0)
    }
}

final class StoryPlaybackTests: XCTestCase {
    func testPagesLastFiveSeconds() {
        XCTAssertEqual(StoryPlayback.pageDuration, 5)
    }

    func testAutoAdvanceRules() {
        XCTAssertTrue(StoryPlayback.autoAdvances(reduceMotion: false, voiceOver: false, pageCount: 3))
        XCTAssertFalse(StoryPlayback.autoAdvances(reduceMotion: true, voiceOver: false, pageCount: 3), "Reduce Motion stops auto-advance")
        XCTAssertFalse(StoryPlayback.autoAdvances(reduceMotion: false, voiceOver: true, pageCount: 3), "VoiceOver stops auto-advance")
        XCTAssertFalse(StoryPlayback.autoAdvances(reduceMotion: false, voiceOver: false, pageCount: 1))
    }

    func testNavigationStopsAtBothEnds() {
        XCTAssertEqual(StoryPlayback.index(after: 0, count: 3), 1)
        XCTAssertEqual(StoryPlayback.index(after: 1, count: 3), 2)
        XCTAssertNil(StoryPlayback.index(after: 2, count: 3))
        XCTAssertEqual(StoryPlayback.index(before: 2), 1)
        XCTAssertNil(StoryPlayback.index(before: 0))
    }
}
