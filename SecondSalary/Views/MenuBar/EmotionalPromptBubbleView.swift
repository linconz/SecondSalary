import SwiftUI

struct EmotionalPromptBubbleView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "bubble.left.fill")
            .font(.body)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppDesign.cardPadding)
            .accessibilityLabel(message)
    }
}
