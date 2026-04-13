import SwiftUI

struct SettingsView: View {
    @AppStorage("refreshIntervalMinutes") private var refreshInterval = 30
    @AppStorage("markReadOnOpen") private var markReadOnOpen = true
    @AppStorage("retentionDays") private var retentionDays = 30

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

            Section("Article Retention") {
                Picker("Keep articles for", selection: $retentionDays) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("Forever").tag(0)
                }
                .pickerStyle(.radioGroup)
            }

            Section("iCloud Sync") {
                HStack {
                    if BroadsheetApp.iCloudSyncActive {
                        Image(systemName: "checkmark.icloud.fill")
                            .foregroundStyle(.green)
                        Text("Syncing with iCloud")
                    } else {
                        Image(systemName: "xmark.icloud.fill")
                            .foregroundStyle(.secondary)
                        Text("iCloud sync unavailable")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 440)
        .navigationTitle("General")
    }
}
