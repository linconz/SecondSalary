import SwiftUI

struct MenuBarPopoverContent: View {
    @ObservedObject var model: AppModel
    let now: Date
    @Binding var isShowingClearConfirmation: Bool
    let openSettingsAction: () -> Void
    let openAboutAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.standardSpacing) {
            StatusHeaderView(
                isWorking: model.isWorking,
                emotionalMessage: model.statusHeaderMessage(at: now),
                now: now
            )
            EarningsSummaryView(model: model, now: now)

            Button(
                model.isWorking ? "结束搬砖" : "开始搬砖",
                systemImage: model.isWorking ? "stop.fill" : "play.fill",
                action: toggleSession
            )
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            Divider()

            HStack {
                Button("设置", systemImage: "gear", action: openSettings)
                Button("关于", systemImage: "info.circle", action: openAbout)
                Button("清空今日", systemImage: "trash", action: askToClearToday)
                    .disabled(!model.hasTodayRecord)
                Spacer()
                Button("退出", systemImage: "power", action: model.quitApplication)
            }
            .labelStyle(.iconOnly)
        }
        .padding()
        .task(id: now) {
            handleTick()
        }
    }

    private func toggleSession() {
        if !model.isWorking && !model.hasValidSettings {
            openSettings()
            return
        }
        model.toggleSession(at: now)
    }

    private func openSettings() {
        openSettingsAction()
    }

    private func openAbout() {
        openAboutAction()
    }

    private func askToClearToday() {
        isShowingClearConfirmation = true
    }

    private func handleTick() {
        model.handleTick(at: now)
    }
}
