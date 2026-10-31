import SwiftUI
import UIKit

/// Threshold logic of `SlideToConfirm`, kept separate so it can be unit tested.
enum SlideToConfirmThreshold {
    /// The thumb must travel at least this fraction of the track to confirm.
    static let completion: Double = 0.85

    /// Progress (0…1) for a drag offset on a track with `travel` points of movement.
    static func progress(offset: CGFloat, travel: CGFloat) -> Double {
        guard travel > 0, offset.isFinite else { return 0 }
        return min(max(Double(offset / travel), 0), 1)
    }

    /// `true` only when `progress` reached the completion threshold.
    static func isComplete(_ progress: Double) -> Bool {
        progress >= completion
    }
}

/// A "slide to confirm" control: drag the thumb past 85% of the track to confirm.
///
/// - Crossing the threshold plays a success haptic and calls `onComplete`. The thumb stays
///   at the end while `onComplete` runs, then springs back.
/// - Releasing before the threshold springs the thumb back; nothing happens.
/// - With VoiceOver on, or at accessibility Dynamic Type sizes, it renders as a regular
///   button. The slider also supports the default accessibility action (double-tap).
public struct SlideToConfirm: View {
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.locale) private var locale

    @State private var offset: CGFloat = 0
    @State private var isCompleting = false

    private let title: String
    private let buttonTitle: String?
    private let onComplete: @MainActor () async -> Void

    private let height: CGFloat = 60
    private let inset: CGFloat = 4

    /// - Parameters:
    ///   - title: Text on the track, e.g. "Slide to continue".
    ///   - buttonTitle: Title used when the control renders as a button (VoiceOver,
    ///     accessibility text sizes) and as the VoiceOver label. Defaults to `title`.
    ///   - onComplete: Called once when the user confirms.
    public init(title: String, buttonTitle: String? = nil, onComplete: @escaping @MainActor () async -> Void) {
        self.title = title
        self.buttonTitle = buttonTitle
        self.onComplete = onComplete
    }

    public var body: some View {
        if voiceOverEnabled || dynamicTypeSize.isAccessibilitySize {
            fallbackButton
        } else {
            slider
        }
    }

    // MARK: Slider

    private var slider: some View {
        GeometryReader { proxy in
            let thumb = height - inset * 2
            let travel = max(proxy.size.width - thumb - inset * 2, 0)
            let progress = SlideToConfirmThreshold.progress(offset: offset, travel: travel)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(Capsule().strokeBorder(.tint.opacity(0.45), lineWidth: 1))

                Capsule()
                    .fill(.tint.opacity(0.25))
                    .frame(width: offset + thumb + inset * 2)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.leading, thumb + inset * 3)
                    .padding(.trailing, inset * 3)
                    .frame(maxWidth: .infinity)
                    .opacity(1 - progress * 1.2)

                Circle()
                    .fill(.tint)
                    .overlay(thumbIcon)
                    .frame(width: thumb, height: thumb)
                    .padding(inset)
                    .offset(x: offset)
                    .gesture(dragGesture(travel: travel))
            }
        }
        .frame(height: height)
        .opacity(isEnabled ? 1 : 0.5)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(buttonTitle ?? title)
        .accessibilityHint(L10n(locale: locale).string("slide.hint"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { confirm(travel: nil) }
        .accessibilityIdentifier("paywall.purchase")
    }

    @ViewBuilder
    private var thumbIcon: some View {
        if isCompleting {
            ProgressView().tint(.black)
        } else {
            Image(systemName: "chevron.right.2")
                .font(.headline.weight(.bold))
                .foregroundStyle(.black.opacity(0.8))
        }
    }

    private func dragGesture(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard isEnabled, !isCompleting else { return }
                offset = min(max(value.translation.width, 0), travel)
                if SlideToConfirmThreshold.isComplete(SlideToConfirmThreshold.progress(offset: offset, travel: travel)) {
                    confirm(travel: travel)
                }
            }
            .onEnded { _ in
                guard !isCompleting else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { offset = 0 }
            }
    }

    // MARK: Fallback

    private var fallbackButton: some View {
        Button {
            confirm(travel: nil)
        } label: {
            ZStack {
                Text(buttonTitle ?? title).opacity(isCompleting ? 0 : 1)
                if isCompleting { ProgressView() }
            }
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isCompleting)
        .accessibilityIdentifier("paywall.purchase")
    }

    // MARK: Completion

    private func confirm(travel: CGFloat?) {
        guard isEnabled, !isCompleting else { return }
        isCompleting = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if let travel {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offset = travel }
        }
        Task { @MainActor in
            await onComplete()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) { offset = 0 }
            isCompleting = false
        }
    }
}
