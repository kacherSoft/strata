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
        self.version = 2
        self.exportedAt = exportedAt
        self.tasks = tasks
    }
}

@MainActor
final class DataExportService {
    static let shared = DataExportService()

    private init() {}

    func exportTasks(context: ModelContext) throws {
        let descriptor = FetchDescriptor<TaskModel>()
        let tasks = try context.fetch(descriptor)

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
                photos: task.photos.map { URL(fileURLWithPath: $0).lastPathComponent },
                createdAt: task.createdAt,
                updatedAt: task.updatedAt,
                sortOrder: task.sortOrder
            )
        }

        let exportData = ExportData(exportedAt: Date(), tasks: exportableTasks)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(exportData)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "TaskFlowPro-Export-\(ISO8601DateFormatter().string(from: Date())).json"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try jsonData.write(to: url)
    }

    func importTasks(context: ModelContext) throws {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(ExportData.self, from: data)

        for exportTask in exportData.tasks {
            let resolvedPhotos = resolveImportedPhotos(exportTask.photos)

            if let existingTask = try fetchTask(id: exportTask.id, context: context) {
                existingTask.title = exportTask.title
                existingTask.taskDescription = exportTask.description
                existingTask.dueDate = exportTask.dueDate
                existingTask.priority = TaskPriority(rawValue: exportTask.priority) ?? .medium
                existingTask.tags = exportTask.tags
                existingTask.status = TaskStatus(rawValue: exportTask.status) ?? .todo
                existingTask.isToday = exportTask.isToday
                existingTask.photos = resolvedPhotos
                existingTask.completedAt = exportTask.completedAt
                existingTask.createdAt = exportTask.createdAt
                existingTask.updatedAt = exportTask.updatedAt
                existingTask.sortOrder = exportTask.sortOrder
                continue
            }

            let newTask = TaskModel(
                id: exportTask.id,
                title: exportTask.title,
                taskDescription: exportTask.description,
                dueDate: exportTask.dueDate,
                priority: TaskPriority(rawValue: exportTask.priority) ?? .medium,
                tags: exportTask.tags,
                status: TaskStatus(rawValue: exportTask.status) ?? .todo,
                isToday: exportTask.isToday,
                photos: resolvedPhotos
            )
            newTask.completedAt = exportTask.completedAt
            newTask.createdAt = exportTask.createdAt
            newTask.updatedAt = exportTask.updatedAt
            newTask.sortOrder = exportTask.sortOrder
            context.insert(newTask)
        }

        try context.save()
    }

    private func fetchTask(id: UUID, context: ModelContext) throws -> TaskModel? {
        let descriptor = FetchDescriptor<TaskModel>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    private func resolveImportedPhotos(_ imported: [String]) -> [String] {
        imported.compactMap { value in
            let fileName = URL(fileURLWithPath: value).lastPathComponent

            if PhotoStorageService.shared.photoExists(at: value) {
                return value
            }

            return PhotoStorageService.shared.storedPhotoPath(forFileName: fileName)
        }
    }
}
