# Phase 3: InlineEnhanceHUD + Panel

## Context Links
- Parent: [plan.md](plan.md)
- Depends on: [phase-02-text-focus-manager.md](phase-02-text-focus-manager.md)

## Overview
| Property | Value |
|----------|-------|
| Priority | P1 |
| Status | Pending |
| Effort | 1.5h |

Create a floating HUD that shows enhancement progress. Must be visible **above all apps** without stealing focus — uses NSPanel with `.nonactivatingPanel` style, following the existing `QuickEntryPanel` pattern.

## Requirements

### Functional
- Display above/near the text field being enhanced (in any app)
- Show AI mode name and loading indicator
- Support success/error states
- Auto-dismiss after completion
- Smooth fade in/out animations

### Non-Functional
- **Does NOT steal focus** from the source app's text field
- **Click-through** — ignores mouse events
- Visible on all desktops/spaces
- Stays visible when our app is in background
- Lightweight, minimal visual footprint

## Architecture

### InlineEnhanceHUDPanel (NSPanel)

The panel is a borderless, non-activating NSPanel that floats above all windows.

```swift
final class InlineEnhanceHUDPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = true
    }
    
    func setContent<V: View>(_ view: V) {
        contentView = NSHostingView(rootView: view)
    }
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

**Critical properties explained:**
| Property | Why |
|----------|-----|
| `.nonactivatingPanel` | Doesn't activate our app when shown |
| `.borderless` | No title bar — just the capsule |
| `ignoresMouseEvents = true` | Click-through, doesn't interfere |
| `canBecomeKey = false` | Never steals keyboard focus |
| `hidesOnDeactivate = false` | Stays visible when our app is background |
| `.canJoinAllSpaces` | Visible on all desktops |
| `level = .floating` | Above all normal windows |

### InlineEnhanceHUD (SwiftUI View)

```swift
struct InlineEnhanceHUD: View {
    let modeName: String
    let state: HUDState
    
    enum HUDState: Equatable {
        case enhancing
        case success
        case error(String)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            stateIcon
            stateText
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8)
    }
    
    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .enhancing:
            ProgressView().controlSize(.small)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
    
    @ViewBuilder
    private var stateText: some View {
        switch state {
        case .enhancing:
            Text("Enhancing with \"\(modeName)\"...")
        case .success:
            Text("Enhanced")
        case .error(let message):
            Text(message).lineLimit(1)
        }
    }
}
```

### Visual Design

```
┌──────────────────────────────────┐
│ ⏳ Enhancing with "Correct Me"... │  ← .enhancing state
└──────────────────────────────────┘

┌──────────────────────────────────┐
│ ✓ Enhanced                       │  ← .success (auto-dismiss 1s)
└──────────────────────────────────┘

┌──────────────────────────────────┐
│ ⚠️ No AI mode configured         │  ← .error (auto-dismiss 3s)
└──────────────────────────────────┘
```

## Related Code Files

### Reference Files (patterns to follow)
- `TaskManager/Sources/TaskManager/Windows/QuickEntryPanel.swift` — NSPanel pattern with `.nonactivatingPanel`
- `TaskManager/Sources/TaskManager/Windows/EnhanceMePanel.swift` — NSPanel `setContent()` pattern

### New Files
- `TaskManager/Sources/TaskManager/Windows/InlineEnhanceHUDPanel.swift`
- `TaskManager/Sources/TaskManager/Views/Components/InlineEnhanceHUD.swift`

## Todo List

- [ ] Create InlineEnhanceHUDPanel.swift in Windows/
- [ ] Create InlineEnhanceHUD.swift in Views/Components/
- [ ] Implement HUDState enum
- [ ] Implement HUD view with 3 states
- [ ] Test panel positioning near text fields
- [ ] Verify panel doesn't steal focus

## Success Criteria

- [ ] HUD appears as floating capsule above all windows
- [ ] HUD does NOT activate our app or steal focus
- [ ] Shows mode name during enhancement
- [ ] Progress indicator animates
- [ ] Success state shows green checkmark
- [ ] Error state shows orange warning + message
- [ ] Click-through — mouse events pass to app below
- [ ] Visible on all desktops/spaces

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| HUD positioned off-screen (multi-monitor) | Low | Clamp to visible screen bounds |
| `.ultraThinMaterial` looks different on various backgrounds | Low | Acceptable — native macOS behavior |
| Panel flickers on show/hide | Low | Use fade animations via `NSAnimationContext` |

## Next Steps

After completion, proceed to [Phase 4: InlineEnhanceCoordinator](phase-04-coordinator.md)
