import SwiftUI
import SwiftData
import AppKit
import TaskManagerUIComponents
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
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
        _ = ShortcutManager.shared
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
                onEdit: { taskItem, title, notes, dueDate, hasReminder, priority, tags in
                    updateTask(taskItem: taskItem, title: title, notes: notes, dueDate: dueDate, hasReminder: hasReminder, priority: priority, tags: tags)
                },
                onDelete: { taskItem in
                    deleteTask(taskItem: taskItem)
                },
                onPriorityChange: { taskItem, priority in
                    updatePriority(taskItem: taskItem, priority: priority)
                }
            )
        }
        .navigationSplitViewStyle(.balanced)
        .background(WindowActivator())
        .sheet(isPresented: $showNewTaskSheet) {
            NewTaskSheet(isPresented: $showNewTaskSheet) { title, notes, dueDate, hasReminder, priority, tags in
                createTask(
                    title: title,
                    notes: notes,
                    dueDate: dueDate,
                    hasReminder: hasReminder,
                    priority: priority,
                    tags: tags
                )
            }
        }
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
        tags: [String]
    ) {
        let task = TaskModel(
            title: title,
            taskDescription: notes,
            dueDate: dueDate,
            priority: TaskPriority.from(priority),
            tags: tags,
            hasReminder: hasReminder
        )
        modelContext.insert(task)
        try? modelContext.save()
    }
    
    private func findTaskModel(for taskItem: TaskItem) -> TaskModel? {
        taskModels.first { $0.id == taskItem.id }
    }
    
    private func toggleComplete(taskItem: TaskItem) {
        guard let task = findTaskModel(for: taskItem) else { return }
        if task.isCompleted {
            task.markIncomplete()
        } else {
            task.markComplete()
        }
        try? modelContext.save()
    }
    
    private func updateTask(
        taskItem: TaskItem,
        title: String,
        notes: String,
        dueDate: Date?,
        hasReminder: Bool,
        priority: TaskItem.Priority,
        tags: [String]
    ) {
        guard let task = findTaskModel(for: taskItem) else { return }
        task.title = title
        task.taskDescription = notes
        task.dueDate = dueDate
        task.hasReminder = hasReminder
        task.priority = TaskPriority.from(priority)
        task.tags = tags
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
}
