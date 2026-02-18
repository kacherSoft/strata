import SwiftUI

// MARK: - Sidebar View
public struct SidebarView: View {
    @Binding var selectedItem: SidebarItem?
    let tags: [String]
    @Binding var selectedTag: String?
    @Binding var selectedDate: Date?
    @Binding var dateFilterMode: CalendarFilterMode
    @Binding var selectedPriority: TaskItem.Priority?
    let tasks: [TaskItem]
    @Binding var isKanbanMode: Bool
    let showsKanbanPremiumBadge: Bool

    public init(
        selectedItem: Binding<SidebarItem?>,
        tags: [String] = [],
        selectedTag: Binding<String?> = .constant(nil),
        selectedDate: Binding<Date?> = .constant(nil),
        dateFilterMode: Binding<CalendarFilterMode> = .constant(.all),
        selectedPriority: Binding<TaskItem.Priority?> = .constant(nil),
        tasks: [TaskItem] = [],
        isKanbanMode: Binding<Bool> = .constant(false),
        showsKanbanPremiumBadge: Bool = false
    ) {
        self._selectedItem = selectedItem
        self.tags = tags
        self._selectedTag = selectedTag
        self._selectedDate = selectedDate
        self._dateFilterMode = dateFilterMode
        self._selectedPriority = selectedPriority
        self.tasks = tasks
        self._isKanbanMode = isKanbanMode
        self.showsKanbanPremiumBadge = showsKanbanPremiumBadge
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    isKanbanMode = false
                } label: {
                    Image(systemName: "list.bullet")
                        .frame(width: 28, height: 28)
                        .background(!isKanbanMode ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("List View")

                Button {
                    isKanbanMode = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.3x3")
                        if showsKanbanPremiumBadge {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.yellow)
                        }
                    }
                    .frame(height: 28)
                    .padding(.horizontal, 8)
                    .background(isKanbanMode ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Kanban View")

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)

            List(selection: $selectedItem) {
                Section("My Work") {
                    ForEach(SidebarItem.mainItems) { item in
                        SidebarRow(item: item)
                            .tag(item)
                    }
                }

                Section("Tags") {
                    if tags.isEmpty {
                        Text("No tags yet")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 2)
                    } else {
                        ForEach(tags, id: \.self) { tagName in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(tagColor(for: tagName))
                                    .frame(width: 8, height: 8)

                                Text(tagName)
                                    .font(.system(size: 13))

                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedTag == tagName
                                        ? tagColor(for: tagName).opacity(0.2)
                                        : Color.clear)
                            )
                            .onTapGesture {
                                if selectedTag == tagName {
                                    selectedTag = nil
                                } else {
                                    selectedTag = tagName
                                    selectedItem = nil
                                    selectedPriority = nil
                                }
                            }
                        }
                    }
                }

                Section("Priority") {
                    ForEach(priorityFilterOptions, id: \.0) { label, icon, color, priority in
                        HStack(spacing: 8) {
                            Image(systemName: icon)
                                .foregroundStyle(color)
                                .font(.system(size: 12))
                                .frame(width: 16)

                            Text(label)
                                .font(.system(size: 13))

                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedPriority == priority
                                    ? color.opacity(0.2)
                                    : Color.clear)
                        )
                        .onTapGesture {
                            if selectedPriority == priority {
                                selectedPriority = nil
                            } else {
                                selectedPriority = priority
                                selectedItem = nil
                                selectedTag = nil
                                selectedDate = nil
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Calendar section
            VStack(spacing: 8) {
                CalendarGridView(
                    selectedDate: $selectedDate,
                    dateInfo: calendarDateInfo
                )
                .padding(.horizontal, 12)

                if selectedDate != nil {
                    HStack(spacing: 6) {
                        // Only show filter pills when date has both types
                        if selectedDateHasBothTypes {
                            ForEach(CalendarFilterMode.allCases, id: \.self) { mode in
                                Button(action: { dateFilterMode = mode }) {
                                    Group {
                                        switch mode {
                                        case .all:
                                            Image(systemName: "tray.2")
                                        case .deadline:
                                            Image(systemName: "clock.badge.exclamationmark")
                                                .foregroundStyle(.red, .primary)
                                        case .created:
                                            Image(systemName: "plus.circle")
                                                .foregroundStyle(.green, .primary)
                                        }
                                    }
                                    .font(.system(size: 13))
                                    .frame(width: 28, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(dateFilterMode == mode
                                                ? Color.accentColor.opacity(0.15)
                                                : Color.clear)
                                    )
                                }
                                .buttonStyle(.plain)
                                .help(mode.rawValue)
                            }
                        }

                        Spacer()

                        Button(action: { selectedDate = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear date filter")
                    }
                    .padding(.horizontal, 12)
                }
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("Task Manager")
    }

    private var priorityFilterOptions: [(String, String, Color, TaskItem.Priority)] {
        [
            ("High", "flag.fill", .red, .high),
            ("Medium", "flag.fill", .orange, .medium),
            ("Low", "flag.fill", .blue, .low),
            ("None", "flag", .secondary, .none),
        ]
    }

    private var selectedDateHasBothTypes: Bool {
        guard let date = selectedDate else { return false }
        let calendar = Calendar.current
        var hasCreated = false
        var hasDeadline = false
        for task in tasks {
            if let createdAt = task.createdAt, calendar.isDate(createdAt, inSameDayAs: date) {
                hasCreated = true
            }
            if let dueDate = task.dueDate, calendar.isDate(dueDate, inSameDayAs: date) {
                hasDeadline = true
            }
            if hasCreated && hasDeadline { return true }
        }
        return hasCreated && hasDeadline
    }

    private var calendarDateInfo: [Date: CalendarDateInfo] {
        let calendar = Calendar.current
        var info: [Date: CalendarDateInfo] = [:]

        for task in tasks {
            if let createdAt = task.createdAt {
                let day = calendar.startOfDay(for: createdAt)
                let existing = info[day] ?? CalendarDateInfo(hasCreatedTask: false, hasDeadline: false)
                info[day] = CalendarDateInfo(hasCreatedTask: true, hasDeadline: existing.hasDeadline)
            }
            if let dueDate = task.dueDate {
                let day = calendar.startOfDay(for: dueDate)
                let existing = info[day] ?? CalendarDateInfo(hasCreatedTask: false, hasDeadline: false)
                info[day] = CalendarDateInfo(hasCreatedTask: existing.hasCreatedTask, hasDeadline: true)
            }
        }

        return info
    }
}
