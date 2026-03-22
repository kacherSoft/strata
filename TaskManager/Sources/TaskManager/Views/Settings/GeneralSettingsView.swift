import SwiftUI
import SwiftData

// MARK: - Appearance Mode
enum AppearanceMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    
    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}

struct GeneralSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(EntitlementService.self) var entitlementService
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared
    @Query private var settings: [SettingsModel]
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    private var currentSettings: SettingsModel? { settings.first }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("General")
                    .font(.title)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 20) {
                    // Appearance Mode
                    HStack {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Appearance")
                                .font(.body)
                            Text("Choose light or dark mode")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Picker("", selection: $appearanceMode) {
                            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                Label(mode.displayName, systemImage: mode.icon)
                                    .tag(mode)
                            }
                        }
                        .frame(width: 140)
                        .onChange(of: appearanceMode) { _, newValue in
                            applyAppearanceMode(newValue)
                        }
                    }
                    
                    Divider()
                    
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
                    
                    Divider()
                    
                    // Reminder Sound
                    HStack {
                        Image(systemName: "bell.badge")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reminder Sound")
                                .font(.body)
                            Text("Sound played when a reminder fires")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Picker("", selection: Binding(
                            get: { currentSettings?.reminderSoundId ?? "default" },
                            set: { newValue in
                                currentSettings?.reminderSoundId = newValue
                                currentSettings?.touch()
                            }
                        )) {
                            ForEach(NotificationService.availableSounds, id: \.id) { sound in
                                Text(sound.name).tag(sound.id)
                            }
                        }
                        .frame(width: 120)

                        Button {
                            NotificationService.previewSound(
                                for: currentSettings?.reminderSoundId ?? "default"
                            )
                        } label: {
                            Image(systemName: "speaker.wave.2")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                                .liquidGlass(.circleButton)
                        }
                        .buttonStyle(.plain)
                        .help("Preview sound")
                    }

                    // Account/license moved to Account settings section
                }
                .padding(20)
                .liquidGlass(.settingsCard)

                // System-Wide Enhancement
                VStack(alignment: .leading, spacing: 0) {
                    Text("System-Wide Enhancement")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                    
                    HStack {
                        Image(systemName: accessibilityManager.isAccessibilityEnabled
                              ? "checkmark.shield.fill" : "exclamationmark.shield")
                            .foregroundStyle(accessibilityManager.isAccessibilityEnabled ? .green : .orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(accessibilityManager.isAccessibilityEnabled
                                 ? "Accessibility Enabled" : "Accessibility Required")
                                .font(.body)
                            Text("Required to enhance text in other applications")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if !accessibilityManager.isAccessibilityEnabled {
                            Button("Grant Access") {
                                accessibilityManager.requestPermission()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    #if false
                    SettingsToggleRow(
                        title: "Debug Logging",
                        description: "Show detailed logs for text capture and replacement",
                        icon: "ladybug",
                        isOn: Binding(
                            get: { InlineEnhanceCoordinator.shared.enableDebugMode },
                            set: { InlineEnhanceCoordinator.shared.enableDebugMode = $0 }
                        )
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    #endif
                }
                .liquidGlass(.settingsCard)

                // Data section moved to Tasks settings
                .liquidGlass(.settingsCard)

                Spacer()
            }
            .padding(24)
        }
        .confirmationDialog("Delete All Tasks?", isPresented: $showDeleteConfirmation) {
            Button("Delete All", role: .destructive) {
                deleteAllTasks()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Deactivate License?", isPresented: $showDeactivateConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Deactivate", role: .destructive) {
                Task {
                    do {
                        try await entitlementService.deactivateLicense()
                    } catch {
                        deactivationError = error.localizedDescription
                    }
                }
            }
        } message: {
            Text("This will deactivate your license on this device. You can reactivate later if activation slots are available.")
        }
        .alert("Deactivation Failed", isPresented: Binding(
            get: { deactivationError != nil },
            set: { if !$0 { deactivationError = nil } }
        )) {
            Button("OK", role: .cancel) { deactivationError = nil }
        } message: {
            Text(deactivationError ?? "")
        }
        .alert("Data Operation Failed", isPresented: Binding(
            get: { dataErrorMessage != nil },
            set: { if !$0 { dataErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                dataErrorMessage = nil
            }
        } message: {
            Text(dataErrorMessage ?? "")
        }
        .alert("Subscription Portal Unavailable", isPresented: Binding(
            get: { subscriptionManagementError != nil },
            set: { if !$0 { subscriptionManagementError = nil } }
        )) {
            Button("OK", role: .cancel) {
                subscriptionManagementError = nil
            }
        } message: {
            Text(subscriptionManagementError ?? "")
        }
        .sheet(isPresented: $showAccountSignInSheet) {
            AccountSignInView()
        }
    }
    
    @State private var showDeleteConfirmation = false
    @State private var showDeactivateConfirmation = false
    @State private var showAccountSignInSheet = false
    @State private var deactivationError: String?
    @State private var dataErrorMessage: String?
    @State private var subscriptionManagementError: String?

    private func deleteAllTasks() {
        do {
            try modelContext.delete(model: TaskModel.self)
            try modelContext.save()
        } catch {
            dataErrorMessage = error.localizedDescription
        }
    }
    
    private func maskedKey(_ key: String) -> String {
        guard key.count > 4 else { return key }
        let suffix = String(key.suffix(4))
        return "XXXX-XXXX-...-\(suffix)"
    }

    private func formattedValidationDate(_ isoString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: isoString) else { return isoString }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func applyAppearanceMode(_ mode: AppearanceMode) {
        switch mode {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
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
                .controlSize(.small)
                .accessibilityLabel(title)
        }
    }
}
