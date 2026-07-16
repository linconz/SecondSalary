import SwiftUI

struct StatusHeaderView: View {
    let isWorking: Bool
    let emotionalMessage: String?
    let now: Date

    var body: some View {
        HStack {
            Label(
                emotionalMessage ?? (isWorking ? "搬砖中" : "尚未开始搬砖"),
                systemImage: emotionalMessage == nil
                    ? (isWorking ? "play.circle.fill" : "pause.circle")
                    : "bubble.left.fill"
            )
            .foregroundStyle(
                emotionalMessage == nil
                    ? (isWorking ? .green : .secondary)
                    : .primary
            )
            .bold()
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if emotionalMessage == nil {
                Text(now, format: .dateTime.month().day().weekday())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
