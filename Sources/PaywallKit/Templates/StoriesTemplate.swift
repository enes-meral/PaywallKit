import SwiftUI

/// Playback rules of `.stories`, kept separate so they can be unit tested.
enum StoryPlayback {
    static let pageDuration: TimeInterval = 5

    /// Auto-advance is off with Reduce Motion or VoiceOver, and pointless with one page.
    static func autoAdvances(reduceMotion: Bool, voiceOver: Bool, pageCount: Int) -> Bool {
        !reduceMotion && !voiceOver && pageCount > 1
    }

    static func index(after index: Int, count: Int) -> Int? {
        index + 1 < count ? index + 1 : nil
    }

    static func index(before index: Int) -> Int? {
        index > 0 ? index - 1 : nil
    }
}

/// `.stories`: full-screen pages with segmented progress bars. Tap right / left to move,
/// press and hold to pause. Plans, disclosure, button and links live in a fixed bottom
/// panel that is visible on every page, so users can buy before the story ends.
struct StoriesTemplate: View {
    @ObservedObject var model: PaywallViewModel
    let traits: PaywallTemplateTraits
    let pages: [PaywallStoryPage]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    @State private var index = 0
    @State private var movingForward = true
    /// Fill of the current page's progress bar (0…1), animated linearly by Core Animation.
    @State private var progress: CGFloat = 0
    @State private var isVisible = false
    @State private var isRunning = false
    @State private var runStartedAt = Date()
    @State private var elapsedBeforeRun: TimeInterval = 0
    @State private var advanceTask: Task<Void, Never>?

    private var autoAdvances: Bool {
        StoryPlayback.autoAdvances(reduceMotion: reduceMotion, voiceOver: voiceOverEnabled, pageCount: pages.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            storyArea
            bottomPanel
        }
        .background(backgrounds.ignoresSafeArea())
        .onAppear {
            isVisible = true
            startPage()
        }
        .onDisappear {
            isVisible = false
            stop()
        }
        .onChange(of: autoAdvances) { _ in startPage() }
    }

    // MARK: Story area

    private var storyArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            progressBars
                .padding(.leading, 16)
                .padding(.trailing, 64) // room for the close button
                .padding(.top, 20)

            if pages.indices.contains(index) {
                pageContent(pages[index])
                    .id(index)
                    .transition(pageTransition)
            }

            Spacer(minLength: 0)

            if voiceOverEnabled || reduceMotion {
                manualControls.padding(.horizontal, 24).padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .overlay(tapZones)
    }

    private func pageContent(_ page: PaywallStoryPage) -> some View {
        ViewThatFits(in: .vertical) {
            pageText(page)
            ScrollView { pageText(page) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n(locale: locale).format("stories.position", index + 1, pages.count))
    }

    private func pageText(_ page: PaywallStoryPage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(page.caption)
                .font(.subheadline.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.75))
            Text(page.title)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            page.content
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressBars: some View {
        HStack(spacing: 4) {
            ForEach(pages.indices, id: \.self) { barIndex in
                GeometryReader { proxy in
                    Capsule().fill(Color.white.opacity(0.25))
                        .overlay(alignment: .leading) {
                            Capsule().fill(Color.white)
                                .frame(width: proxy.size.width * fill(for: barIndex))
                        }
                }
                .frame(height: 3)
            }
        }
        .accessibilityHidden(true)
    }

    private func fill(for barIndex: Int) -> CGFloat {
        if barIndex < index { return 1 }
        if barIndex > index { return 0 }
        return autoAdvances ? progress : 1
    }

    /// Left third: previous. Right two thirds: next. Press and hold anywhere: pause.
    private var tapZones: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: proxy.size.width / 3)
                    .onTapGesture { goBack() }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { goForward() }
            }
            .onLongPressGesture(minimumDuration: 0.25, maximumDistance: 30, perform: {}, onPressingChanged: { pressing in
                pressing ? pause() : resume()
            })
        }
        .accessibilityHidden(true)
    }

    private var manualControls: some View {
        let l10n = L10n(locale: locale)
        return HStack {
            Button { goBack() } label: {
                Label(l10n.string("stories.previous"), systemImage: "chevron.left")
            }
            .disabled(StoryPlayback.index(before: index) == nil)
            Spacer()
            Button { goForward() } label: {
                Label(l10n.string("stories.next"), systemImage: "chevron.right")
                    .labelStyle(TrailingIconLabelStyle())
            }
            .disabled(StoryPlayback.index(after: index, count: pages.count) == nil)
        }
        .font(.subheadline.weight(.semibold))
        .tint(.white)
        .buttonStyle(.bordered)
    }

    private var backgrounds: some View {
        ZStack {
            Color.black
            ForEach(pages.indices, id: \.self) { pageIndex in
                LinearGradient(colors: gradientColors(pages[pageIndex].background),
                               startPoint: .top, endPoint: .bottom)
                    .opacity(pageIndex == index ? 1 : 0)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: index)
    }

    private func gradientColors(_ colors: [Color]) -> [Color] {
        colors.count >= 2 ? colors : (colors + [colors.first ?? .black, .black]).prefix(2).map { $0 }
    }

    private var pageTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: movingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: movingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    // MARK: Bottom panel

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView { planBlock }.frame(maxHeight: 280)
                } else {
                    planBlock
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            PinnedPaywallFooter(background: AnyShapeStyle(Color.clear)) {
                PurchaseButton(model: model)
                PaywallFooterLinks(model: model, items: traits.footerItems)
            }
        }
        .background(
            UnevenRoundedTop(radius: 24)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var planBlock: some View {
        VStack(spacing: 10) {
            PlanSelection(model: model, variant: traits.planCardVariant)
            SubscriptionDisclosure(product: model.selectedProduct)
        }
    }

    // MARK: Playback

    private func goForward() {
        guard let next = StoryPlayback.index(after: index, count: pages.count) else { return }
        show(next, forward: true)
    }

    private func goBack() {
        guard let previous = StoryPlayback.index(before: index) else {
            startPage() // restart the first page
            return
        }
        show(previous, forward: false)
    }

    private func show(_ newIndex: Int, forward: Bool) {
        movingForward = forward
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .easeInOut(duration: 0.3)) {
            index = newIndex
        }
        startPage()
    }

    /// Resets the current page's progress and starts the timer if auto-advance is on.
    private func startPage() {
        stop()
        elapsedBeforeRun = 0
        setProgressWithoutAnimation(0)
        resume()
    }

    private func resume() {
        guard autoAdvances, isVisible, !isRunning else { return }
        let remaining = max(StoryPlayback.pageDuration - elapsedBeforeRun, 0)
        isRunning = true
        runStartedAt = Date()
        withAnimation(.linear(duration: remaining)) { progress = 1 }
        advanceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            isRunning = false
            if StoryPlayback.index(after: index, count: pages.count) != nil {
                goForward()
            }
        }
    }

    private func pause() {
        guard isRunning else { return }
        stop()
        elapsedBeforeRun += Date().timeIntervalSince(runStartedAt)
        setProgressWithoutAnimation(CGFloat(min(elapsedBeforeRun / StoryPlayback.pageDuration, 1)))
    }

    private func stop() {
        advanceTask?.cancel()
        advanceTask = nil
        isRunning = false
    }

    private func setProgressWithoutAnimation(_ value: CGFloat) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { progress = value }
    }
}

/// Rounded top corners only (iOS 16 has no `UnevenRoundedRectangle`).
struct UnevenRoundedTop: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight],
                          cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}

/// Label with the icon after the title.
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
    }
}
