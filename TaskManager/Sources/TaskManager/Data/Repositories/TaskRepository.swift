import SwiftData
import Foundation

enum TaskFilter: Equatable, Sendable {
    case all
    case today
    case completed
    case incomplete
    case priority(TaskPriority)
    case tag(String)
    case dueSoon(days: Int)
}

enum TaskSortOrder: Sendable {
    case createdAt(ascending: Bool)
    case dueDate(ascending: Bool)
    case priority(ascending: Bool)
    case title(ascending: Bool)
    case manual
}

@MainActor
final class TaskRepository: ObservableObject {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchAll(
        filter: TaskFilter = .all,
        sortOrder: TaskSortOrder = .createdAt(ascending: false),
        searchText: String = ""
    ) throws -> [TaskModel] {
        var descriptor = FetchDescriptor<TaskModel>()
        
        descriptor.sortBy = sortDescriptors(for: sortOrder)
        
        var tasks = try modelContext.fetch(descriptor)
        
        tasks = applyFilter(tasks, filter: filter)
        
        if !searchText.isEmpty {
            tasks = applySearch(tasks, searchText: searchText)
        }
        
        return tasks
    }
    
    func fetch(id: UUID) throws -> TaskModel? {
        var descriptor = FetchDescriptor<TaskModel>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
    
    @discardableResult
    func create(
        title: String,
        taskDescription: String = "",
        dueDate: Date? = nil,
        priority: TaskPriority = .medium,
        tags: [String] = [],
        isToday: Bool = false
    ) -> TaskModel {
        let task = TaskModel(
            title: title,
            taskDescription: taskDescription,
            dueDate: dueDate,
            priority: priority,
            tags: tags,
            isToday: isToday
        )
        modelContext.insert(task)
        try? modelContext.save()
        return task
    }
    
    func update(_ task: TaskModel) {
        task.touch()
        try? modelContext.save()
    }
    
    func delete(_ task: TaskModel) {
        modelContext.delete(task)
        try? modelContext.save()
    }
    
    func deleteAll() throws {
        try modelContext.delete(model: TaskModel.self)
        try modelContext.save()
    }
    
    func toggleComplete(_ task: TaskModel) {
        if task.isCompleted {
            task.markIncomplete()
        } else {
            task.markComplete()
        }
        try? modelContext.save()
    }
    
    private func sortDescriptors(for order: TaskSortOrder) -> [SortDescriptor<TaskModel>] {
        switch order {
        case .createdAt(let ascending):
            return [SortDescriptor(\.createdAt, order: ascending ? .forward : .reverse)]
        case .dueDate(let ascending):
            return [SortDescriptor(\.dueDate, order: ascending ? .forward : .reverse)]
        case .priority:
            return [SortDescriptor(\.createdAt, order: .reverse)]
        case .title(let ascending):
            return [SortDescriptor(\.title, order: ascending ? .forward : .reverse)]
        case .manual:
            return [SortDescriptor(\.sortOrder, order: .forward)]
        }
    }
    
    private func applyFilter(_ tasks: [TaskModel], filter: TaskFilter) -> [TaskModel] {
        switch filter {
        case .all:
            return tasks
        case .today:
            return tasks.filter { $0.isToday }
        case .completed:
            return tasks.filter { $0.isCompleted }
        case .incomplete:
            return tasks.filter { !$0.isCompleted }
        case .priority(let priority):
            return tasks.filter { $0.priority == priority }
        case .tag(let tag):
            return tasks.filter { $0.tags.contains(tag) }
        case .dueSoon(let days):
            let futureDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
            return tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate <= futureDate && dueDate >= Date()
            }
        }
    }
    
    private func applySearch(_ tasks: [TaskModel], searchText: String) -> [TaskModel] {
        let lowercasedSearch = searchText.lowercased()
        return tasks.filter { task in
            task.title.lowercased().contains(lowercasedSearch) ||
            task.taskDescription.lowercased().contains(lowercasedSearch) ||
            task.tags.contains { $0.lowercased().contains(lowercasedSearch) }
        }
    }
}
