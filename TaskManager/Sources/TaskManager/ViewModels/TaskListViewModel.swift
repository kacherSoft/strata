import SwiftUI
import SwiftData
import Combine

@MainActor
final class TaskListViewModel: ObservableObject {
    @Published var tasks: [TaskModel] = []
    @Published var searchText: String = ""
    @Published var selectedFilter: TaskFilter = .all
    @Published var sortOrder: TaskSortOrder = .createdAt(ascending: false)
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    private var repository: TaskRepository?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSearchDebounce()
    }
    
    func configure(modelContext: ModelContext) {
        self.repository = TaskRepository(modelContext: modelContext)
        refresh()
    }
    
    func refresh() {
        guard let repository else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            tasks = try repository.fetchAll(
                filter: selectedFilter,
                sortOrder: sortOrder,
                searchText: searchText
            )
            error = nil
        } catch {
            self.error = error
            tasks = []
        }
    }
    
    func createTask(
        title: String,
        description: String = "",
        dueDate: Date? = nil,
        priority: TaskPriority = .medium,
        tags: [String] = [],
        isToday: Bool = false
    ) {
        guard let repository, !title.isEmpty else { return }
        
        repository.create(
            title: title,
            taskDescription: description,
            dueDate: dueDate,
            priority: priority,
            tags: tags,
            isToday: isToday
        )
        refresh()
    }
    
    func updateTask(_ task: TaskModel) {
        guard let repository else { return }
        repository.update(task)
        refresh()
    }
    
    func deleteTask(_ task: TaskModel) {
        guard let repository else { return }
        repository.delete(task)
        refresh()
    }
    
    func toggleComplete(_ task: TaskModel) {
        guard let repository else { return }
        repository.toggleComplete(task)
        refresh()
    }
    
    func setFilter(_ filter: TaskFilter) {
        selectedFilter = filter
        refresh()
    }
    
    func setSortOrder(_ order: TaskSortOrder) {
        sortOrder = order
        refresh()
    }
    
    private func setupSearchDebounce() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }
    
    var incompleteTasks: [TaskModel] {
        tasks.filter { !$0.isCompleted }
    }
    
    var completedTasks: [TaskModel] {
        tasks.filter { $0.isCompleted }
    }
    
    var todayTasks: [TaskModel] {
        tasks.filter { $0.isToday && !$0.isCompleted }
    }
    
    var allTags: [String] {
        Array(Set(tasks.flatMap { $0.tags })).sorted()
    }
}
