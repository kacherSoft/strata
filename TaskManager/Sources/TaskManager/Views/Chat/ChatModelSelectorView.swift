import SwiftUI
import SwiftData

/// Dropdown model selector for Chat toolbar — shows all models from enabled providers.
struct ChatModelSelectorView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedProviderId: UUID?
    @Binding var selectedModelName: String

    @State private var providers: [AIProviderModel] = []

    /// Flattened list of provider+model pairs for the picker
    private var options: [ModelOption] {
        providers.flatMap { p in
            p.models.map { ModelOption(providerId: p.id, providerName: p.name, modelName: $0) }
        }
    }

    /// Current selection key for the picker
    private var selectionKey: String {
        "\(selectedProviderId?.uuidString ?? ""):\(selectedModelName)"
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
                Text(selectedModelName.isEmpty ? "Select model" : selectedModelName)
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
        .onAppear { loadProviders() }
    }

    private func loadProviders() {
        let repo = AIProviderRepository(modelContext: modelContext)
        providers = (try? repo.fetchEnabled()) ?? []
    }

    private func select(provider: AIProviderModel, model: String) {
        selectedProviderId = provider.id
        selectedModelName = model
    }
}

private struct ModelOption: Identifiable {
    let providerId: UUID
    let providerName: String
    let modelName: String
    var id: String { "\(providerId.uuidString):\(modelName)" }
}
