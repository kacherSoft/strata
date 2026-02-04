import SwiftUI
import SwiftData

@MainActor
final class TaskDetailViewModel: ObservableObject {
    @Published var task: TaskModel?
    @Published var isEditing: Bool = false
    @Published var editedTitle: String = ""
    @Published var editedDescription: String = ""
    @Published var editedDueDate: Date?
    @Published var editedPriority: TaskPriority = .medium
    @Published var editedTags: [String] = []
    @Published var editedIsToday: Bool = false
    
    private var repository: TaskRepository?
    
    func configure(modelContext: ModelContext) {
        self.repository = TaskRepository(modelContext: modelContext)
    }
    
    func setTask(_ task: TaskModel?) {
        self.task = task
        if let task {
            loadFromTask(task)
        }
    }
    
    func startEditing() {
        guard let task else { return }
        loadFromTask(task)
        isEditing = true
    }
    
    func cancelEditing() {
        isEditing = false
        if let task {
            loadFromTask(task)
        }
    }
    
    func saveChanges() {
        guard let task, let repository else { return }
        
        task.title = editedTitle
        task.taskDescription = editedDescription
        task.dueDate = editedDueDate
        task.priority = editedPriority
        task.tags = editedTags
        task.isToday = editedIsToday
        
        repository.update(task)
        isEditing = false
    }
    
    func toggleComplete() {
        guard let task, let repository else { return }
        repository.toggleComplete(task)
    }
    
    func delete() {
        guard let task, let repository else { return }
        repository.delete(task)
        self.task = nil
    }
    
    func addTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !editedTags.contains(trimmed) else { return }
        editedTags.append(trimmed)
    }
    
    func removeTag(_ tag: String) {
        editedTags.removeAll { $0 == tag }
    }
    
    private func loadFromTask(_ task: TaskModel) {
        editedTitle = task.title
        editedDescription = task.taskDescription
        editedDueDate = task.dueDate
        editedPriority = task.priority
        editedTags = task.tags
        editedIsToday = task.isToday
    }
    
    var hasUnsavedChanges: Bool {
        guard let task else { return false }
        return editedTitle != task.title ||
               editedDescription != task.taskDescription ||
               editedDueDate != task.dueDate ||
               editedPriority != task.priority ||
               editedTags != task.tags ||
               editedIsToday != task.isToday
    }
}
