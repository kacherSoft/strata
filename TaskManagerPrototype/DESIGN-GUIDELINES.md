# TaskManager - Liquid Glass UI Design Guidelines

**Version:** 1.0
**Date:** 2026-02-03
**Platform:** macOS 15+ (Sequoia)

---

## Overview

This design system implements Apple's **Liquid Glass** design language from OS 26. It features translucent materials, adaptive colors, and native macOS UI patterns.

---

## 1. Glass Materials

### Material Hierarchy

| Material | Usage | Opacity |
|----------|-------|---------|
| `.ultraThinMaterial` | Badges, buttons, tags | ~10% blur |
| `.thinMaterial` | Selected rows, cards | ~20% blur |
| `.regularMaterial` | Headers, panels | ~30% blur |
| `.thickMaterial` | Modal backgrounds | ~40% blur |
| `.ultraThickMaterial` | Overlays | ~50% blur |

### Implementation Pattern

```swift
// Basic glass background
.background(.ultraThinMaterial)

// With shape
.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

// With stroke border
.background(.regularMaterial)
.overlay {
    RoundedRectangle(cornerRadius: 12)
        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
}
```

### Selection State Pattern

```swift
.background(isSelected ? .thinMaterial : .ultraThinMaterial)
.overlay {
    if isSelected {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(.blue.opacity(0.5), lineWidth: 2)
    }
}
```

---

## 2. Color System

### Semantic Colors

| Usage | Color | Notes |
|-------|-------|-------|
| Primary text | `.primary` | Adapts to theme |
| Secondary text | `.secondary` | Vitality effect |
| Tertiary text | `.tertiary` | Disabled states |
| Accents | `.blue` | Primary actions |
| Destructive | `.red` | Delete actions |
| Warning | `.orange` | Due dates, priority |
| Success | `.green` | Completion |

### Priority Colors

```swift
.high  → .red
.medium → .orange
.low   → .blue
.none   → .clear
```

### Text with Vitality

```swift
// Use secondary style for vibrant text that stands out
.foregroundStyle(.secondary)
```

---

## 3. Typography

### Font Scale

| Element | Size | Weight |
|---------|------|--------|
| Header title | 20pt | Semibold |
| Section header | 15pt | Medium |
| Body text | 13pt | Regular |
| Secondary text | 12pt | Regular |
| Caption | 11pt | Regular |
| Tags | 10pt | Regular |

### SF Symbols Scale

| Context | Size |
|---------|------|
| Large icons | 48pt |
| Action icons | 20pt |
| Small icons | 13pt |
| Inline icons | 10-11pt |

---

## 4. Component Specifications

### 4.1 Button Components

#### Action Button (Circular)

```swift
ActionButton(icon: "pencil", action: {})
```

- **Size:** 28x28pt
- **Background:** `.ultraThinMaterial`
- **Icon:** 13pt SF Symbol
- **Shape:** Circle

#### Primary Button

```swift
PrimaryButton(title: "Create Task", icon: "plus") {}
```

- **Padding:** H:16pt, V:10pt
- **Background:** Linear gradient blue
- **Corner radius:** 8pt
- **Shadow:** `.blue.opacity(0.3)`, radius 4pt

#### Floating Action Button

```swift
FloatingActionButton(icon: "plus") {}
```

- **Size:** 52x52pt
- **Background:** Linear gradient blue
- **Shape:** Circle
- **Shadow:** `.blue.opacity(0.4)`, radius 12pt

### 4.2 Input Components

#### Search Bar

```swift
SearchBar(text: $searchText)
```

- **Height:** 36pt
- **Corner radius:** 8pt
- **Padding:** H:12pt, V:8pt
- **Background:** `.ultraThinMaterial`
- **Focus state:** Blue border, 1pt

#### Textarea Field

```swift
TextareaField(text: $notes, placeholder: "Add notes...", height: 80)
```

- **Corner radius:** 8pt
- **Padding:** H:12pt, V:8pt
- **Font:** 13pt system
- **Background:** `.ultraThinMaterial`

#### Priority Picker

```swift
PriorityPicker(selectedPriority: $selectedPriority)
```

- **Option size:** 60x56pt
- **Spacing:** 12pt between options
- **Selected:** Colored background + border 2pt
- **Unselected:** `.ultraThinMaterial`

### 4.3 Display Components

#### Tag Chip

```swift
TagChip(text: "design")
```

- **Padding:** H:8pt, V:3pt
- **Corner radius:** 4pt
- **Font:** 10pt
- **Background:** `.ultraThinMaterial`

#### Task Row

```swift
TaskRow(task: task, isSelected: selectedTask?.id == task.id)
```

- **Padding:** 16pt
- **Corner radius:** 12pt
- **Spacing:** 16pt between elements
- **Shadow:** `.black.opacity(0.05)`, radius 4pt

#### Progress Indicator

```swift
ProgressIndicator(current: 3, total: 5)
```

- **Container padding:** 12pt
- **Bar height:** 6pt
- **Corner radius:** 3pt
- **Fill color:** `.blue`
- **Track:** `.ultraThinMaterial`

#### Empty State

```swift
EmptyStateView(icon: "tray", title: "No tasks", message: "Get started...")
```

- **Icon:** 48pt
- **Title:** 17pt Semibold
- **Message:** 13pt Regular
- **Background:** `.ultraThinMaterial`

---

## 5. Spacing & Layout

### Standard Spacing Scale

| Name | Value | Usage |
|------|-------|-------|
| xs | 4pt | Tight elements |
| sm | 8pt | Related items |
| md | 12pt | Section spacing |
| lg | 16pt | Component padding |
| xl | 20pt | Header padding |

### Corner Radius Scale

| Name | Value | Usage |
|------|-------|-------|
| small | 4pt | Tags, chips |
| medium | 8pt | Inputs, buttons |
| large | 12pt | Cards, rows |
| circle | Full | Circular buttons |

---

## 6. Layout Patterns

### NavigationSplitView

```swift
NavigationSplitView {
    SidebarView(selectedItem: $selectedItem)
} detail: {
    DetailPanelView(...)
}
.navigationSplitViewStyle(.balanced)
```

### Sheet (Modal)

```swift
.sheet(isPresented: $showSheet) {
    NewTaskSheet(isPresented: $showSheet)
}
```

- **Min size:** 500x400pt
- **Form style:** `.grouped`

---

## 7. Dark Mode

### Implementation

All components automatically support dark mode through:
- Semantic colors (`.primary`, `.secondary`)
- SF Symbols (auto-adapt)
- Materials (auto-adjust)

### Testing

Toggle dark mode in System Settings or Xcode preview:
```swift
#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
```

---

## 8. Accessibility

### Minimum Contrast Ratios

- **Text:** 4.5:1 (WCAG AA)
- **Large text:** 3:1
- **UI components:** 3:1

### Best Practices

- Use semantic colors
- Provide VoiceOver labels
- Support keyboard navigation
- Include focus indicators (blue border)

---

## 9. Animation & Transitions

### Standard Transitions

```swift
// Slide from bottom
.transition(.move(edge: .bottom))

// Fade
.transition(.opacity)

// Scale
.transition(.scale(scale: 0.9))
```

### Animation Duration

| Type | Duration |
|------|----------|
| Micro (hover) | 0.15s |
| Short (toggle) | 0.2s |
| Medium (sheet) | 0.3s |
| Long (complex) | 0.4s |

---

## 10. Component Library

### All Available Components

| Component | File | Lines |
|-----------|------|-------|
| ContentView | TaskManagerPrototype.swift | 15-40 |
| SidebarView | TaskManagerPrototype.swift | 42-72 |
| SidebarRow | TaskManagerPrototype.swift | 74-103 |
| DetailPanelView | TaskManagerPrototype.swift | 105-176 |
| HeaderView | TaskManagerPrototype.swift | 178-229 |
| SearchBar | TaskManagerPrototype.swift | 231-266 |
| MenuButton | TaskManagerPrototype.swift | 268-290 |
| TaskListView | TaskManagerPrototype.swift | 292-311 |
| TaskRow | TaskManagerPrototype.swift | 313-391 |
| TagCloud | TaskManagerPrototype.swift | 393-406 |
| TagChip | TaskManagerPrototype.swift | 408-421 |
| PriorityIndicator | TaskManagerPrototype.swift | 423-441 |
| TaskDetailView | TaskManagerPrototype.swift | 443-515 |
| EmptyStateView | TaskManagerPrototype.swift | 517-540 |
| NewTaskSheet | TaskManagerPrototype.swift | 542-636 |
| EditTaskSheet | TaskManagerPrototype.swift | 638-714 |
| TextareaField | TaskManagerPrototype.swift | 716-746 |
| PriorityPicker | TaskManagerPrototype.swift | 748-793 |
| PriorityOption | TaskManagerPrototype.swift | 795-826 |
| ActionButton | TaskManagerPrototype.swift | 828-843 |
| PrimaryButton | TaskManagerPrototype.swift | 845-873 |
| FloatingActionButton | TaskManagerPrototype.swift | 875-898 |
| ProgressIndicator | TaskManagerPrototype.swift | 900-940 |

---

## 11. Quick Reference

### Creating a New Glass Component

```swift
struct MyGlassCard: View {
    var body: some View {
        VStack {
            Text("Content")
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}
```

### Reusable Component Template

```swift
// MARK: - Component Name
struct ComponentName: View {
    // Input bindings
    let title: String
    @Binding var isSelected: Bool

    var body: some View {
        // UI here
    }
}
```

---

## 12. Resources

- [Apple Liquid Glass Documentation](https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass)
- [SF Symbols](https://developer.apple.com/sf-symbols/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
