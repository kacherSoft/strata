# SwiftData Patterns and Anti-Patterns for 2025-2026

## Model Design Best Practices

### Basic Model Structure
```swift
@Model
final class TaskItem {
    var title: String
    var notes: String?
    var isComplete: Bool
    var createdAt: Date
    var updatedAt: Date
    var priority: Int

    init(title: String, priority: Int = 0) {
        self.title = title
        self.priority = priority
        self.createdAt = .now
        self.updatedAt = .now
        self.isComplete = false
    }
}
```

### Property Type Guidelines
- **Use Foundation types**: Int, Double, Date, URL, String
- **Choose stable complex types**: CGPoint, CLLocation
- **Manage custom Codable types carefully**: Use widely adopted types
- **Consider optionality**: Make properties optional or provide defaults

## Relationship Handling

### One-to-One Relationship
```swift
@Model
final class Task {
    var title: String
    @Relationship(.nullify)
    var assignee: User?

    init(title: String) { self.title = title }
}

@Model
final class User {
    var name: String
    @Relationship(.nullify, inverse: \Task.assignee)
    var assignedTasks: [Task] = []
}
```

### One-to-Many Relationship
```swift
@Model
final class Project {
    var name: String
    @Relationship(.cascade)
    var tasks: [Task] = []

    init(name: String) { self.name = name }
}
```

## Repository Pattern Implementation

```swift
protocol TaskRepository {
    func save() throws
    func fetchTasks() throws -> [Task]
    func fetchTasks(predicate: NSPredicate) throws -> [Task]
    func delete(task: Task) throws
}

class SwiftDataTaskRepository: TaskRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save() throws {
        try modelContext.save()
    }

    func fetchTasks() throws -> [Task] {
        try modelContext.fetch(FetchDescriptor<Task>())
    }

    func fetchTasks(predicate: NSPredicate) throws -> [Task] {
        let descriptor = FetchDescriptor<Task>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }

    func delete(task: Task) throws {
        modelContext.delete(task)
    }
}
```

## Migration Strategies

### Versioned Schema Pattern
```swift
let versionedSchema = VersionedSchema(
    schemas: [
        SchemaV1.self,
        SchemaV2.self,
        SchemaV3.self
    ],
    migrationPlan: MigrationPlan()
)

struct MigrationPlan: SchemaMigrationPlan {
    static var stages: [MigrationStage] {
        [V1ToV2(), V2ToV3()]
    }
}

struct V2ToV3: MigrationStage {
    var schemaVersion: Schema.Version = Schema.Version(3, 0)

    func migrate(modelContext: ModelContext) {
        let tasks = modelContext.fetch(FetchDescriptor<Task>())
        for task in tasks {
            task.updatedAt = .now
        }
        try? modelContext.save()
    }
}
```

## Query Optimization

### Type-Specific Filtering (iOS 26+)
```swift
// Property-based filtering
let highPriorityTasks = context.fetch(
    FetchDescriptor<Task>(
        predicate: #Predicate { task in
            task.priority >= 5
        }
    )
)

// Selective property fetching
let descriptors = FetchDescriptor<Task>(
    predicate: searchPredicate,
    propertiesToFetch: [\Task.title, \Task.createdAt]
)

// Fetch limiting for performance
descriptor.fetchLimit = 50
```

## Background Thread Handling

### ModelActor Pattern
```swift
let modelActor = ModelActor(modelContainer: container)

// Background data processing
let result = await modelActor.perform { context in
    let tasks = try context.fetch(FetchDescriptor<Task>())
    return tasks.filter { !$0.isComplete }
}

// Task-based operations
Task {
    let result = await fetchBackgroundData()
    await MainActor.run {
        updateUI(with: result)
    }
}
```

## Common Anti-Patterns

1. **Over-Complex Models**: Avoid models with too many relationships
2. **Missing Inverse Relationships**: Always set inverse relationships
3. **Unnecessary Custom Codable Types**: Use Foundation types when possible
4. **Main Thread Blocking**: Offload heavy operations to background threads
5. **Poor Context Management**: Create context hierarchy properly

## Testing SwiftData Models

### Unit Testing with Mocks
```swift
class TaskRepositoryTests: XCTestCase {
    var repository: TaskRepository!
    var mockContext: ModelContext!

    override func setUp() {
        super.setUp()
        // Create test container and context
        let container = ModelContainer(for: Task.self)
        mockContext = ModelContext(container)
        repository = SwiftDataTaskRepository(modelContext: mockContext)
    }

    func testFetchTasks() async throws {
        // Arrange
        let task = Task(title: "Test Task")
        mockContext.insert(task)

        // Act
        let tasks = try await repository.fetchTasks()

        // Assert
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.title, "Test Task")
    }
}
```

### UI Testing with @Query
```swift
struct TaskListView: View {
    @Query var tasks: [Task]

    var body: some View {
        List(tasks) { task in
            Text(task.title)
        }
    }
}
```

## Key Recommendations

1. **Use @Relationship explicitly** for non-trivial relationships
2. **Configure delete rules** appropriately (cascade, nullify, deny)
3. **Implement proper error handling** for async operations
4. **Use ModelActor** for thread-safe background operations
5. **Fetch selectively** to improve performance
6. **Set inverse relationships** to maintain data consistency
7. **Test concurrent scenarios** to ensure thread safety

## Migration Checklist

- [ ] Define continuous migration paths
- [ ] Test migrations with production-like data
- [ ] Document breaking changes
- [ ] Use lightweight migration when possible
- [ ] Validate data integrity after migration

## Performance Optimization Tips

- Use fetch limits in list views
- Select only needed properties in queries
- Batch insert/delete operations
- Profile with Instruments before optimizing
- Use @Query animation parameters for better performance