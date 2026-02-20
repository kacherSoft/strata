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
    @EnvironmentObject private var subscriptionService: SubscriptionService
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

                    Divider()

                    HStack {
                        Image(systemName: "person.badge.key")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        Text("Access Level")
                            .font(.body)

                        Spacer()

                        Text(subscriptionService.accessLabel)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    #if DEBUG
                    Divider()

                    HStack {
                        Image(systemName: "ladybug")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("VIP Admin Grant")
                                .font(.body)
                            Text("Debug-only local entitlement override")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { subscriptionService.isVIPAdminGrantActive },
                            set: { _ in subscriptionService.toggleVIPAdminGrant() }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .accessibilityLabel("VIP Admin Grant")
                    }
                    #endif
                }
                .padding(20)
                .liquidGlass(.settingsCard)

                // Data Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Data")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    Text("Reminders are not included in exports or imports.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                    
                    HStack(spacing: 12) {
                        Button {
                            do {
                                try DataExportService.shared.exportTasks(context: modelContext)
                            } catch {
                                dataErrorMessage = error.localizedDescription
                            }
                        } label: {
                            Label("Export Tasks", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            do {
                                try DataExportService.shared.importTasks(context: modelContext)
                            } catch {
                                dataErrorMessage = error.localizedDescription
                            }
                        } label: {
                            Label("Import Tasks", systemImage: "square.and.arrow.down")
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete All Tasks", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
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
    }
    
    @State private var showDeleteConfirmation = false
    @State private var dataErrorMessage: String?

    private func deleteAllTasks() {
        do {
            try modelContext.delete(model: TaskModel.self)
            try modelContext.save()
        } catch {
            dataErrorMessage = error.localizedDescription
        }
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
