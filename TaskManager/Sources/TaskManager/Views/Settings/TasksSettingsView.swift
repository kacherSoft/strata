import SwiftUI
import SwiftData

/// Task-related settings — default priority, show completed, custom fields, reminder sound.
struct TasksSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    private var settings: SettingsModel? {
        try? modelContext.fetch(FetchDescriptor<SettingsModel>()).first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Tasks")
                    .font(.title2.bold())
                    .padding(.bottom, 4)

                GroupBox("Defaults") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let s = settings {
                            HStack {
                                Text("Default Priority")
                                Spacer()
                                Text(s.defaultPriority.rawValue.capitalized)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                }

                GroupBox("Custom Fields") {
                    VStack(alignment: .leading, spacing: 8) {
                        CustomFieldsSettingsView()
                            .frame(minHeight: 200)
                    }
                }

                Spacer()
            }
            .padding(24)
        }
    }
}
