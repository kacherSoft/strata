# TaskManager — Feature Status

_Last updated: 2026-02-23_

## Implementation Status

All currently scoped product features are implemented and considered **DONE**.

---

## Feature Tiers

### 🆓 Free Tier

| Category | Feature | Notes |
|---|---|---|
| **Task Management** | Task CRUD (title, description, status) | Todo/In Progress/Completed |
| | Tags | Tag-based organization & filtering |
| | Priorities | None → Critical levels |
| | Due dates & reminders | With alarm handling |
| | Photo attachments | Stored in Application Support |
| | Search & filtering | Full-text search |
| | Data import/export | Backup & restore |
| **Views** | List view | Default view with sorting |
| | Calendar view | Monthly calendar with task indicators |
| **AI** | Built-in AI modes | Correct Me, Enhance Prompt, Explain |
| | Custom AI modes (basic) | Create modes with custom prompts |
| | Enhance Me panel | Floating window via global shortcut |
| **Shortcuts** | Quick Entry | Global shortcut for task capture |
| | Enhance Me | Global shortcut for AI panel |
| | Main Window | Global shortcut toggle |
| **Data** | Local storage | All data on device |
| | SwiftData persistence | Modern SwiftData models |

### ⭐ Premium Tier (Pro Subscription or VIP Lifetime)

| Category | Feature | Notes |
|---|---|---|
| **Views** | Kanban board | Drag-and-drop workflow view |
| **Task Management** | Recurring tasks | Daily/weekly/monthly/yearly/weekdays + intervals |
| | Custom fields | Text, number, currency, date, toggle |
| | Budget/client/effort | Extended task metadata |
| **AI** | AI attachments | Image/PDF support in AI modes |
| | Attachments in custom modes | Enable attachments for user-created modes |

---

## Product Tiers Summary

| Tier | Price | What You Get |
|---|---|---|
| **Free** | $0 | Full task management, list + calendar views, basic AI modes, local storage |
| **Pro** | $4.99/mo or $39.99/yr | Everything in Free + Kanban, recurring tasks, custom fields, AI attachments |
| **VIP** | $79.99 (one-time) | Same as Pro, lifetime access |

### Entitlement Gating

All premium features use unified `hasFullAccess` check:
- `isPremium` (active Pro subscription) **OR**
- `isVIPPurchased` (lifetime purchase) **OR**
- `isVIPAdminGranted` (debug override)

---

## Global Shortcuts

| Shortcut | Action | Customizable |
|---|---|---|
| Quick Entry | Capture task from anywhere | ✅ Yes |
| Enhance Me | Open AI enhancement panel | ✅ Yes |
| Main Window | Toggle main app window | ✅ Yes |
| ⌘N | New task in app | ❌ Fixed |
| ⌘, | Open settings | ❌ Fixed |

---

## AI Features Detail

| Feature | Free | Premium | Notes |
|---|---|---|---|
| Built-in modes (Correct Me, Enhance Prompt, Explain) | ✅ | ✅ | Core AI enhancement |
| Custom AI modes | ✅ | ✅ | Create your own modes |
| Enhance Me panel | ✅ | ✅ | Floating AI window |
| AI attachments (image/PDF) | ❌ | ✅ | Requires premium |

---

## Architecture Notes

- **UI Framework**: SwiftUI with native macOS design
- **Data Layer**: SwiftData with model containers
- **AI Integration**: Protocol-based provider system (Gemini, z.ai)
- **Shortcuts**: System-wide keyboard shortcuts via Carbon API

---

## Distribution

| Branch | Sandbox | Inline Enhance | Distribution |
|---|---|---|---|
| `main` | ✅ Enabled | ❌ Not available | App Store |
| `developer-id` | ❌ Disabled | ✅ Available | Developer ID |

---

## Technical Implementation

### Entitlements & Billing

| Feature | Status | Notes |
|---|---|---|
| Unified access gate | ✅ Done | `hasFullAccess` property |
| Pro subscription | ✅ Done | Monthly/yearly via StoreKit 2 |
| VIP lifetime | ✅ Done | One-time purchase |
| Restore purchases | ✅ Done | Full restore flow |
| Debug VIP grant | ✅ Done | `#if DEBUG` admin override |

### Settings & Configuration

| Feature | Status | Notes |
|---|---|---|
| AI settings | ✅ Done | Provider, model, mode management |
| General settings | ✅ Done | Appearance, window behavior |
| Shortcut customization | ✅ Done | All global shortcuts configurable |
| Custom field management | ✅ Done | Create/edit/delete fields |


### Data Persistence

| Feature | Status | Notes |
|---|---|---|
| SwiftData models | ✅ Done | Modern SwiftData persistence |
| Local storage | ✅ Done | All data stored locally on device |
| Photo storage | ✅ Done | Application Support directory |
