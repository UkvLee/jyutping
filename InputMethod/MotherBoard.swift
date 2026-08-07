import SwiftUI
import CommonExtensions

struct MotherBoard: View {
        @EnvironmentObject private var context: InputContext
        private let pageCornerRadius: CGFloat = CGFloat(AppSettings.pageCornerRadius)
        private let contentInsets: CGFloat = CGFloat(AppSettings.contentInsets)
        private let verticalSpacing: CGFloat = 4 - (PresetConstant.contentWindowGap * 2)
        private let isThickerGlassPreferred: Bool = AppSettings.isThickerGlassPreferred
        var body: some View {
                ZStack(alignment: context.quadrant.alignment) {
                        Color.clear
                        VStack(alignment: .leading, spacing: verticalSpacing) {
                                if #available(macOS 26.0, *) {
                                        switch context.quadrant {
                                        case .upperRight, .upperLeft:
                                                if context.isReverseLookup.negative {
                                                        GlassIndicatorBar()
                                                }
                                        case .bottomLeft, .bottomRight:
                                                if context.isReverseLookup {
                                                        GlassIndicatorBar()
                                                }
                                        }
                                        switch context.inputForm {
                                        case .options:
                                                ZStack {
                                                        Color.clear.glassEffect(in: .rect(cornerRadius: pageCornerRadius))
                                                        OptionsView()
                                                                .padding(contentInsets)
                                                                .clipShape(.rect(cornerRadius: pageCornerRadius))
                                                }
                                                .padding(PresetConstant.contentWindowGap)
                                                .fixedSize()
                                        case .cantonese where context.displayCandidates.isNotEmpty:
                                                ZStack {
                                                        Color.clear.glassEffect(in: .rect(cornerRadius: pageCornerRadius))
                                                        if isThickerGlassPreferred {
                                                                CandidateStackView()
                                                                        .padding(contentInsets)
                                                                        .background(VisualEffectView())
                                                                        .clipShape(.rect(cornerRadius: pageCornerRadius))
                                                        } else {
                                                                CandidateStackView()
                                                                        .padding(contentInsets)
                                                                        .clipShape(.rect(cornerRadius: pageCornerRadius))
                                                        }
                                                }
                                                .padding(PresetConstant.contentWindowGap)
                                                .fixedSize()
                                        default:
                                                Color.clear
                                        }
                                        switch context.quadrant {
                                        case .upperRight, .upperLeft:
                                                if context.isReverseLookup {
                                                        GlassIndicatorBar()
                                                }
                                        case .bottomLeft, .bottomRight:
                                                if context.isReverseLookup.negative {
                                                        GlassIndicatorBar()
                                                }
                                        }
                                } else {
                                        switch context.quadrant {
                                        case .upperRight, .upperLeft:
                                                if context.isReverseLookup.negative {
                                                        IndicatorBar()
                                                }
                                        case .bottomLeft, .bottomRight:
                                                if context.isReverseLookup {
                                                        IndicatorBar()
                                                }
                                        }
                                        switch context.inputForm {
                                        case .options:
                                                OptionsView()
                                                        .padding(contentInsets)
                                                        .background(VisualEffectView())
                                                        .clipShape(.rect(cornerRadius: pageCornerRadius))
                                                        .shadow(radius: 2)
                                                        .padding(PresetConstant.contentWindowGap)
                                                        .fixedSize()
                                        case .cantonese where context.displayCandidates.isNotEmpty:
                                                CandidateStackView()
                                                        .padding(contentInsets)
                                                        .background(VisualEffectView())
                                                        .clipShape(.rect(cornerRadius: pageCornerRadius))
                                                        .shadow(radius: 2)
                                                        .padding(PresetConstant.contentWindowGap)
                                                        .fixedSize()
                                        default:
                                                Color.clear
                                        }
                                        switch context.quadrant {
                                        case .upperRight, .upperLeft:
                                                if context.isReverseLookup {
                                                        IndicatorBar()
                                                }
                                        case .bottomLeft, .bottomRight:
                                                if context.isReverseLookup.negative {
                                                        IndicatorBar()
                                                }
                                        }
                                }
                        }
                        .fixedSize()
                        .onGeometryChange(for: CGSize.self) { proxy in
                                proxy.size
                        } action: { newSize in
                                guard context.quadrant.isNegativeHorizontal else { return }
                                NotificationCenter.default.post(name: .contentSize, object: nil, userInfo: [NotificationKey.contentSize : newSize])
                        }
                }
        }
}
