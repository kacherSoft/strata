# Phase 5: Testing & Launch

**Priority:** HIGH | **Status:** Pending | **Effort:** 0.5-1 week

## Overview

Comprehensive testing, accessibility audit, performance optimization, and preparation for App Store submission.

## Context Links

- [PRD - Success Metrics](../../docs/product-requirements-document.md)
- [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [macOS HIG](https://developer.apple.com/design/human-interface-guidelines/platforms/designing-for-macos)

## Dependencies

- Phases 1-4 complete
- Apple Developer account
- App icon designed

## Key Insights

- Test on both macOS 15 Sequoia and 26 Tahoe
- VoiceOver testing is App Store requirement
- Code signing and notarization mandatory
- Performance profiling with Instruments

## Requirements

### Testing Scope
- Functional testing (all features)
- Cross-version testing (macOS 15, 26)
- Accessibility testing (VoiceOver, keyboard navigation)
- Performance testing (memory, CPU, response times)
- Security testing (no hardcoded keys, keychain works)

### Launch Prep
- App icon (all sizes)
- App Store screenshots
- App Store description
- Privacy policy
- Code signing
- Notarization
- DMG or pkg installer (if direct download)

## Test Plan

### 1. Functional Testing Checklist

**Task Management**
- [ ] Create task via quick entry (CMD+Shift+N)
- [ ] Create task via main window
- [ ] Edit task title, description, due date, priority, tags
- [ ] Complete task (checkbox)
- [ ] Delete task
- [ ] Search finds tasks by title
- [ ] Search finds tasks by description
- [ ] Search finds tasks by tag
- [ ] Filter by priority
- [ ] Filter by completion status
- [ ] Sort by date
- [ ] Sort by priority
- [ ] Tasks persist after app restart

**Global Shortcuts**
- [ ] CMD+Shift+N opens quick entry from any app
- [ ] CMD+Shift+T shows main window from any app
- [ ] CMD+Shift+E opens Enhance Me panel
- [ ] CMD+Shift+, opens Settings
- [ ] CMD+Shift+M cycles AI mode
- [ ] Shortcuts work with Finder in foreground
- [ ] Shortcuts work with Safari in foreground
- [ ] Shortcuts work with full-screen apps
- [ ] Custom shortcuts save correctly
- [ ] Conflict detection shows warning

**AI Enhancement**
- [ ] Gemini enhancement with valid key
- [ ] Gemini error with invalid key
- [ ] z.ai enhancement with valid key
- [ ] z.ai error with invalid key
- [ ] Mode switching updates label
- [ ] Side-by-side diff shows correctly
- [ ] Apply updates task description
- [ ] Copy copies to clipboard
- [ ] Cancel dismisses without changes
- [ ] Timeout shows user-friendly error
- [ ] Rate limit shows user-friendly error

**Settings**
- [ ] General tab toggles work
- [ ] AI configuration saves API keys
- [ ] Test connection button works
- [ ] Shortcuts tab records new shortcuts
- [ ] AI modes CRUD works
- [ ] Always-on-top keeps window above
- [ ] Settings persist after restart

**Notifications**
- [ ] Permission prompt on first launch
- [ ] Notification fires at due time
- [ ] Mark Complete action works
- [ ] View action opens app and highlights task

**Data Management**
- [ ] Export creates valid JSON
- [ ] Import restores tasks correctly
- [ ] Delete all tasks works

**Menu Bar**
- [ ] Icon appears in menu bar
- [ ] Menu items work correctly
- [ ] Quit terminates app

### 2. Cross-Version Testing

| Test | macOS 15 Sequoia | macOS 26 Tahoe |
|------|------------------|----------------|
| App launches | ⬜ | ⬜ |
| UI renders correctly | ⬜ | ⬜ |
| Liquid glass materials work | ⬜ | ⬜ |
| SwiftData operations | ⬜ | ⬜ |
| Global shortcuts | ⬜ | ⬜ |
| AI requests | ⬜ | ⬜ |
| Notifications | ⬜ | ⬜ |

### 3. Accessibility Testing

**VoiceOver**
- [ ] All buttons have accessible labels
- [ ] Task list reads correctly
- [ ] Forms navigable with VO
- [ ] Focus order is logical
- [ ] Enhance Me panel accessible
- [ ] Settings accessible

**Keyboard Navigation**
- [ ] Tab navigates form fields
- [ ] Enter submits forms
- [ ] Escape cancels/closes
- [ ] Arrow keys navigate lists
- [ ] Space toggles checkboxes

**Dynamic Type**
- [ ] Text scales with system settings
- [ ] Layout doesn't break at large sizes

**Reduce Motion**
- [ ] Animations disabled when preference set

### 4. Performance Testing

Run Instruments profiling for:

**Memory**
- [ ] Idle: <50MB
- [ ] With 100 tasks: <60MB
- [ ] With 1000 tasks: <100MB
- [ ] No memory leaks over 1 hour

**CPU**
- [ ] Idle: <5%
- [ ] During search: <20%
- [ ] During AI request: <15%

**Response Times**
- [ ] Cold launch: <1s
- [ ] Warm launch: <500ms
- [ ] Quick entry display: <200ms
- [ ] UI interactions: <100ms
- [ ] Search results: <100ms
- [ ] AI enhancement: 2-3s

**Disk**
- [ ] App bundle: <50MB
- [ ] SwiftData store scales linearly

### 5. Security Testing

- [ ] No API keys in source code
- [ ] No API keys in logs
- [ ] Keychain stores keys securely
- [ ] Export doesn't include API keys
- [ ] No hardcoded credentials
- [ ] HTTPS for all network requests

## Launch Preparation

### App Icon

Required sizes for macOS:
- 16x16
- 32x32
- 64x64 (32@2x)
- 128x128
- 256x256
- 512x512
- 1024x1024

**Design notes:**
- Should work on both light and dark backgrounds
- Recognizable at 16x16
- Suggest: checkmark or task-related icon with liquid glass effect

### App Store Assets

**Screenshots (required sizes):**
- 1280x800 or 1440x900 (13" display)
- 2560x1600 or 2880x1800 (optional, higher res)

**Screenshot content:**
1. Main task list view
2. Quick entry panel
3. Enhance Me with AI
4. Settings panel
5. (Optional) Notification example

**App Store Description:**
```
TaskFlow Pro - Your AI-Powered Task Manager for macOS

Capture tasks instantly from anywhere. Enhance them with AI. Stay focused with a beautiful, distraction-free interface.

FEATURES:
• Global Shortcuts - Press ⌘⇧N from any app to instantly add a task
• AI Enhancement - Use Google Gemini or z.ai to improve your task descriptions
• Custom AI Modes - Create your own AI prompts for different workflows
• Liquid Glass UI - Beautiful macOS Tahoe-inspired design
• Always On Top - Keep your tasks visible while you work
• Smart Search - Find any task instantly

REQUIREMENTS:
• macOS 15 Sequoia or later
• AI features require your own API key (Google Gemini or z.ai)

Built with love for productivity enthusiasts.
```

**Keywords:**
task manager, to-do, AI, productivity, notes, GTD, reminder, macOS, native

**Privacy Policy URL:**
Required - create simple policy stating:
- Local data storage only
- AI enhancement sends task text to selected provider
- No analytics/tracking
- No data sold

### Code Signing & Distribution

**Certificate Setup:**
```bash
# List available signing identities
security find-identity -v -p codesigning
```

**Sign the app:**
```bash
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: YOUR NAME (TEAM_ID)" \
  "TaskFlow Pro.app"
```

**Notarization:**
```bash
# Create zip for notarization
ditto -c -k --keepParent "TaskFlow Pro.app" "TaskFlow Pro.zip"

# Submit for notarization
xcrun notarytool submit "TaskFlow Pro.zip" \
  --apple-id "your@email.com" \
  --team-id "TEAM_ID" \
  --password "@keychain:AC_PASSWORD" \
  --wait

# Staple the ticket
xcrun stapler staple "TaskFlow Pro.app"
```

**Create DMG (for direct download):**
```bash
hdiutil create -volname "TaskFlow Pro" \
  -srcfolder "TaskFlow Pro.app" \
  -ov -format UDZO \
  "TaskFlow Pro.dmg"
```

### App Store Submission

1. Archive in Xcode: Product → Archive
2. Distribute App → App Store Connect
3. Wait for processing
4. Fill App Store Connect metadata
5. Submit for review

**Common rejection reasons to avoid:**
- Crashes on launch
- Incomplete metadata
- Missing privacy policy
- Placeholder content
- Broken links

## Implementation Steps

### Step 1: Automated Testing (Day 1)

Create basic XCTest suite:
```swift
import XCTest
@testable import TaskManager

final class TaskModelTests: XCTestCase {
    func testTaskCreation() {
        let task = TaskModel(title: "Test", taskDescription: "Desc")
        XCTAssertEqual(task.title, "Test")
        XCTAssertFalse(task.isCompleted)
    }
    
    func testTaskCompletion() {
        let task = TaskModel(title: "Test")
        task.isCompleted = true
        XCTAssertNotNil(task.completedDate)
    }
}

final class AIProviderTests: XCTestCase {
    func testGeminiNotConfigured() async {
        let provider = GeminiProvider()
        // Clear keychain for test
        KeychainService.shared.delete(.geminiAPIKey)
        XCTAssertFalse(provider.isConfigured)
    }
}
```

### Step 2: Manual Testing (Day 2)

Execute full test plan checklist above.

### Step 3: Performance Profiling (Day 2)

Use Instruments:
- Time Profiler
- Allocations
- Leaks
- System Trace

### Step 4: Accessibility Audit (Day 3)

- Enable VoiceOver (CMD+F5)
- Navigate entire app with VO
- Fix any unlabeled elements
- Test with Accessibility Inspector

### Step 5: Bug Fixes (Day 3-4)

Address all issues found in testing.

### Step 6: App Icon & Assets (Day 4)

- Create app icon in all sizes
- Take App Store screenshots
- Write App Store description

### Step 7: Code Signing (Day 5)

- Sign with Developer ID
- Notarize with Apple
- Create DMG if direct download

### Step 8: App Store Submission (Day 5)

- Archive and upload
- Fill metadata
- Submit for review

## Todo List

- [ ] Write XCTest unit tests for models
- [ ] Execute functional testing checklist
- [ ] Test on macOS 15 Sequoia
- [ ] Test on macOS 26 Tahoe
- [ ] Complete VoiceOver testing
- [ ] Complete keyboard navigation testing
- [ ] Profile with Instruments
- [ ] Fix memory leaks if any
- [ ] Optimize slow code paths
- [ ] Security audit (no hardcoded keys)
- [ ] Create app icon (all sizes)
- [ ] Take App Store screenshots
- [ ] Write App Store description
- [ ] Create privacy policy
- [ ] Code sign application
- [ ] Notarize with Apple
- [ ] Create DMG for direct download
- [ ] Submit to App Store

## Success Criteria

- [ ] All functional tests pass
- [ ] No crashes on either macOS version
- [ ] VoiceOver navigation works
- [ ] Memory <50MB idle
- [ ] Quick entry <200ms
- [ ] AI enhancement 2-3s
- [ ] App notarized successfully
- [ ] App Store submission accepted

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| App Store rejection | Low | Medium | Follow guidelines, test thoroughly |
| SwiftData bugs on Tahoe | Medium | Medium | File bug reports, have workarounds |
| Performance issues | Low | Medium | Profile early, optimize |

## Definition of Done

TaskFlow Pro v1.0 is complete when:
1. All PRD features implemented
2. All tests passing
3. Accessibility verified
4. Performance targets met
5. App notarized
6. Either App Store approved OR DMG ready for distribution

---

**Congratulations! 🎉**

After Phase 5, TaskFlow Pro is ready for users.

## Post-Launch

- Monitor crash reports (App Store Connect)
- Respond to user feedback
- Plan v1.1 with CloudKit sync
- Consider analytics for usage patterns
