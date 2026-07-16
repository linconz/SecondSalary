import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: AppDesign.standardSpacing) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityLabel("SecondSalary 应用图标")

            Text("SecondSalary")
                .font(.title)
                .bold()

            Text("版本 1.0.0")
                .foregroundStyle(.secondary)

            Text("Copyright © 2026 zhangyilin")

            Text("本程序是自由软件，按 GNU GPL v3.0 only 发布，不提供任何明示或暗示的担保。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let licenseURL = URL(string: "https://www.gnu.org/licenses/gpl-3.0.html") {
                Link("查看 GNU GPL v3.0", destination: licenseURL)
            }
        }
        .padding()
        .frame(width: 340)
    }
}
