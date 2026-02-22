# Phase 0: Branch & Entitlements Setup

## Context Links
- Parent: [plan.md](plan.md)

## Overview
| Property | Value |
|----------|-------|
| Priority | P1 |
| Status | Pending |
| Effort | 0.5h |

Create a separate branch for the direct-distribution (non-App Store) version and modify entitlements.

## Requirements

### Functional
- Create `feature/inline-enhance-system-wide` branch from `main`
- Disable App Sandbox in entitlements
- Keep network and file access entitlements

### Non-Functional
- App Store version on `main` remains unaffected
- Build still compiles successfully

## Implementation Steps

### 1. Create Branch

```bash
cd /Volumes/OCW-2TB/LocalProjects/TaskManager
git checkout -b feature/inline-enhance-system-wide
```

### 2. Modify Entitlements

**File:** `TaskManager/Sources/TaskManager/TaskManager.entitlements`

```diff
 <dict>
     <key>com.apple.security.app-sandbox</key>
-    <true/>
+    <false/>
     <key>com.apple.security.network.client</key>
     <true/>
     <key>com.apple.security.files.user-selected.read-write</key>
     <true/>
 </dict>
```

### 3. Verify Build

```bash
cd /Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager
swift build
```

## Todo List

- [ ] Create branch `feature/inline-enhance-system-wide`
- [ ] Disable App Sandbox in entitlements
- [ ] Verify build compiles

## Success Criteria

- [ ] Branch exists and is checked out
- [ ] Entitlements have `app-sandbox = false`
- [ ] Build succeeds without errors

## Next Steps

After completion, proceed to [Phase 1: AccessibilityManager](phase-01-accessibility-manager.md)
