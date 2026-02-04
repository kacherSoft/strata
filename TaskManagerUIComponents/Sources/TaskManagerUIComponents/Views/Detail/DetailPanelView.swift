import SwiftUI

// MARK: - Detail Panel View
public struct DetailPanelView: View {
    let selectedSidebarItem: SidebarItem?
    @Binding var selectedTask: TaskItem?
    let tasks: [TaskItem]
    @Binding var searchText: String
    @Binding var showNewTaskSheet: Bool
    
    let onToggleComplete: ((TaskItem) -> Void)?
    let onEdit: ((TaskItem, String, String, Date?, Bool, TaskItem.Priority, [String]) -> Void)?
    let onDelete: ((TaskItem) -> Void)?
    let onPriorityChange: ((TaskItem, TaskItem.Priority) -> Void)?

    public init(
        selectedSidebarItem: SidebarItem?,
        selectedTask: Binding<TaskItem?>,
        tasks: [TaskItem],
        searchText: Binding<String>,
        showNewTaskSheet: Binding<Bool>
    ) {
        self.selectedSidebarItem = selectedSidebarItem
        self._selectedTask = selectedTask
        self.tasks = tasks
        self._searchText = searchText
        self._showNewTaskSheet = showNewTaskSheet
        self.onToggleComplete = nil
        self.onEdit = nil
        self.onDelete = nil
        self.onPriorityChange = nil
    }
    
    public init(
        selectedSidebarItem: SidebarItem?,
        selectedTask: Binding<TaskItem?>,
        tasks: [TaskItem],
        searchText: Binding<String>,
        showNewTaskSheet: Binding<Bool>,
        onToggleComplete: @escaping (TaskItem) -> Void,
        onEdit: @escaping (TaskItem, String, String, Date?, Bool, TaskItem.Priority, [String]) -> Void,
        onDelete: @escaping (TaskItem) -> Void,
        onPriorityChange: @escaping (TaskItem, TaskItem.Priority) -> Void
    ) {
        self.selectedSidebarItem = selectedSidebarItem
        self._selectedTask = selectedTask
        self.tasks = tasks
        self._searchText = searchText
        self._showNewTaskSheet = showNewTaskSheet
        self.onToggleComplete = onToggleComplete
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onPriorityChange = onPriorityChange
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Header with Search
                HeaderView(
                    title: selectedSidebarItem?.title ?? "All Tasks",
                    searchText: $searchText
                )

                // Task List
                if let onToggleComplete, let onEdit, let onDelete, let onPriorityChange {
                    TaskListView(
                        tasks: filteredTasks,
                        selectedTask: $selectedTask,
                        onToggleComplete: onToggleComplete,
                        onEdit: onEdit,
                        onDelete: onDelete,
                        onPriorityChange: onPriorityChange
                    )
                } else {
                    TaskListView(
                        tasks: filteredTasks,
                        selectedTask: $selectedTask
                    )
                }
            }
            .frame(minWidth: 600, minHeight: 400)
            .overlay {
                if filteredTasks.isEmpty && !searchText.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No results found",
                        message: "Try a different search term"
                    )
                } else if filteredTasks.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "No tasks yet",
                        message: "Create your first task to get started"
                    )
                }
            }

            // Floating Action Button
            FloatingActionButton(icon: "plus") {
                showNewTaskSheet = true
            }
            .padding(24)
        }
    }

    private var filteredTasks: [TaskItem] {
        var result = tasks

        // Filter by sidebar selection
        if let selectedItem = selectedSidebarItem {
            switch selectedItem {
            case .allTasks: break
            case .today: result = result.filter { $0.isToday }
            case .upcoming: result = result.filter { !$0.isToday }
            case .completed: result = result.filter { $0.isCompleted }
            default: break
            }
        }

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.notes.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return result
    }
}
