import SwiftData
import Foundation

/// CRUD operations for AIProviderModel with validation and limit enforcement.
struct AIProviderRepository {
    let modelContext: ModelContext

    func fetchAll() throws -> [AIProviderModel] {
        let descriptor = FetchDescriptor<AIProviderModel>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchEnabled() throws -> [AIProviderModel] {
        let descriptor = FetchDescriptor<AIProviderModel>(
            predicate: #Predicate { $0.isEnabled },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchById(_ id: UUID) throws -> AIProviderModel? {
        let descriptor = FetchDescriptor<AIProviderModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    func create(
        name: String,
        providerType: AIProviderType,
        baseURL: String? = nil,
        apiKeyRef: String,
        models: [String],
        defaultModelName: String? = nil,
        isDefault: Bool = false
    ) throws -> AIProviderModel {
        let all = try fetchAll()
        guard all.count < AIProviderModel.maxProviderCount else {
            throw AIProviderError.maxProvidersReached
        }

        let provider = AIProviderModel(
            name: name,
            providerType: providerType,
            baseURL: baseURL,
            apiKeyRef: apiKeyRef,
            models: models,
            defaultModelName: defaultModelName,
            isDefault: isDefault,
            sortOrder: all.count
        )
        modelContext.insert(provider)
        try modelContext.save()
        return provider
    }

    func delete(_ provider: AIProviderModel) throws {
        guard !provider.isDefault else {
            throw AIProviderError.cannotDeleteDefault
        }
        // Clean up Keychain key for custom providers
        KeychainService.shared.deleteValue(forRef: provider.apiKeyRef)
        modelContext.delete(provider)
        try modelContext.save()
    }
}

enum AIProviderError: LocalizedError {
    case maxProvidersReached
    case cannotDeleteDefault

    var errorDescription: String? {
        switch self {
        case .maxProvidersReached:
            return "Maximum of \(AIProviderModel.maxProviderCount) providers allowed"
        case .cannotDeleteDefault:
            return "Default providers cannot be deleted"
        }
    }
}
