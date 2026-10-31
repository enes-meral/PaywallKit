import XCTest

/// Checks the App Review guarantees on the real, rendered UI of every template.
final class TemplateUITests: XCTestCase {
    private static let templates = ["classic", "comparison", "vault", "stories"]

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ template: String, slowProducts: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-showPaywall", "-paywallStyle", template,
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if slowProducts { app.launchArguments.append("-slowProducts") }
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Products take 3 s to load here: the close button and the footer must already be
    /// on screen while the plans are still loading.
    func testCloseButtonAndFooterAreVisibleBeforePlansLoad() {
        for template in Self.templates {
            let app = launch(template, slowProducts: true)
            XCTAssertTrue(app.staticTexts["Loading plans…"].exists, "\(template): expected loading state")

            for identifier in ["paywall.close", "paywall.restore", "paywall.terms", "paywall.privacy"] {
                let item = element(app, identifier)
                XCTAssertTrue(item.exists, "\(template): \(identifier) missing while loading")
                XCTAssertTrue(item.isHittable, "\(template): \(identifier) not hittable while loading")
            }
            app.terminate()
        }
    }

    func testEveryTemplateShowsPlansDisclosureAndPurchaseControl() {
        for template in Self.templates {
            let app = launch(template)
            XCTAssertTrue(element(app, "paywall.plan.demo.yearly").waitForExistence(timeout: 5), "\(template): plans")
            XCTAssertTrue(element(app, "paywall.disclosure").exists, "\(template): disclosure")
            XCTAssertTrue(element(app, "paywall.purchase").isHittable, "\(template): purchase control")
            for identifier in ["paywall.close", "paywall.restore", "paywall.terms", "paywall.privacy"] {
                XCTAssertTrue(element(app, identifier).isHittable, "\(template): \(identifier)")
            }
            app.terminate()
        }
    }

    /// The disclosure is either fully inside the opaque pinned area (not touching its
    /// controls) or in the scroll view directly below the plans — and then it can be scrolled
    /// completely above the pinned area, including its gradient edge.
    func testDisclosureIsFullyVisibleAndNeverOverlapsPinnedArea() {
        for template in Self.templates {
            let app = launch(template)
            XCTAssertTrue(element(app, "paywall.plan.demo.yearly").waitForExistence(timeout: 5), template)
            let pinned = element(app, "paywall.pinnedFooter")
            let disclosure = element(app, "paywall.disclosure")
            XCTAssertTrue(pinned.exists, "\(template): pinned area")
            XCTAssertTrue(disclosure.exists, "\(template): disclosure")

            if pinned.frame.contains(disclosure.frame) {
                for identifier in ["paywall.purchase", "paywall.restore", "paywall.terms", "paywall.privacy"] {
                    XCTAssertFalse(disclosure.frame.intersects(element(app, identifier).frame),
                                   "\(template): disclosure overlaps \(identifier)")
                }
            } else {
                let plansBottom = planFrames(app).map(\.maxY).max() ?? 0
                XCTAssertGreaterThanOrEqual(disclosure.frame.minY, plansBottom - 1, "\(template): disclosure above plans")
                XCTAssertLessThan(disclosure.frame.minY - plansBottom, 40, "\(template): disclosure not directly below plans")

                var swipes = 0
                while disclosure.frame.maxY > pinned.frame.minY, swipes < 4 {
                    app.swipeUp()
                    swipes += 1
                }
                XCTAssertLessThanOrEqual(disclosure.frame.maxY, pinned.frame.minY + 0.5,
                                         "\(template): disclosure can't be scrolled clear of the pinned area")
                XCTAssertGreaterThanOrEqual(disclosure.frame.minY, 0, "\(template): disclosure scrolled off the top")
            }
            app.terminate()
        }
    }

    /// iPhone 17 Pro: table, the preselected (selected, first) plan and the disclosure are all
    /// visible without scrolling.
    func testComparisonFirstScreenShowsTableSelectedPlanAndDisclosure() {
        let app = launch("comparison")
        let yearly = element(app, "paywall.plan.demo.yearly")
        XCTAssertTrue(yearly.waitForExistence(timeout: 5))
        let pinned = element(app, "paywall.pinnedFooter")

        XCTAssertGreaterThanOrEqual(element(app, "paywall.comparisonTable").frame.minY, 0)
        XCTAssertTrue(yearly.isSelected, "Preselected plan must be selected")
        XCTAssertLessThan(yearly.frame.minY, element(app, "paywall.plan.demo.weekly").frame.minY, "Preselected plan first")
        XCTAssertLessThan(yearly.frame.minY, element(app, "paywall.plan.demo.monthly").frame.minY, "Preselected plan first")
        XCTAssertLessThanOrEqual(yearly.frame.maxY, pinned.frame.minY + 0.5, "Selected plan hidden by the pinned area")
        XCTAssertTrue(pinned.frame.contains(element(app, "paywall.disclosure").frame), "Disclosure not fully visible")
    }

    private func planFrames(_ app: XCUIApplication) -> [CGRect] {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'paywall.plan.'"))
            .allElementsBoundByIndex
            .map(\.frame)
    }

    func testCloseButtonDismissesEveryTemplate() {
        for template in Self.templates {
            let app = launch(template)
            let close = element(app, "paywall.close")
            close.tap()
            // The presenting screen stays in the accessibility tree under a full-screen
            // cover, so check that the paywall itself is gone.
            XCTAssertTrue(close.waitForNonExistence(timeout: 3), "\(template): not dismissed")
            XCTAssertTrue(app.buttons["demo.showPaywall"].isHittable, "\(template): home not reachable")
            app.terminate()
        }
    }

    // MARK: Vault slider

    func testVaultSliderReleasedEarlyDoesNotPurchase() {
        let app = launch("vault")
        let slider = element(app, "paywall.purchase")
        XCTAssertTrue(element(app, "paywall.plan.demo.yearly").waitForExistence(timeout: 5))

        drag(slider, to: 0.5)

        // Nothing purchased, still on the paywall.
        XCTAssertFalse(app.staticTexts["Pro unlocked"].waitForExistence(timeout: 3))
        XCTAssertTrue(element(app, "paywall.close").isHittable)
        XCTAssertTrue(slider.isHittable)
    }

    func testVaultSliderPastThresholdPurchases() {
        let app = launch("vault")
        let slider = element(app, "paywall.purchase")
        XCTAssertTrue(element(app, "paywall.plan.demo.yearly").waitForExistence(timeout: 5))

        drag(slider, to: 0.98)

        // The fake provider succeeds; the demo dismisses the paywall and shows Pro.
        XCTAssertTrue(app.staticTexts["Pro unlocked"].waitForExistence(timeout: 5))
    }

    /// Records nothing by itself: run with TEST_RUNNER_RECORD_VAULT=1 (xcodebuild passes it on
    /// as RECORD_VAULT) while
    /// `xcrun simctl io booted recordVideo` captures the screen (used for docs/vault.gif).
    func testVaultDemoForRecording() throws {
        guard ProcessInfo.processInfo.environment["RECORD_VAULT"] == "1" else {
            throw XCTSkip("Only used to record docs/vault.gif")
        }
        let app = XCUIApplication()
        // Slower fake purchase so the open lock stays on screen before the paywall closes.
        app.launchArguments = ["-showPaywall", "-paywallStyle", "vault", "-purchaseDelay", "2.5",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let slider = element(app, "paywall.purchase")
        XCTAssertTrue(element(app, "paywall.plan.demo.yearly").waitForExistence(timeout: 8))
        sleep(2)
        drag(slider, to: 0.98, velocity: 350)   // past 85%: lock opens, purchase starts
        XCTAssertTrue(app.staticTexts["Pro unlocked"].waitForExistence(timeout: 8))
    }

    private func drag(_ slider: XCUIElement, to fraction: CGFloat, velocity: CGFloat = 600) {
        let start = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.09, dy: 0.5))
        let end = slider.coordinate(withNormalizedOffset: CGVector(dx: fraction, dy: 0.5))
        start.press(forDuration: 0.15, thenDragTo: end,
                    withVelocity: XCUIGestureVelocity(velocity), thenHoldForDuration: 0.1)
    }
}
