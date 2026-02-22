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
                    Text("Global Shortcuts")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                    
                    Text("Work system-wide, even when the app is not focused")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 20)
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
                        name: .inlineEnhanceMe,
                        title: "Inline Enhance",
                        description: "Enhance text in any app's text field",
                        icon: "sparkles"
                    )
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
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
                        title: "Show Task List",
                        description: "Focus the main task list window",
                        icon: "macwindow"
                    )
                    
                    // Local Shortcuts
                    Text("Local Shortcuts")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 4)
                    
                    Text("Work only when the app is focused")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    
                    ShortcutRow(
                        name: .settings,
                        title: "Settings",
                        description: "Open settings window",
                        icon: "gearshape"
                    )
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    LocalShortcutRow(
                        title: "Cycle AI Mode",
                        description: "Switch between AI modes in Enhance Me panel",
                        icon: "arrow.triangle.2.circlepath",
                        shortcutLabel: "Tab"
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
                .liquidGlass(.settingsCard)
                
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

struct LocalShortcutRow: View {
    let title: String
    let description: String
    let icon: String
    let shortcutLabel: String
    
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
            
            Text(shortcutLabel)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

