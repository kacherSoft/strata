import SwiftUI
import SwiftData

/// Dropdown model selector for Chat input — shows all models from enabled providers.
struct ChatModelSelectorView: View {
    @Binding var selectedProviderId: UUID?
    @Binding var selectedModelName: String

    @Query(filter: #Predicate<AIProviderModel> { $0.isEnabled },
           sort: \AIProviderModel.sortOrder)
    private var providers: [AIProviderModel]

    /// Resolve the provider — by ID first, then by model name match
    private var resolvedProvider: AIProviderModel? {
        if let pid = selectedProviderId {
            return providers.first { $0.id == pid }
        }
        // Fallback: find provider whose models contain the selected model
        return providers.first { $0.models.contains(selectedModelName) }
    }

    /// Display label with provider prefix: "Gemini / gemini-flash-latest"
    private var displayLabel: String {
        guard !selectedModelName.isEmpty else { return "Select model" }
        if let p = resolvedProvider {
            // Auto-set providerId if it was nil (legacy mode without aiProviderId)
            if selectedProviderId == nil { selectedProviderId = p.id }
            return "\(p.name) / \(selectedModelName)"
        }
        return selectedModelName
    }

    var body: some View {
        Menu {
            ForEach(providers) { provider in
                Section(provider.name) {
                    ForEach(provider.models, id: \.self) { model in
                        Button(action: { select(provider: provider, model: model) }) {
                            HStack {
                                Text(model)
                                if provider.id == selectedProviderId && model == selectedModelName {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(displayLabel)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func select(provider: AIProviderModel, model: String) {
        selectedProviderId = provider.id
        selectedModelName = model
    }
}
