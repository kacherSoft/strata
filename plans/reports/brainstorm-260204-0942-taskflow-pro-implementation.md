# TaskFlow Pro - Implementation Brainstorming Report

**Date:** 2026-02-04
**Project:** TaskFlow Pro - Personal Task Management for macOS
**Target:** macOS 26 Tahoe

---

## Executive Summary

**Project Goal:** Build complete task management app with AI enhancement, liquid glass UI, and global shortcuts for macOS 26 Tahoe.

**User Requirements:**
- Scope: **Complete** - All PRD features implemented
- Risk Tolerance: **Aggressive** - Cutting edge, file bugs as they arise
- AI Providers: **Google Gemini + z.ai** (not OpenAI/Anthropic)

**Key Finding:** macOS 26 Tahoe is REAL (released late 2025) with official "Liquid Glass" design language - perfect alignment with app vision.

---

## Problem Statement

TaskFlow Pro must bridge gap between simple note apps and complex PM tools. Individual users need:
1. Instant task capture (global shortcuts, <200ms)
2. AI-powered enhancement with custom modes
3. Native macOS 26 Tahoe integration
4. Liquid glass dark mode UI
5. Always-on-top accessibility

**Timeline:** 4-6 weeks for solo developer

---

## Architecture Decisions

### Data Layer: SwiftData (Aggressive Choice)

| Factor | SwiftData | Core Data | GRDB |
|--------|-----------|-----------|------|
| Performance | 🔴 Slowest | 🟡 Medium | 🟢 Fastest |
| Stability | 🔴 New bugs on 15/26 | 🟢 20+ years mature | 🟢 Very mature |
| Boilerplate | 🟢 60% less code | 🔴 High complexity | 🟡 Medium |
| macOS 26 Ready | 🟢 Built for Tahoe | 🟡 Legacy APIs | 🟡 Third-party |

**Recommendation:** **SwiftData**

**Rationale:**
- 60% less code = faster shipping (critical for 4-6 week timeline)
- Built for macOS 26 Tahoe's new features
- Aggressive risk tolerance accepts potential bugs
- For 5,000 tasks, performance diff is negligible
- Community issues on macOS 15 may be resolved in Tahoe

**Mitigation Strategy:**
- File bugs immediately via Feedback Assistant
- Have Core Data fallback plan if critical issues arise
- Monitor [Apple Developer Forums - SwiftUI](https://developer.apple.com/forums/topics/ui-frameworks-topic/ui-frameworks-topic-swiftui) for Tahoe updates

**Sources:**
- [SwiftData vs Core Data: Which Should You Use in 2025?](https://commitstudiogs.medium.com/swiftdata-vs-core-data-which-should-you-use-in-2025-61b3f3a1abb1)
- [Key Considerations Before Using SwiftData](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/)
- [GRDB Performance Wiki](https://github.com/groue/GRDB.swift/wiki/Performance)

### AI Integration: Google Gemini + z.ai

**Google Gemini:**
- Official Swift SDK available
- Growing Apple partnership (Siri integration Feb 2026)
- Strong documentation for SwiftUI

**z.ai (GLM 4.6):**
- Standard HTTP REST API
- No official Swift SDK → use URLSession
- Highly rated for coding tasks

**Architecture:**
```swift
protocol AIProvider {
    func enhance(text: String, mode: AIMode) async throws -> String
}

struct GeminiProvider: AIProvider { /* Google AI SDK */ }
struct ZAIProvider: AIProvider { /* URLSession + REST */ }
```

**Sources:**
- [Integrating Google Gemini AI with Swift and SwiftUI](https://www.appcoda.com/swiftui-google-gemini-ai/)
- [Implement Gemini AI SDK with SwiftUI](https://www.swiftanytime.com/blog/implement-gemini-ai-sdk-with-swiftui)
- [Z.ai API Quick Start](https://docs.z.ai/guides/overview/quick-start)
- [Z.ai HTTP API Guide](https://docs.z.ai/guides/develop/http/introduction)
- [Integrate Z.ai GLM 4.6 API Guide](https://zoer.ai/posts/zoer/integrate-z-ai-glm-4-6-api-guide)

### Global Shortcuts: KeyboardShortcuts Package

**Decision:** Use [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)

**Rationale:**
- Battle-tested, widely adopted
- Fully sandbox + Mac App Store compatible
- Built-in conflict detection
- User-customizable UI included

**Avoid:** Building own Carbon API wrapper (YAGNI - reinventing wheel)

**Sources:**
- [sindresorhus/KeyboardShortcuts GitHub](https://github.com/sindresorhus/KeyboardShortcuts)
- [How to Add Global Keyboard Shortcuts to MacOS Apps SwiftUI](https://tnvmadhav.me/guides/how-to-add-global-keyboard-shortcuts-to-macos-apps-swiftui/)

---

## Technical Stack Summary

| Component | Technology | Rationale |
|-----------|------------|-----------|
| **UI Framework** | SwiftUI | Native Tahoe integration, liquid glass materials |
| **Data Layer** | SwiftData | 60% less code, Tahoe-ready |
| **Shortcuts** | KeyboardShortcuts pkg | Proven, App Store safe |
| **AI Providers** | Gemini SDK + z.ai REST | User-requested, HTTP-based fallback |
| **Storage** | Core Data SQLite backing | SwiftData default |
| **Networking** | URLSession | Native, async/await |
| **Security** | Keychain Services | API key storage |

---

## Known Risks & Mitigations

### Risk 1: SwiftData SwiftUI Performance Issues

**Status:** Reported on macOS 15 Sequoia
**Impact:** UI lag, potential crashes
**Probability:** Medium (may be fixed in Tahoe)

**Mitigation:**
- Test early on macOS 26 Tahoe beta/RC
- Profile with Instruments (Time Profiler)
- Core Data fallback if critical
- File bug reports with reproducible cases

**Source:** [Hacker News - Performance regressions in SwiftUI apps](https://news.ycombinator.com/item?id=41139144)

### Risk 2: Global Shortcut Conflicts

**Status:** High probability with productivity apps
**Impact:** Shortcuts don't work, user frustration

**Mitigation:**
- Use KeyboardShortcuts package (built-in conflict detection)
- Allow user customization (defaults can conflict)
- Document conflicts in help
- Provide visual feedback when shortcut fails

### Risk 3: AI API Rate Limits/Costs

**Status:** User brings own API key
**Impact:** Enhancement failures, unexpected costs

**Mitigation:**
- Show usage statistics in settings
- Implement request queuing (max 1 req/sec)
- Cache common enhancements
- Clear error messages with retry option
- Implement timeout + retry logic

### Risk 4: Liquid Glass Performance on Older Macs

**Status:** Visual effects are CPU/GPU intensive
**Impact:** Laggy animations, battery drain

**Mitigation:**
- Test on minimum supported hardware
- Provide "reduced motion" toggle
- Use `.thinMaterial` instead of `.ultraThickMaterial` on older devices
- Monitor frame times (target 16ms = 60fps)

---

## Implementation Phases (Updated for Complete Scope)

### Phase 1: Foundation (Week 1.5)
- SwiftData models (Task, AIMode, Settings)
- Basic task list UI with existing components
- Task CRUD operations
- Search/filter functionality

### Phase 2: Global Shortcuts (Week 1)
- KeyboardShortcuts package integration
- Quick-entry NSPanel (CMD+Shift+N)
- Main window shortcut (CMD+Shift+T)
- Menu bar icon + menu

### Phase 3: AI Integration (Week 1.5)
- AIProvider protocol + Gemini implementation
- z.ai REST client
- Enhance Me panel with diff view
- Custom AI mode management
- API key secure storage (Keychain)

### Phase 4: Polish + Advanced Features (Week 1)
- Liquid glass refinement (all Tahoe materials)
- Settings panel (all tabs)
- Always-on-top mode
- macOS notifications + interactive actions
- Data export/import
- Micro-interactions + animations

### Phase 5: Testing + Launch (Week 0.5-1)
- Cross-version testing (15, 26)
- Accessibility audit (VoiceOver, keyboard)
- Performance optimization
- App icon + marketing
- Code signing + notarization
- App Store submission

**Total:** 5-6 weeks

---

## macOS 26 Tahoe Specific Considerations

### Liquid Glass Materials (Already Used)
```swift
.ultraThinMaterial  // Badges, buttons, tags
.thinMaterial      // Selected rows, inputs
.regularMaterial   // Headers, panels
.thickMaterial     // Modal backgrounds
.ultraThickMaterial // Overlays
```

### New Tahoe APIs to Evaluate
- **Spatial Layout:** 3D capabilities (may not need for 2D app)
- **Window Tiling:** Enhanced window management (relevant for multi-panel)
- **StoreKit:** Custom subscription styles (future monetization)

### Known Tahoe Issues to Monitor
- SwiftUI performance regressions (carryover from Sequoia)
- SwiftData + SwiftUI view binding issues
- Report via Feedback Assistant immediately

**Sources:**
- [Apple - macOS Tahoe 26](https://www.apple.com/os/macos/)
- [Apple Developer - macOS 15 Release Notes](https://developer.apple.com/documentation/macos-release-notes/macos-15-release-notes)
- [Apple Developer Forums - SwiftUI](https://developer.apple.com/forums/topics/ui-frameworks-topic/ui-frameworks-topic-swiftui)

---

## Success Metrics

From PRD, tracking should measure:

### User Engagement
- 70%+ daily active usage
- 80%+ tasks via global shortcut
- 40%+ use AI 3x/week
- 2-3 custom AI modes/user

### Technical
- <50MB memory footprint
- <5% CPU idle
- <100ms UI response
- <200ms global shortcut display
- 2-3s AI enhancement

### Business
- 4.5+ star App Store rating
- <5% AI config issues
- Zero data loss incidents

---

## Unresolved Questions

1. **z.ai SDK:** No official Swift SDK exists. Build custom REST client or wait?
   - Recommendation: Build URLSession client (simple HTTP POST)

2. **App Store Distribution:** Sandbox constraints on global shortcuts?
   - Recommendation: KeyboardShortcuts package is App Store approved

3. **Tahoe Beta Testing:** Should we join beta program or wait for GM?
   - Recommendation: Wait for GM unless critical Tahoe-only features needed

4. **iCloud Sync:** PRD says "initial version stores locally" but mentions future sync
   - Recommendation: Build with CloudKit from start if sync is on roadmap

---

## Next Steps

1. **Create Implementation Plan** → Run `/plan` with this brainstorm context
2. **Set up SwiftData models** → Task, AIMode, Settings
3. **Integrate KeyboardShortcuts** → Register CMD+Shift+N, CMD+Shift+T
4. **Build AI abstraction layer** → Protocol + Gemini + z.ai clients
5. **Implement Enhance Me panel** → Two-column diff view with mode switching

---

## Research Sources

### macOS 26 Tahoe
- [Apple - macOS Tahoe 26](https://www.apple.com/os/macos/)
- [Apple Newsroom - macOS Tahoe](https://www.apple.com.cn/newsroom/2025/06/macos-tahoe-26-makes-the-mac-more-capable-and-productive-than-ever/)
- [Wikipedia - macOS Tahoe](https://en.wikipedia.org/wiki/MacOS_Tahoe)
- [MacRumors - macOS 26 Tahoe](https://www.macrumors.com/roundup/macos-26/)

### Data Layer Performance
- [SwiftData vs Core Data 2025](https://commitstudiogs.medium.com/swiftdata-vs-core-data-which-should-you-use-in-2025-61b3f3a1abb1)
- [Core Data vs SwiftData 2025](https://distantjob.com/blog/core-data-vs-swift-data/)
- [Key Considerations Before Using SwiftData](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/)
- [GRDB Performance Wiki](https://github.com/groue/GRDB.swift/wiki/Performance)
- [Core Data vs GRDB vs SwiftData - Reddit](https://www.reddit.com/r/iOSProgramming/comments/1n4jz6h/core_data_vs_grdb_vs_swift_data/)

### SwiftUI Issues
- [Hacker News - SwiftUI Performance Regressions](https://news.ycombinator.com/item?id=41139144)
- [Reddit - Apps Unusable After Sequoia Update](https://www.reddit.com/r/iOSProgramming/comments/1g5c4ut/app_unusable_after_updating_to_sequoia_os_and/)
- [Apple Developer Forums - Beta Problems](https://developer.apple.com/forums/thread/756679)

### Global Shortcuts
- [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
- [Global Hotkeys in SwiftUI - YouTube](https://www.youtube.com/watch?v=ZVdbRjY2GN4)
- [How to Add Global Shortcuts - Tutorial](https://tnvmadhav.me/guides/how-to-add-global-keyboard-shortcuts-to-macos-apps-swiftui/)
- [Creating Spotlight-like Panel](https://whid.eu/2022/06/03/chapter-6-creating-a-spotlight-like-floating-panel-in-swift/)

### AI Integration
- [Integrating Google Gemini AI with Swift](https://www.appcoda.com/swiftui-google-gemini-ai/)
- [Implement Gemini AI SDK with SwiftUI](https://www.swiftanytime.com/blog/implement-gemini-ai-sdk-with-swiftui)
- [Build AI App with SwiftUI and Gemini - YouTube](https://www.youtube.com/watch?v=6Ibvt5W5FbA)
- [Z.ai API Quick Start](https://docs.z.ai/guides/overview/quick-start)
- [Z.ai API Introduction](https://docs.z.ai/api-reference/introduction)
- [Z.ai HTTP API Guide](https://docs.z.ai/guides/develop/http/introduction)
- [Integrate Z.ai GLM 4.6 Guide](https://zoer.ai/posts/zoer/integrate-z-ai-glm-4-6-api-guide)

### SwiftUI What's New
- [Apple Developer - SwiftUI What's New](https://developer.apple.com/swiftui/whats-new/)

---

*Report generated by brainstorm skill*
*Sacrificing grammar for concision*
