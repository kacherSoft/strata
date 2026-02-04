import SwiftData
import Foundation

@Model
final class AIModeModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var systemPrompt: String
    var sortOrder: Int
    var isBuiltIn: Bool
    var createdAt: Date
    
    init(name: String, systemPrompt: String, isBuiltIn: Bool = false) {
        self.id = UUID()
        self.name = name
        self.systemPrompt = systemPrompt
        self.sortOrder = 0
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
    }
    
    static func createDefaultModes() -> [AIModeModel] {
        [
            AIModeModel(
                name: "Correct Me",
                systemPrompt: "You are an expert editor. Correct grammar, spelling, and improve fluency while maintaining the original meaning and tone. Only output the corrected text, nothing else.",
                isBuiltIn: true
            ),
            AIModeModel(
                name: "Enhance Prompt",
                systemPrompt: "You are an expert at writing clear, detailed descriptions. Expand this text with more specific details, actionable steps, and context. Make it clearer and more comprehensive. Only output the enhanced text, nothing else.",
                isBuiltIn: true
            ),
            AIModeModel(
                name: "Simplify",
                systemPrompt: "You are an expert at concise communication. Rewrite this text to be shorter and clearer while keeping the essential meaning. Remove unnecessary words. Only output the simplified text, nothing else.",
                isBuiltIn: true
            ),
            AIModeModel(
                name: "Break Down",
                systemPrompt: "You are a project manager expert. Break this task into smaller, actionable subtasks. Format as a numbered list. Only output the subtask list, nothing else.",
                isBuiltIn: true
            )
        ]
    }
}
