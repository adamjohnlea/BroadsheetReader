import SwiftUI

struct SettingsView: View {
    @AppStorage("refreshIntervalMinutes") private var refreshInterval = 30
    @AppStorage("markReadOnOpen") private var markReadOnOpen = true

    var body: some View {
        Form {
            Section("Reading") {
                Toggle("Mark articles as read when opened", isOn: $markReadOnOpen)
            }

            Section("Auto-Refresh") {
                Picker("Refresh interval", selection: $refreshInterval) {
                    Text("Manual only").tag(0)
                    Text("Every 15 minutes").tag(15)
                    Text("Every 30 minutes").tag(30)
                    Text("Every hour").tag(60)
                }
                .pickerStyle(.radioGroup)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 240)
        .navigationTitle("General")
    }
}
