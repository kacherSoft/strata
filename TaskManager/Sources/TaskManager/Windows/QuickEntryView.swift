import SwiftUI
import SwiftData
import TaskManagerUIComponents

struct QuickEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var notes = ""
    @State private var dueDate = Date()
    @State private var hasDate = false
    @State private var hasReminder = false
    @State private var priority: TaskPriority = .medium
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var showSuccess = false
    @State private var showValidationError = false
    @FocusState private var titleFocused: Bool
    
    var onDismiss: () -> Void
    var onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Quick Entry")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title field
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            TextField("Task title", text: $title)
                                .textFieldStyle(.plain)
                                .font(.title3)
                                .focused($titleFocused)
                            Text("*")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        
                        if showValidationError {
                            Label("Title is required", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .onChange(of: title) { _, _ in
                        showValidationError = false
                    }
                    
                    // Notes field
                    TextEditor(text: $notes)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 60, maxHeight: 80)
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    
                    // Options row
                    HStack(spacing: 16) {
                        // Due date toggle + picker
                        Toggle(isOn: $hasDate) {
                            Image(systemName: "calendar")
                        }
                        .toggleStyle(.button)
                        .foregroundStyle(hasDate ? .blue : .secondary)
                        
                        if hasDate {
                            DatePicker("", selection: $dueDate, displayedComponents: .date)
                                .labelsHidden()
                                .frame(width: 120)
                        }
                        
                        Divider()
                            .frame(height: 20)
                        
                        // Reminder toggle
                        Toggle(isOn: $hasReminder) {
                            Image(systemName: "bell")
                        }
                        .toggleStyle(.button)
                        .foregroundStyle(hasReminder ? .orange : .secondary)
                        
                        Spacer()
                        
                        // Priority picker
                        Picker("", selection: $priority) {
                            ForEach(TaskPriority.allCases, id: \.self) { p in
                                Text(p.rawValue.capitalized).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                    
                    // Tags
                    HStack {
                        TextField("Add tag...", text: $newTag)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                            .onSubmit {
                                addTag()
                            }
                        
                        Button("Add") {
                            addTag()
                        }
                        .disabled(newTag.isEmpty)
                    }
                    
                    if !tags.isEmpty {
                        TagCloud(tags: tags, onRemove: { tag in
                            tags.removeAll { $0 == tag }
                        })
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                if showSuccess {
                    Label("Task Added!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .transition(.opacity.combined(with: .scale))
                } else {
                    Button("Add Task") {
                        saveTask()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
        }
        .frame(width: 500, height: 380)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { titleFocused = true }
    }
    
    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !tags.contains(trimmed) else {
            newTag = ""
            return
        }
        tags.append(trimmed)
        newTag = ""
    }
    
    private func saveTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            showValidationError = true
            return
        }
        
        let task = TaskModel(
            title: trimmedTitle,
            taskDescription: notes,
            dueDate: hasDate ? dueDate : nil,
            priority: priority,
            tags: tags,
            hasReminder: hasReminder
        )
        modelContext.insert(task)
        try? modelContext.save()
        
        withAnimation(.spring(response: 0.3)) {
            showSuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onSave()
        }
    }
}
