import SwiftUI
import SwiftData

/// Chat behavior settings — default model, system prompt display.
struct ChatSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    private var chatMode: AIModeModel? {
        let descriptor = FetchDescriptor<AIModeModel>(
            predicate: #Predicate { $0.isBuiltIn && $0.name == "Chat" }
        )
        return try? modelContext.fetch(descriptor).first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Chat")
                    .font(.title2.bold())
                    .padding(.bottom, 4)

                GroupBox("Default Model") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let mode = chatMode {
                            HStack {
                                Text("Provider")
                                Spacer()
                                Text(mode.provider.displayName)
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("Model")
                                Spacer()
                                Text(mode.modelName)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Change via AI Modes → Chat")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("Chat mode not found")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                }

                if let mode = chatMode {
                    GroupBox("System Prompt") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(mode.systemPrompt)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                            Text("Edit via AI Modes → Chat")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 8)
                                .padding(.bottom, 4)
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
        }
    }
}
