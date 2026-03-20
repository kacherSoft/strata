import SwiftUI
import KeyboardShortcuts

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case chat = "Chat"
    case aiProviders = "AI Providers"
    case aiModes = "AI Modes"
    case tasks = "Tasks"
    case shortcuts = "Shortcuts"
    case account = "Account"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .chat: return "bubble.left.and.bubble.right"
        case .aiProviders: return "cpu"
        case .aiModes: return "sparkles"
        case .tasks: return "checklist"
        case .shortcuts: return "keyboard"
        case .account: return "person.circle"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsSidebarRow(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
                Spacer()
            }
            .padding(12)
            .frame(width: 200)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            // Content
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .chat:
                    ChatSettingsView()
                case .aiProviders:
                    AIProvidersSettingsView()
                case .aiModes:
                    AIModesSettingsView()
                case .tasks:
                    TasksSettingsView()
                case .shortcuts:
                    ShortcutsSettingsView()
                case .account:
                    AccountSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 780, height: 560)
    }
}

struct SettingsSidebarRow: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                Text(tab.rawValue)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
    }
}
