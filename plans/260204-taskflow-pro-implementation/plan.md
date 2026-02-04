---
title: "TaskFlow Pro - Complete Implementation"
description: "Build complete macOS 26 task management app with AI enhancement, liquid glass UI, and global shortcuts"
status: pending
priority: P1
effort: 5-6w
issue: null
branch: main
tags: [macos, swiftui, swiftdata, ai, gemini, liquid-glass]
created: 2026-02-04
---

# TaskFlow Pro - Implementation Plan

## Overview

Complete implementation of TaskFlow Pro - native macOS 26 Tahoe task management app with:
- **AI Enhancement:** Gemini SDK + z.ai REST (user-specified, NOT OpenAI/Anthropic)
- **Liquid Glass UI:** macOS 26 Tahoe visual language
- **Global Shortcuts:** KeyboardShortcuts package
- **Data Layer:** SwiftData (local-only, CloudKit deferred to v2)

**Timeline:** 5-6 weeks solo developer
**Risk Tolerance:** Aggressive (cutting edge, file bugs as they arise)

## Tech Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| UI Framework | SwiftUI | Native Tahoe integration |
| Data Layer | SwiftData | 60% less code, Tahoe-ready |
| Shortcuts | KeyboardShortcuts pkg | Proven, App Store safe |
| AI Providers | Gemini SDK + z.ai REST | User requirement |
| Security | Keychain Services | API key storage |

## Phases

| # | Phase | Status | Effort | Link |
|---|-------|--------|--------|------|
| 1 | Foundation & Data Layer | Pending | 1.5w | [phase-01](./phase-01-foundation.md) |
| 2 | Global Shortcuts & Quick Entry | Pending | 1w | [phase-02](./phase-02-shortcuts.md) |
| 3 | AI Integration | Pending | 1.5w | [phase-03](./phase-03-ai-integration.md) |
| 4 | Polish & Advanced Features | Pending | 1w | [phase-04](./phase-04-polish.md) |
| 5 | Testing & Launch | Pending | 0.5-1w | [phase-05](./phase-05-launch.md) |

## Existing Codebase

**TaskManagerUIComponents/** (24 components ready to use):
- Views: TaskRow, TaskListView, SidebarView, DetailPanelView
- Inputs: SearchBar, PriorityPicker, TextareaField
- Display: TagCloud, TagChip, PriorityIndicator, EmptyStateView
- Sheets: NewTaskSheet, EditTaskSheet
- Buttons: ActionButton, PrimaryButton, FloatingActionButton

**TaskManager/** (app shell):
- TaskManagerApp.swift with NavigationSplitView
- Empty Data/ and Windows/ folders ready for implementation

## Dependencies

- [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Global shortcuts
- [GoogleGenerativeAI](https://github.com/google/generative-ai-swift) - Gemini SDK
- macOS 26 Tahoe SDK

## Key Decisions

1. **SwiftData over Core Data** - 60% less boilerplate, accepts Tahoe bugs
2. **Local-only storage** - CloudKit deferred to v2
3. **Gemini + z.ai** - NOT OpenAI/Anthropic per user requirement
4. **KeyboardShortcuts pkg** - Battle-tested, App Store approved

## Success Metrics

- <200ms global shortcut display
- <50MB memory footprint
- <5% CPU idle
- 2-3s AI enhancement response
- Zero data loss incidents

## Research Sources

See: [brainstorm-260204-0942-taskflow-pro-implementation.md](../reports/brainstorm-260204-0942-taskflow-pro-implementation.md)
