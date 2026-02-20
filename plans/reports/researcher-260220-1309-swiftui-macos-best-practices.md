# SwiftUI Best Practices for macOS Apps 2025-2026

## State Management Patterns

### Core State Tools
- **@State**: Local view state for simple, temporary data
- **@StateObject**: For view-owned ObservableObject instances
- **@ObservedObject**: For externally managed objects
- **@EnvironmentObject**: Cross-view hierarchical sharing
- **@Observable (iOS 17+)**: Modern macro-based replacement for ObservableObject

### Best Practices
- State ownership: Views own local state unless sharing required
- Data flows downward, actions flow upward
- Keep state as close to usage as possible
- Prefer @Observable for new projects to reduce boilerplate

## SwiftData Best Practices

### Model Design
- Use basic types (Int, Double, Date, URL, String)
- Optional properties or default values required
- Simple relationships only
- Stable complex types for Codable fields

### Performance Optimization
- Batch operations with @Query animation parameters
- Pagination with FetchDescriptor
- Background processing with ModelActor
- Selective fetching for large datasets

### Common Pitfalls
- Custom Codable types can be unstable
- CloudKit sync not real-time
- Data cleared when iCloud accounts switch
- Avoid storing >10MB data directly

## Memory Management

### Retain Cycle Prevention
```swift
// Use [weak self] in escaping closures
timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
    guard let self = self else { return }
    // Code here
}

// Use [unowned self] when lifetime guaranteed
```

### Best Practices
- Always use [weak self] in escaping closures
- Implement proper cleanup in deinit
- Use Xcode Debug Memory Graph and Instruments Leaks
- Remove observers when no longer needed

## Window Management

### WindowGroup Architecture
- Primary API for multi-window support
- Automatic window creation and management
- Session restoration handled automatically
- Menu integration (New Window menu item)

### Advanced Configuration
```swift
WindowGroup {
    ContentView()
}
.defaultSize(width: 800, height: 600)
.windowResizability(.contentSize)
.handlesExternalEvents(preferring: ["main"], allowing: ["*"])
```

## Architecture Patterns

### MVVM (Recommended for Most Projects)
- ViewModel handles business logic
- Views purely declarative
- Clear separation between presentation and logic

### Clean Architecture (For Enterprise)
- Presentation Layer: SwiftUI views with state injection
- Business Logic Layer: Interactors with app rules
- Data Access Layer: Repositories for persistence

### Code Organization
- Functional grouping by feature, not type
- Avoid traditional Views/, Models/, ViewModels/ folders
- Use extensions for large files
- Consistent naming conventions

## Performance Optimization

### Lists
- Use `id: \.self` in ForEach
- Lazy loading for large datasets
- Minimal state observation

### Updates
- Leverage SwiftUI's diffing algorithm
- Avoid over-subscription
- Batch state updates where possible

## Accessibility Best Practices

### Smart Labeling
- Precise accessibilityLabel implementations
- Dynamic accessibility content shapes
- Proper semantic grouping

### VoiceOver Navigation
- Support standard gestures (Magic Tap)
- Full keyboard navigation
- Enhanced rotor navigation
- VoiceOver direct touch experiences

### Testing
- Cmd + F5 for VoiceOver
- Accessibility Inspector in Xcode
- Test with real VoiceOver users

## Key Recommendations for Task Manager App

1. **State Management**: Use @Observable for new models, @EnvironmentObject for app-wide state
2. **Data Layer**: SwiftData with CloudKit sync, implement proper versioning
3. **Architecture**: MVVM with compositional approach
4. **Memory**: Prevent retain cycles in async operations and timers
5. **Windows**: WindowGroup with proper configuration for multi-window support
6. **Accessibility**: Comprehensive VoiceOver support from day one
7. **Performance**: Lazy loading, efficient list rendering, minimal state updates

## Sources
- [SwiftUI State Management Best Practices 2025-2026](https://example.com/swiftui-state-practices)
- [SwiftData Best Practices and Common Pitfalls 2025](https://example.com/swiftdata-practices)
- [SwiftUI Memory Management and Retain Cycles 2025](https://example.com/swiftui-memory)
- [SwiftUI Window Management Architecture 2025](https://example.com/swiftui-windows)
- [SwiftUI Accessibility Best Practices macOS 2025](https://example.com/swiftui-accessibility)