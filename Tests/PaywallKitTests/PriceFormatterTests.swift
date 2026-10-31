import XCTest
@testable import PaywallKit

final class PriceFormatterTests: XCTestCase {
    private let tr = PriceFormatter(locale: Fixtures.tr)
    private let en = PriceFormatter(locale: Fixtures.en)

    // MARK: Billed amount

    func testBilledAmountTurkish() {
        XCTAssertEqual(normalized(tr.billedAmount(for: Fixtures.yearlyTRY)), "₺599,99/yıl")
        XCTAssertEqual(normalized(tr.billedAmount(for: Fixtures.monthlyTRY)), "₺199,99/ay")
        XCTAssertEqual(normalized(tr.billedAmount(for: Fixtures.weeklyTRY)), "₺79,99/hafta")
        XCTAssertEqual(normalized(tr.billedAmount(for: Fixtures.product("9.99", period: .days(1)))), "₺9,99/gün")
    }

    func testBilledAmountEnglish() {
        XCTAssertEqual(normalized(en.billedAmount(for: Fixtures.yearlyUSD)), "$59.99/year")
        XCTAssertEqual(normalized(en.billedAmount(for: Fixtures.product("4.99", "USD", period: .weekly))), "$4.99/week")
    }

    func testBilledAmountMultiUnitPeriod() {
        XCTAssertEqual(normalized(en.billedAmount(for: Fixtures.quarterlyUSD)), "$29.99 / 3 months")
        XCTAssertEqual(normalized(tr.billedAmount(for: Fixtures.product("299.99", period: .months(3)))), "₺299,99 / 3 ay")
        XCTAssertEqual(normalized(en.billedAmount(for: Fixtures.product("99.99", "USD", period: .years(2)))), "$99.99 / 2 years")
    }

    func testBilledAmountOneTimePurchase() {
        XCTAssertEqual(normalized(tr.billedAmount(for: Fixtures.lifetimeTRY)), "₺999,99 · tek seferlik")
        XCTAssertEqual(normalized(en.billedAmount(for: Fixtures.product("19.99", "USD", period: nil))), "$19.99 · one-time")
    }

    func testCurrencyComesFromProductNotLocale() {
        let usdInTurkish = normalized(tr.billedAmount(for: Fixtures.yearlyUSD))
        XCTAssertEqual(usdInTurkish?.contains("59,99"), true)
        XCTAssertEqual(usdInTurkish?.contains("$"), true)
        XCTAssertEqual(usdInTurkish?.hasSuffix("/yıl"), true)
    }

    func testUnsupportedLanguageFallsBackToEnglish() {
        let german = PriceFormatter(locale: Locale(identifier: "de_DE"))
        XCTAssertEqual(german.billedAmount(for: Fixtures.yearlyUSD).hasSuffix("/year"), true)
    }

    // MARK: Equivalents

    func testWeeklyEquivalentOfYearlyPlan() {
        // 599.99 / 52 = 11.538… → 11.54
        XCTAssertEqual(normalized(tr.equivalent(for: Fixtures.yearlyTRY, per: .week)), "≈ ₺11,54/hafta")
        XCTAssertEqual(normalized(en.equivalent(for: Fixtures.yearlyUSD, per: .week)), "≈ $1.15/week")
    }

    func testWeeklyEquivalentOfMonthlyPlan() {
        // 199.99 × 12 / 52 = 46.151… → 46.15
        XCTAssertEqual(normalized(tr.equivalent(for: Fixtures.monthlyTRY, per: .week)), "≈ ₺46,15/hafta")
    }

    func testMonthlyEquivalentOfYearlyPlan() {
        // 599.99 / 12 = 49.999… → 50.00
        XCTAssertEqual(normalized(tr.equivalent(for: Fixtures.yearlyTRY, per: .month)), "≈ ₺50,00/ay")
    }

    func testEquivalentAmountPrecision() {
        let value = tr.equivalentAmount(for: Fixtures.yearlyTRY, per: .week)!
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 2, .plain)
        XCTAssertEqual(rounded, Decimal(string: "11.54"))
    }

    func testNoEquivalentWhenPeriodIsNotLongerThanUnit() {
        XCTAssertNil(tr.equivalent(for: Fixtures.weeklyTRY, per: .week), "A weekly plan must not show a weekly equivalent")
        XCTAssertNil(tr.equivalent(for: Fixtures.monthlyTRY, per: .month))
        XCTAssertNil(tr.equivalent(for: Fixtures.weeklyTRY, per: .month))
        XCTAssertNil(tr.equivalent(for: Fixtures.lifetimeTRY, per: .week), "One-time purchases have no equivalent")
    }

    // MARK: Introductory offers

    func testFreeTrialTextAlwaysNamesBilledAmount() {
        XCTAssertEqual(normalized(tr.introductoryOfferText(for: Fixtures.yearlyTrialTRY)), "3 gün ücretsiz, sonra ₺599,99/yıl")
        let enTrial = Fixtures.product("59.99", "USD", period: .yearly, offer: .freeTrial(.weeks(1)))
        XCTAssertEqual(normalized(en.introductoryOfferText(for: enTrial)), "Free for 1 week, then $59.99/year")
    }

    func testPayAsYouGoOffer() {
        let offer = IntroductoryOffer(kind: .payAsYouGo, price: Decimal(string: "4.99")!, period: .monthly, periodCount: 3)
        let product = Fixtures.product("9.99", "USD", period: .monthly, offer: offer)
        XCTAssertEqual(normalized(en.introductoryOfferText(for: product)), "$4.99/month for the first 3 months, then $9.99/month")
    }

    func testPayUpFrontOffer() {
        let offer = IntroductoryOffer(kind: .payUpFront, price: Decimal(string: "99.99")!, period: .months(6))
        let product = Fixtures.product("199.99", period: .monthly, offer: offer)
        XCTAssertEqual(normalized(tr.introductoryOfferText(for: product)), "İlk 6 ay ₺99,99, sonra ₺199,99/ay")
    }

    func testNoOfferText() {
        XCTAssertNil(tr.introductoryOfferText(for: Fixtures.yearlyTRY))
    }

    func testBadgeText() {
        XCTAssertEqual(tr.badgeText(for: .freeTrial(.days(3))), "3 gün ücretsiz")
        XCTAssertEqual(en.badgeText(for: .freeTrial(.days(7))), "7 days free")
        let discount = IntroductoryOffer(kind: .payUpFront, price: 1, period: .monthly)
        XCTAssertEqual(en.badgeText(for: discount), "Intro offer")
    }

    func testDurationPluralization() {
        XCTAssertEqual(en.duration(.days(1)), "1 day")
        XCTAssertEqual(en.duration(.days(3)), "3 days")
        XCTAssertEqual(en.duration(.years(1)), "1 year")
        XCTAssertEqual(tr.duration(.days(1)), "1 gün")
        XCTAssertEqual(tr.duration(.months(6)), "6 ay")
    }

    // MARK: Accessibility

    func testAccessibilityLabelsAvoidSlashes() {
        XCTAssertEqual(normalized(tr.billedAmountAccessibilityLabel(for: Fixtures.yearlyTRY)), "yılda ₺599,99")
        XCTAssertEqual(normalized(en.billedAmountAccessibilityLabel(for: Fixtures.yearlyUSD)), "$59.99 per year")
        XCTAssertEqual(normalized(en.billedAmountAccessibilityLabel(for: Fixtures.quarterlyUSD)), "$29.99 every 3 months")
        XCTAssertEqual(normalized(tr.equivalentAccessibilityLabel(for: Fixtures.yearlyTRY, per: .week)), "yaklaşık haftada ₺11,54")
    }
}
