import SwiftUI
import SwiftData

struct GeneralSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [SettingsModel]
    
    private var currentSettings: SettingsModel? { settings.first }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("General")
                    .font(.title)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 20) {
                    // Always on Top
                    SettingsToggleRow(
                        title: "Always on Top",
                        description: "Keep window above other applications",
                        icon: "pin.fill",
                        isOn: Binding(
                            get: { currentSettings?.alwaysOnTop ?? false },
                            set: { newValue in
                                currentSettings?.alwaysOnTop = newValue
                                currentSettings?.touch()
                                WindowManager.shared.setAlwaysOnTop(newValue)
                            }
                        )
                    )
                    
                    Divider()
                    
                    // Show Completed Tasks
                    SettingsToggleRow(
                        title: "Show Completed Tasks",
                        description: "Display completed tasks in the list",
                        icon: "checkmark.circle",
                        isOn: Binding(
                            get: { currentSettings?.showCompletedTasks ?? true },
                            set: { newValue in
                                currentSettings?.showCompletedTasks = newValue
                                currentSettings?.touch()
                            }
                        )
                    )
                    
                    Divider()
                    
                    // Reduced Motion
                    SettingsToggleRow(
                        title: "Reduced Motion",
                        description: "Minimize animations throughout the app",
                        icon: "figure.walk",
                        isOn: Binding(
                            get: { currentSettings?.reducedMotion ?? false },
                            set: { newValue in
                                currentSettings?.reducedMotion = newValue
                                currentSettings?.touch()
                            }
                        )
                    )
                    
                    Divider()
                    
                    // Default Priority
                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Priority")
                                .font(.body)
                            Text("Priority for new tasks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Picker("", selection: Binding(
                            get: { currentSettings?.defaultPriority ?? .medium },
                            set: { newValue in
                                currentSettings?.defaultPriority = newValue
                                currentSettings?.touch()
                            }
                        )) {
                            ForEach(TaskPriority.allCases, id: \.self) { priority in
                                Text(priority.rawValue.capitalized).tag(priority)
                            }
                        }
                        .frame(width: 120)
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                Spacer()
            }
            .padding(24)
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
        }
    }
}
