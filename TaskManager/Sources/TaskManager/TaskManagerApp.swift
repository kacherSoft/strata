import SwiftUI
import TaskManagerUIComponents

// MARK: - Main App
@main
struct TaskManagerApp: App {
    var body: some Scene {
        WindowGroup("Task Manager", id: "main-window") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var selectedSidebarItem: SidebarItem? = .allTasks
    @State private var selectedTask: TaskItem?
    @State private var tasks = TaskItem.sampleTasks
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
                tasks: tasks,
                searchText: $searchText,
                showNewTaskSheet: $showNewTaskSheet
            )
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showNewTaskSheet) {
            NewTaskSheet(isPresented: $showNewTaskSheet)
        }
    }
}
