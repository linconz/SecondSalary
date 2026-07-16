import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let closeAction: (() -> Void)?
    @State private var monthlySalary: Double
    @State private var monthlyWorkdays: Int
    @State private var workStartTime: Date
    @State private var workEndTime: Date
    @State private var currency: CurrencyOption
    @State private var refreshInterval: RefreshInterval
    @State private var launchAtLogin: Bool
    @State private var didSave = false
    @State private var isShowingResetConfirmation = false

    init(model: AppModel, closeAction: (() -> Void)? = nil) {
        self.model = model
        self.closeAction = closeAction
        let settings = model.settings
        _monthlySalary = State(
            initialValue: settings.map { NSDecimalNumber(decimal: $0.monthlySalary).doubleValue } ?? 0
        )
        _monthlyWorkdays = State(initialValue: settings?.monthlyWorkdays ?? 21)
        _workStartTime = State(
            initialValue: Self.date(
                forMinuteOfDay: settings?.workStartMinute
                    ?? CompensationSettings.defaultWorkStartMinute
            )
        )
        _workEndTime = State(
            initialValue: Self.date(
                forMinuteOfDay: settings?.workEndMinute
                    ?? CompensationSettings.defaultWorkEndMinute
            )
        )
        _currency = State(initialValue: settings?.currency ?? .cny)
        _refreshInterval = State(initialValue: model.refreshInterval)
        _launchAtLogin = State(initialValue: model.launchAtLogin)
    }

    var body: some View {
        VStack(spacing: AppDesign.standardSpacing) {
            Form {
                Section("工资计算") {
                    TextField(
                        "月薪",
                        value: $monthlySalary,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    TextField("当月工作日", value: $monthlyWorkdays, format: .number)
                    LabeledContent("上班时间") {
                        SystemTimeField(
                            selection: $workStartTime,
                            accessibilityLabel: "上班时间"
                        )
                        .fixedSize()
                    }
                    LabeledContent("下班时间") {
                        SystemTimeField(
                            selection: $workEndTime,
                            accessibilityLabel: "下班时间"
                        )
                        .fixedSize()
                    }
                    LabeledContent("每日搬砖时长", value: scheduledWorkDuration)
                        .monospacedDigit()

                    Picker("币种", selection: $currency) {
                        ForEach(CurrencyOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .disabled(model.hasTodayRecord)

                    if model.hasTodayRecord {
                        Label(
                            "当天已有记录，币种将在清空今日记录或次日后才能修改。",
                            systemImage: "lock"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("计数器") {
                    Picker("刷新频率", selection: $refreshInterval) {
                        ForEach(RefreshInterval.allCases) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                    Toggle("登录时启动", isOn: $launchAtLogin)
                }

                Section("隐私") {
                    Label(
                        "月薪和今日搬砖记录仅保存在本机钥匙串，不联网、不上传。",
                        systemImage: "lock.shield"
                    )
                    .foregroundStyle(.secondary)

                    Button(
                        "删除全部本机数据",
                        systemImage: "trash",
                        role: .destructive,
                        action: askToReset
                    )
                }
            }
            .formStyle(.grouped)

            HStack {
                if didSave {
                    Label("已保存", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                Spacer()
                Button("取消", action: close)
                Button("保存", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: AppDesign.settingsWidth)
        .alert("操作失败", isPresented: $model.isShowingError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(model.errorMessage)
        }
        .confirmationDialog(
            "删除全部本机数据？",
            isPresented: $isShowingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除全部数据", role: .destructive, action: resetAllData)
            Button("取消", role: .cancel) {}
        } message: {
            Text("工资设置、今日搬砖记录和偏好将被删除，登录时启动也会关闭。")
        }
    }

    private var canSave: Bool {
        monthlySalary > 0
            && (1...31).contains(monthlyWorkdays)
            && Self.minuteOfDay(for: workStartTime) != Self.minuteOfDay(for: workEndTime)
    }

    private var scheduledWorkDuration: String {
        let minutes = CompensationSettings.workDurationMinutes(
            from: Self.minuteOfDay(for: workStartTime),
            to: Self.minuteOfDay(for: workEndTime)
        )
        return DurationText.formatted(seconds: TimeInterval(minutes * 60))
    }

    private func save() {
        let settings = CompensationSettings(
            monthlySalary: Decimal(monthlySalary),
            monthlyWorkdays: monthlyWorkdays,
            workStartMinute: Self.minuteOfDay(for: workStartTime),
            workEndMinute: Self.minuteOfDay(for: workEndTime),
            currency: currency
        )
        didSave = model.saveSettings(
            settings,
            refreshInterval: refreshInterval,
            launchAtLogin: launchAtLogin
        )
    }

    private func close() {
        if let closeAction {
            closeAction()
        } else {
            dismiss()
        }
    }

    private func askToReset() {
        isShowingResetConfirmation = true
    }

    private func resetAllData() {
        model.resetAllData()
        monthlySalary = 0
        monthlyWorkdays = 21
        workStartTime = Self.date(
            forMinuteOfDay: CompensationSettings.defaultWorkStartMinute
        )
        workEndTime = Self.date(
            forMinuteOfDay: CompensationSettings.defaultWorkEndMinute
        )
        currency = .cny
        refreshInterval = .oneSecond
        launchAtLogin = false
        didSave = false
    }

    private static func date(forMinuteOfDay minute: Int) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        return calendar.date(
            bySettingHour: minute / 60,
            minute: minute % 60,
            second: 0,
            of: .now
        ) ?? .now
    }

    private static func minuteOfDay(for date: Date) -> Int {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
