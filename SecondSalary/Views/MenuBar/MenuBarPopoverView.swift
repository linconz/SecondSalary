import SwiftUI

struct MenuBarPopoverView: View {
    @ObservedObject var model: AppModel
    let openSettingsAction: () -> Void
    let openAboutAction: () -> Void
    @State private var isShowingClearConfirmation = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: model.refreshInterval.timeInterval)) { context in
            MenuBarPopoverContent(
                model: model,
                now: context.date,
                isShowingClearConfirmation: $isShowingClearConfirmation,
                openSettingsAction: openSettingsAction,
                openAboutAction: openAboutAction
            )
        }
        .frame(width: AppDesign.popoverWidth)
        .confirmationDialog(
            "清空今日记录？",
            isPresented: $isShowingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空今日记录", role: .destructive, action: model.clearToday)
            Button("取消", role: .cancel) {}
        } message: {
            Text("今天的累计搬砖时长和金额将被删除，此操作无法撤销。")
        }
        .alert("操作失败", isPresented: $model.isShowingError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(model.errorMessage)
        }
    }
}
