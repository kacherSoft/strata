# AI Implementation Architecture Report

## Overview

This report documents all AI-related implementation files in the TaskManager codebase, focusing on the Inline Enhance feature, AI providers, and technical architecture.

## 1. Core AI Infrastructure Files

### AI Directory Structure
- `/TaskManager/Sources/TaskManager/AI/Models/AIEnhancementResult.swift` - Data models for AI operations
- `/TaskManager/Sources/TaskManager/AI/Protocols/AIProvider.swift` - Protocol interface for AI providers
- `/TaskManager/Sources/TaskManager/AI/Services/AIService.swift` - Main AI service orchestration
- `/TaskManager/Sources/TaskManager/AI/Services/KeychainService.swift` - API key storage
- `/TaskManager/Sources/TaskManager/AI/Providers/GeminiProvider.swift` - Google Gemini implementation
- `/TaskManager/Sources/TaskManager/AI/Providers/ZAIProvider.swift` - z.ai implementation

### Key Classes and Structs

#### AIEnhancementResult.swift
- `AIAttachment` - Represents file attachments (images, PDFs) with 10MB limit
- `AIEnhancementResult` - Result container for AI operations with metrics
- `AIModeData` - Runtime data for AI modes including prompts and model selection

#### AIProvider.swift
- `AIProviderProtocol` - Interface for all AI providers
- `AIError` - Enum of error types (network, auth, rate limiting, etc.)

#### AIService.swift
- Singleton class managing AI provider selection and mode cycling
- Handles persistence of selected AI modes via SwiftData
- Key methods:
  - `enhance(text:attachments:mode:)` - Main enhancement workflow
  - `cycleMode(in:)` - Cycles through configured AI modes
  - `providerFor(_:)` - Returns appropriate provider instance

## 2. Inline Enhance Feature

### Core Files
- `/TaskManager/Sources/TaskManager/Services/InlineEnhanceCoordinator.swift` - Main orchestration
- `/TaskManager/Sources/TaskManager/Services/TextCaptureEngine.swift` - Text capture via Accessibility API
- `/TaskManager/Sources/TaskManager/Services/TextReplacementEngine.swift` - Text replacement strategies
- `/TaskManager/Sources/TaskManager/Windows/InlineEnhanceHUDPanel.swift` - HUD panel container
- `/TaskManager/Sources/TaskManager/Views/InlineEnhanceHUD.swift` - HUD visual components

### Architecture Flow

1. **Entry Point** - `InlineEnhanceCoordinator.performInlineEnhance()`
2. **Permission Check** - Verifies Accessibility API access
3. **Text Capture** - Uses `TextCaptureEngine` with 5-layer strategy:
   - Layer 1: Direct selection/value reading
   - Layer 2: Parent element traversal
   - Layer 3: Child descent for containers
   - Layer 4: Web content range extraction
   - Layer 5: Clipboard fallback with restore
4. **AI Enhancement** - Calls `AIService.enhance()` with captured text
5. **Text Replacement** - Uses `TextReplacementEngine` with 3 strategies:
   - Direct value set
   - Selection replacement
   - Clipboard paste with restore
6. **HUD Display** - Shows progress/results via `InlineEnhanceHUD`

### Text Capture Engine Features
- App category detection (native, browser, electron, webview)
- Browser-specific accessibility enhancement
- Secure field detection and bypass
- Selection range preservation
- Clipboard backup/restore

### Text Replacement Engine Features
- Focus validation to prevent data loss
- Multiple replacement strategies
- Verification mechanisms
- Browser-specific handling (Arc Browser support)

## 3. AI Providers

### Gemini Provider (`GeminiProvider.swift`)
- Uses GoogleGenerativeAI SDK
- Supports image and PDF attachments
- Models: gemini-flash-lite-latest (default), gemini-flash-latest, gemini-3-flash-preview
- Error mapping for safety filters and rate limits
- PDF text extraction (20 pages max, 50K chars)

### ZAI Provider (`ZAIProvider.swift`)
- Custom HTTP client for z.ai API
- Uses GLM-4.6/GLM-4.7 models
- Supports text only (no attachments)
- HTTP connection testing
- Token usage tracking

## 4. AI Modes and Configuration

### Data Models
- `/TaskManager/Sources/TaskManager/Data/Models/AIModeModel.swift` - AI mode definitions
- `/TaskManager/Sources/TaskManager/Data/Models/SettingsModel.swift` - AI provider settings

### Built-in AI Modes
1. **Correct Me** - Grammar/spelling correction
2. **Enhance Prompt** - Text expansion and detail addition
3. **Explain** - Analysis and explanation (supports attachments)

### Custom Modes
- User can create custom AI modes
- Customizable system prompts
- Provider and model selection
- Attachment support flags

## 5. Keychain Service (BYOK)

### KeychainService.swift
- Stores API keys for Gemini and z.ai
- Uses macOS Security framework
- Service identifier: "com.taskflowpro.api-keys"
- Key operations: save, get, delete, hasKey

## 6. Accessibility Integration

### AccessibilityManager.swift
- Checks for Accessibility API permission
- Handles permission requests
- Monitors permission changes

### Electron Specialist
- Special handling for Electron apps
- Ensures accessibility flags are set
- Webview detection and enhancement

## 7. HUD Interface

### Visual Design
- Glassmorphism design with dark theme
- Animated shimmer effect during processing
- Bright lime-to-neon green gradient
- Strata brand icon
- Auto-dismiss after completion

### States
- Enhancing (with animated dots)
- Success (checkmark)
- Error (exclamation with message)

## 8. Global Shortcuts

### ShortcutManager.swift
- `⌘⇧E` - Inline Enhance Me (global)
- `⌘⇧N` - Quick Entry
- `⌘⇧T` - Main Window
- `⌘⌥E` - Enhance Me (panel mode)

## 9. Technical Architecture Patterns

### Singleton Pattern
- AIService.shared
- InlineEnhanceCoordinator.shared
- TextCaptureEngine.shared
- TextReplacementEngine.shared

### Observer Pattern
- @MainActor @Observable classes
- Published properties for UI updates

### Protocol-Oriented Design
- AIProviderProtocol for provider abstraction
- Multiple strategy patterns for capture/replace

### Error Handling
- Comprehensive error types in AIError
- Graceful fallbacks for failed operations
- User-friendly error messages

## 10. Performance Optimizations

### Concurrency
- Async/await throughout
- Task cancellation support
- Detached tasks for file processing
- MainActor isolation for UI updates

### Memory Management
- Clipboard snapshots with restore
- Proper cleanup of tasks and observers
- Efficient text processing limits

## Security Considerations

### Keychain Storage
- API keys encrypted in macOS keychain
- No plaintext storage in configuration files

### Accessibility Permissions
- System-level permission requirement
- Graceful degradation when disabled
- Clear user prompts for permission

### App Isolation
- PID-based focus validation
- Element-level permission checking
- Secure field detection

## 11. Integration Points

### Subscription Service
- Checks SubscriptionService.hasFullAccess
- Pro mode required for AI features

### Electron Apps
- Special handling via ElectronSpecialist
- Enhanced accessibility flags
- Webview detection and processing

### Browser Integration
- Browser-specific accessibility bootstrap
- Arc Browser special handling
- Web content range extraction

## Summary

The TaskManager AI implementation demonstrates a sophisticated system with:
- Multi-provider AI support
- Robust text capture/replacement engines
- Beautiful, animated HUD interface
- Comprehensive error handling
- Security-focused design
- Extensible AI mode system
- Global shortcut integration

The architecture follows modern Swift patterns with proper isolation, concurrency, and user experience considerations.
