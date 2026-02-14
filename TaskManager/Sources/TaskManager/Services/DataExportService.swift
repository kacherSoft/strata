import Foundation
import SwiftData
import AppKit

struct ExportableTask: Codable {
    let id: UUID
    let title: String
    let description: String
    let dueDate: Date?
    let priority: String
    let tags: [String]
    let status: String
    let completedAt: Date?
    let isToday: Bool
    let photos: [String]
    let createdAt: Date
    let updatedAt: Date
    let sortOrder: Int
}

struct ExportData: Codable {
    let version: Int
    let exportedAt: Date
    let tasks: [ExportableTask]
    
    init(exportedAt: Date, tasks: [ExportableTask]) {
        self.version = 1
        self.exportedAt = exportedAt
        self.tasks = tasks
    }
}

@MainActor
final class DataExportService {
    static let shared = DataExportService()
    
    private init() {}
    
    func exportTasks(context: ModelContext) {
        let descriptor = FetchDescriptor<TaskModel>()
        guard let tasks = try? context.fetch(descriptor) else { return }
        
        let exportableTasks = tasks.map { task in
            ExportableTask(
                id: task.id,
                title: task.title,
                description: task.taskDescription,
                dueDate: task.dueDate,
                priority: task.priority.rawValue,
                tags: task.tags,
                status: task.status.rawValue,
                completedAt: task.completedAt,
                isToday: task.isToday,
                photos: task.photos,
                createdAt: task.createdAt,
                updatedAt: task.updatedAt,
                sortOrder: task.sortOrder
            )
        }
        
        let exportData = ExportData(exportedAt: Date(), tasks: exportableTasks)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let jsonData = try? encoder.encode(exportData) else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "TaskFlowPro-Export-\(ISO8601DateFormatter().string(from: Date())).json"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? jsonData.write(to: url)
        }
    }
    
    func importTasks(context: ModelContext) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            guard let data = try? Data(contentsOf: url) else { return }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            guard let exportData = try? decoder.decode(ExportData.self, from: data) else { return }
            
            for exportTask in exportData.tasks {
                let task = TaskModel(
                    title: exportTask.title,
                    taskDescription: exportTask.description,
                    dueDate: exportTask.dueDate,
                    priority: TaskPriority(rawValue: exportTask.priority) ?? .medium,
                    tags: exportTask.tags,
                    status: TaskStatus(rawValue: exportTask.status) ?? .todo,
                    isToday: exportTask.isToday,
                    photos: exportTask.photos
                )
                task.completedAt = exportTask.completedAt
                task.createdAt = exportTask.createdAt
                task.updatedAt = exportTask.updatedAt
                task.sortOrder = exportTask.sortOrder
                context.insert(task)
            }
            
            try? context.save()
        }
    }
}
