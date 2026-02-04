import SwiftData
import Foundation

@Model
final class SettingsModel {
    @Attribute(.unique) var id: UUID
    var aiProvider: AIProvider
    var selectedAIModeId: UUID?
    var alwaysOnTop: Bool
    var reducedMotion: Bool
    var showCompletedTasks: Bool
    var defaultPriority: TaskPriority
    var createdAt: Date
    var updatedAt: Date
    
    init() {
        self.id = UUID()
        self.aiProvider = .gemini
        self.alwaysOnTop = false
        self.reducedMotion = false
        self.showCompletedTasks = true
        self.defaultPriority = .medium
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    func touch() {
        updatedAt = Date()
    }
}

enum AIProvider: String, Codable, CaseIterable, Sendable {
    case gemini = "gemini"
    case zai = "zai"
    
    var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .zai: return "z.ai (GLM 4.6)"
        }
    }
}
