import SwiftUI

struct EarningsSummaryView: View {
    @ObservedObject var model: AppModel
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.compactSpacing) {
            Text("今日累计")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(model.formattedTodayEarnings(at: now))
                .font(.title)
                .bold()
                .monospacedDigit()
                .contentTransition(.numericText())

            LabeledContent(
                "今日搬砖时长",
                value: DurationText.formatted(seconds: model.todayDuration(at: now))
            )
            .monospacedDigit()

            LabeledContent("当前秒薪", value: model.formattedCurrentRate())
                .monospacedDigit()
        }
        .padding(AppDesign.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: .rect(cornerRadius: AppDesign.cornerRadius))
        .accessibilityElement(children: .combine)
    }
}
