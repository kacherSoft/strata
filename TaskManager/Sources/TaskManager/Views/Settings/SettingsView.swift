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

/// Settings using NavigationSplitView for native sidebar vibrancy (same as ChatView).
/// Toolbar hidden to avoid unwanted title bar clutter.
struct SettingsView: View {
    @State private var selectedTab: SettingsTab? = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 190, max: 220)
        } detail: {
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
                case nil:
                    Text("Select a section")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: 780, height: 560)
    }
}
