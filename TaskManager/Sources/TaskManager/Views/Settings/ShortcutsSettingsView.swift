import SwiftUI
import KeyboardShortcuts

struct ShortcutsSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Shortcuts")
                    .font(.title)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 0) {
                    // Task Shortcuts
                    Text("Task Shortcuts")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    
                    ShortcutRow(
                        name: .quickEntry,
                        title: "Quick Entry",
                        description: "Open quick task entry panel",
                        icon: "plus.circle"
                    )
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    ShortcutRow(
                        name: .mainWindow,
                        title: "Show Main Window",
                        description: "Focus the main task list",
                        icon: "macwindow"
                    )
                    
                    // AI Shortcuts
                    Text("AI Shortcuts")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                    
                    ShortcutRow(
                        name: .enhanceMe,
                        title: "Enhance Me",
                        description: "Open AI enhancement panel",
                        icon: "sparkles"
                    )
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    ShortcutRow(
                        name: .cycleAIMode,
                        title: "Cycle AI Mode",
                        description: "Switch between AI modes",
                        icon: "arrow.triangle.2.circlepath"
                    )
                    
                    // App Shortcuts
                    Text("App Shortcuts")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                    
                    ShortcutRow(
                        name: .settings,
                        title: "Settings",
                        description: "Open settings window",
                        icon: "gearshape"
                    )
                    
                    // Reset button
                    HStack {
                        Spacer()
                        Button("Reset All to Defaults") {
                            ShortcutManager.resetAllToDefaults()
                        }
                        .foregroundStyle(.red)
                        .padding(.vertical, 16)
                        Spacer()
                    }
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                Spacer()
            }
            .padding(24)
        }
    }
}

struct ShortcutRow: View {
    let name: KeyboardShortcuts.Name
    let title: String
    let description: String
    let icon: String
    
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
            
            KeyboardShortcuts.Recorder(for: name)
                .frame(width: 150)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
