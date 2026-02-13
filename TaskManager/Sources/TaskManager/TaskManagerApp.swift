import SwiftUI
import SwiftData
import AppKit
import TaskManagerUIComponents
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    var modelContainer: ModelContainer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Apply saved settings on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.applySettingsOnLaunch()
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        if let window = NSApp.windows.first(where: { $0.canBecomeKey && !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @MainActor
    private func applySettingsOnLaunch() {
        guard let container = modelContainer else { return }
        let context = container.mainContext
        
        do {
            let descriptor = FetchDescriptor<SettingsModel>()
            if let settings = try context.fetch(descriptor).first {
                WindowManager.shared.setAlwaysOnTop(settings.alwaysOnTop)
            }
        } catch {
            print("Failed to load settings: \(error)")
        }
    }
}

@main
struct TaskManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let container: ModelContainer
    private let menuBarController: MenuBarController
    
    init() {
        do {
            container = try ModelContainer.configured()
            WindowManager.shared.configure(modelContainer: container)
            seedDefaultData(container: container)
        } catch {
            fatalError("Failed to configure SwiftData: \(error)")
        }
        
        // Initialize menu bar
        menuBarController = MenuBarController()
        
        // Initialize shortcut manager (registers shortcuts)
        ShortcutManager.shared.configure(modelContainer: container)
        
        // Pass container to app delegate for settings (after all inits)
        appDelegate.modelContainer = container
    }
    
    var body: some Scene {
        WindowGroup("Task Manager", id: "main-window") {
            ContentView()
        }
        .modelContainer(container)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskModel.createdAt, order: .reverse) private var taskModels: [TaskModel]
    
    @State private var selectedSidebarItem: SidebarItem? = .allTasks
    @State private var selectedTask: TaskItem?
    @State private var showNewTaskSheet = false
    @State private var searchText = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedItem: $selectedSidebarItem)
                .frame(minWidth: 180, idealWidth: 220)
        } detail: {
            DetailPanelView(
                selectedSidebarItem: selectedSidebarItem,
                selectedTask: $selectedTask,
                tasks: taskItems,
                searchText: $searchText,
                showNewTaskSheet: $showNewTaskSheet,
                onToggleComplete: { taskItem in
                    toggleComplete(taskItem: taskItem)
                },
                onEdit: { taskItem, title, notes, dueDate, hasReminder, priority, tags, photos in
                    updateTask(taskItem: taskItem, title: title, notes: notes, dueDate: dueDate, hasReminder: hasReminder, priority: priority, tags: tags, photos: photos)
                },
                onDelete: { taskItem in
                    deleteTask(taskItem: taskItem)
                },
                onPriorityChange: { taskItem, priority in
                    updatePriority(taskItem: taskItem, priority: priority)
                },
                onAddPhotos: { taskItem, urls in
                    addPhotos(taskItem: taskItem, urls: urls)
                },
                onPickPhotos: { completion in
                    PhotoStorageService.shared.pickPhotos(completion: completion)
                },
                onDeletePhoto: { url in
                    PhotoStorageService.shared.deletePhoto(at: url.path)
                }
            )
        }
        .navigationSplitViewStyle(.balanced)
        .background(WindowActivator())
        .sheet(isPresented: $showNewTaskSheet) {
            NewTaskSheet(
                isPresented: $showNewTaskSheet,
                onPickPhotos: { completion in
                    PhotoStorageService.shared.pickPhotos(completion: completion)
                }
            ) { title, notes, dueDate, hasReminder, priority, tags, photos in
                createTask(
                    title: title,
                    notes: notes,
                    dueDate: dueDate,
                    hasReminder: hasReminder,
                    priority: priority,
                    tags: tags,
                    photos: photos
                )
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .background(LocalShortcutHandler())
    }
    
    private var taskItems: [TaskItem] {
        taskModels.map { $0.toTaskItem() }
    }
    
    private func createTask(
        title: String,
        notes: String,
        dueDate: Date?,
        hasReminder: Bool,
        priority: TaskItem.Priority,
        tags: [String],
        photos: [URL] = []
    ) {
        let storedPaths = photos.isEmpty ? [] : PhotoStorageService.shared.storePhotos(photos)
        let task = TaskModel(
            title: title,
            taskDescription: notes,
            dueDate: dueDate,
            priority: TaskPriority.from(priority),
            tags: tags,
            hasReminder: hasReminder,
            photos: storedPaths
        )
        modelContext.insert(task)
        try? modelContext.save()
    }
    
    private func findTaskModel(for taskItem: TaskItem) -> TaskModel? {
        taskModels.first { $0.id == taskItem.id }
    }
    
    private func toggleComplete(taskItem: TaskItem) {
        guard let task = findTaskModel(for: taskItem) else { return }
        task.cycleStatus()
        try? modelContext.save()
    }
    
    private func updateStatus(taskItem: TaskItem, status: TaskItem.Status) {
        guard let task = findTaskModel(for: taskItem) else { return }
        task.setStatus(TaskStatus.from(status))
        try? modelContext.save()
    }
    
    private func updateTask(
        taskItem: TaskItem,
        title: String,
        notes: String,
        dueDate: Date?,
        hasReminder: Bool,
        priority: TaskItem.Priority,
        tags: [String],
        photos: [URL] = []
    ) {
        guard let task = findTaskModel(for: taskItem) else { return }
        task.title = title
        task.taskDescription = notes
        task.dueDate = dueDate
        task.hasReminder = hasReminder
        task.priority = TaskPriority.from(priority)
        task.tags = tags
        task.photos = PhotoStorageService.shared.normalizeToStoredPaths(photos)
        task.touch()
        try? modelContext.save()
    }
    
    private func deleteTask(taskItem: TaskItem) {
        guard let task = findTaskModel(for: taskItem) else { return }
        modelContext.delete(task)
        try? modelContext.save()
        selectedTask = nil
    }
    
    private func updatePriority(taskItem: TaskItem, priority: TaskItem.Priority) {
        guard let task = findTaskModel(for: taskItem) else { return }
        task.priority = TaskPriority.from(priority)
        task.touch()
        try? modelContext.save()
    }
    
    private func addPhotos(taskItem: TaskItem, urls: [URL]) {
        guard let task = findTaskModel(for: taskItem) else { return }
        
        if urls.isEmpty {
            PhotoStorageService.shared.pickPhotos { pickedURLs in
                guard !pickedURLs.isEmpty else { return }
                let storedPaths = PhotoStorageService.shared.storePhotos(pickedURLs)
                task.photos.append(contentsOf: storedPaths)
                task.touch()
                try? self.modelContext.save()
            }
        } else {
            let storedPaths = PhotoStorageService.shared.storePhotos(urls)
            task.photos.append(contentsOf: storedPaths)
            task.touch()
            try? modelContext.save()
        }
    }
}

struct LocalShortcutHandler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { LocalShortcutNSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class LocalShortcutNSView: KeyEventMonitorNSView {
    override func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        if event.matchesShortcut(.mainWindow) {
            ShortcutManager.shared.showMainWindow()
            return nil
        }
        if event.matchesShortcut(.settings) {
            ShortcutManager.shared.showSettings()
            return nil
        }
        return event
    }
}
