import SwiftUI
import XCTest
@testable import PaywallKit

/// Guideline 3.1.2(c): the billed amount must be the most prominent price; calculated
/// equivalents may only be shown smaller and secondary.
final class PriceHierarchyTests: XCTestCase {
    private let formatter = PriceFormatter(locale: Fixtures.tr)

    func testBilledAmountIsAlwaysPresentFirstAndProminent() {
        for product in Fixtures.all {
            let hierarchy = PriceHierarchy(product: product, formatter: formatter, equivalentUnit: .week)
            XCTAssertEqual(hierarchy.lines.first, hierarchy.billed)
            XCTAssertEqual(hierarchy.billed.role, .billed)
            XCTAssertTrue(hierarchy.billed.isProminent)
            XCTAssertFalse(hierarchy.billed.text.isEmpty)
            XCTAssertEqual(hierarchy.billed.text, formatter.billedAmount(for: product))
        }
    }

    func testOnlyBilledLineIsProminent() {
        let hierarchy = PriceHierarchy(product: Fixtures.yearlyTrialTRY, formatter: formatter, equivalentUnit: .week)
        XCTAssertEqual(hierarchy.secondaryLines.count, 2)
        XCTAssertEqual(hierarchy.lines.filter(\.isProminent).count, 1)
    }

    func testDefaultTypographyKeepsEquivalentSmaller() throws {
        let hierarchy = PriceHierarchy(product: Fixtures.yearlyTRY, formatter: formatter, equivalentUnit: .week)
        let equivalent = try XCTUnwrap(hierarchy.equivalent)
        XCTAssertLessThan(equivalent.textStyle.sizeRank, hierarchy.billed.textStyle.sizeRank)
        XCTAssertTrue(hierarchy.satisfiesProminenceRule)
    }

    /// Exhaustive: no combination of text styles can make a secondary line as large as the billed one.
    func testProminenceRuleHoldsForEveryTypographyCombination() {
        for billed in Font.TextStyle.allIOSStyles {
            for secondary in Font.TextStyle.allIOSStyles {
                let typography = PriceTypography.clamped(billed: billed, secondary: secondary)
                XCTAssertLessThan(typography.secondary.sizeRank, typography.billed.sizeRank,
                                  "billed: \(billed), secondary: \(secondary)")
                for product in Fixtures.all {
                    let hierarchy = PriceHierarchy(product: product, formatter: formatter,
                                                   typography: typography, equivalentUnit: .week)
                    XCTAssertTrue(hierarchy.satisfiesProminenceRule,
                                  "billed: \(billed), secondary: \(secondary), product: \(product.id)")
                }
            }
        }
    }

    func testClampingLowersSecondaryStyle() {
        XCTAssertEqual(PriceTypography.clamped(billed: .body, secondary: .largeTitle).secondary, .callout)
        // headline and body share a point size, so body is not "smaller" than headline.
        XCTAssertEqual(PriceTypography.clamped(billed: .headline, secondary: .body).secondary, .callout)
        XCTAssertEqual(PriceTypography.clamped(billed: .title2, secondary: .caption).secondary, .caption)
    }

    func testSmallestBilledStyleIsRaised() {
        let typography = PriceTypography.clamped(billed: .caption2, secondary: .caption2)
        XCTAssertEqual(typography.billed, .caption)
        XCTAssertEqual(typography.secondary, .caption2)
    }

    func testEquivalentIsHiddenByDefault() {
        let hierarchy = PriceHierarchy(product: Fixtures.yearlyTRY, formatter: formatter)
        XCTAssertNil(hierarchy.equivalent)
        XCTAssertEqual(PaywallConfiguration(productIDs: [], termsOfServiceURL: URL(string: "https://example.com/t")!,
                                            privacyPolicyURL: URL(string: "https://example.com/p")!).equivalentPriceUnit, nil)
    }

    func testWeeklyPlanNeverShowsWeeklyEquivalent() {
        let hierarchy = PriceHierarchy(product: Fixtures.weeklyTRY, formatter: formatter, equivalentUnit: .week)
        XCTAssertNil(hierarchy.equivalent)
    }

    func testEquivalentNeverExistsWithoutBilledAmount() {
        for product in Fixtures.all {
            let hierarchy = PriceHierarchy(product: product, formatter: formatter, equivalentUnit: .week)
            if hierarchy.equivalent != nil {
                XCTAssertFalse(hierarchy.billed.text.isEmpty)
                XCTAssertNotEqual(hierarchy.equivalent?.text, hierarchy.billed.text)
            }
        }
    }

    func testTrialLineRepeatsBilledAmountInSecondaryStyle() throws {
        let hierarchy = PriceHierarchy(product: Fixtures.yearlyTrialTRY, formatter: formatter)
        let intro = try XCTUnwrap(hierarchy.introductoryOffer)
        XCTAssertTrue(intro.text.contains(hierarchy.billed.text))
        XCTAssertFalse(intro.isProminent)
        XCTAssertLessThan(intro.textStyle.sizeRank, hierarchy.billed.textStyle.sizeRank)
    }

    func testOnlyBoldWeightForBilled() {
        let hierarchy = PriceHierarchy(product: Fixtures.yearlyTrialTRY, formatter: formatter, equivalentUnit: .week)
        XCTAssertEqual(hierarchy.billed.font, .system(.title2, design: .default, weight: .bold))
        for line in hierarchy.secondaryLines {
            XCTAssertEqual(line.font, .system(.caption, design: .default, weight: .regular))
        }
    }
}
