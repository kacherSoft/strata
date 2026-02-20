import SwiftUI
import SwiftData

struct CustomFieldsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomFieldDefinitionModel.sortOrder) private var definitions: [CustomFieldDefinitionModel]

    @State private var newFieldName = ""
    @State private var newFieldType: CustomFieldValueType = .text
    @State private var showDeleteConfirmation = false
    @State private var fieldToDelete: CustomFieldDefinitionModel?
    @FocusState private var isFieldNameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Custom Fields")
                    .font(.title)
                    .fontWeight(.semibold)

                // MARK: - Existing Fields

                VStack(alignment: .leading, spacing: 12) {
                    if definitions.isEmpty {
                        Text("No custom fields defined yet.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(definitions.enumerated()), id: \.element.id) { index, definition in
                            if index > 0 {
                                Divider()
                            }

                            HStack {
                                Image(systemName: iconName(for: definition.valueType))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)

                                Text(definition.name)
                                    .font(.body)

                                Spacer()

                                Text(displayName(for: definition.valueType))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Toggle("", isOn: Binding(
                                    get: { definition.isActive },
                                    set: { newValue in
                                        definition.isActive = newValue
                                        definition.touch()
                                    }
                                ))
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .accessibilityLabel("\(definition.name) active")

                                Button(role: .destructive) {
                                    fieldToDelete = definition
                                    showDeleteConfirmation = true
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
                .liquidGlass(.settingsCard)

                // MARK: - Add New Field

                VStack(alignment: .leading, spacing: 12) {
                    Text("Add Custom Field")
                        .font(.headline)

                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        TextField("Field name", text: $newFieldName)
                            .textFieldStyle(.roundedBorder)
                            .focused($isFieldNameFocused)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isFieldNameFocused = true
                    }

                    HStack {
                        Image(systemName: "tag")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        Text("Value Type")
                            .font(.body)

                        Spacer()

                        Picker("", selection: $newFieldType) {
                            ForEach(CustomFieldValueType.allCases, id: \.self) { type in
                                Text(displayName(for: type)).tag(type)
                            }
                        }
                        .frame(width: 120)
                    }

                    HStack {
                        Spacer()
                        Button {
                            addField()
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .disabled(newFieldName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(20)
                .liquidGlass(.settingsCard)

                Spacer()
            }
            .padding(24)
        }
        .confirmationDialog(
            "Delete Custom Field?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                if let definition = fieldToDelete {
                    deleteField(definition)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the field and all its values from every task. This action cannot be undone.")
        }
    }

    // MARK: - Actions

    private func addField() {
        let trimmed = newFieldName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let maxSort = definitions.map(\.sortOrder).max() ?? 0
        let definition = CustomFieldDefinitionModel(
            name: trimmed,
            valueType: newFieldType,
            sortOrder: maxSort + 1
        )
        modelContext.insert(definition)
        try? modelContext.save()
        newFieldName = ""
    }

    private func deleteField(_ definition: CustomFieldDefinitionModel) {
        let definitionId = definition.id
        let predicate = #Predicate<CustomFieldValueModel> { $0.definitionId == definitionId }
        do {
            try modelContext.delete(model: CustomFieldValueModel.self, where: predicate)
        } catch {
            // Values may already be absent
        }
        modelContext.delete(definition)
        try? modelContext.save()
        fieldToDelete = nil
    }

    // MARK: - Helpers

    private func displayName(for type: CustomFieldValueType) -> String {
        switch type {
        case .text: return "Text"
        case .number: return "Number"
        case .currency: return "Currency"
        case .date: return "Date"
        case .toggle: return "Toggle"
        }
    }

    private func iconName(for type: CustomFieldValueType) -> String {
        switch type {
        case .text: return "textformat"
        case .number: return "number"
        case .currency: return "dollarsign.circle"
        case .date: return "calendar"
        case .toggle: return "switch.2"
        }
    }
}
