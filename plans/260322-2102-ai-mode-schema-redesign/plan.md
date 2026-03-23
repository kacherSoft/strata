# AI Mode Schema Redesign

## Goal
Simplify AI Modes: 2 built-ins only (Correct Me + Chat), add viewType and autoCopyOutput fields, remove supportsAttachments, lock system prompt for built-ins.

---

## Schema Changes (V3 → V4)

### AIModeModel — Add fields:
```
+ viewTypeRaw: String     // "enhance" | "chat" (default: "enhance")
+ autoCopyOutput: Bool     // default: false, only used in enhance view
```

### AIModeModel — Remove field:
```
- supportsAttachments: Bool  // No longer needed
```

### Computed property:
```swift
enum AIModeViewType: String { case enhance, chat }
var viewType: AIModeViewType  // backed by viewTypeRaw
```

### Migration V3 → V4 (lightweight):
- `viewTypeRaw`: nullable String, default nil → computed property falls back to "enhance"
- `autoCopyOutput`: Bool with default false
- `supportsAttachments`: keep in schema but ignore (SwiftData lightweight migration can't drop columns)

---

## Built-in Modes (reduced to 2)

| Mode | viewType | autoCopy | System Prompt | Editable |
|---|---|---|---|---|
| Correct Me | enhance | true | Grammar/spelling fix | Model only |
| Chat | chat | false | Conversational assistant | Model only |

### Removed built-ins (become deletable):
- Enhance Prompt → mark `isBuiltIn = false` on migration
- Explain → mark `isBuiltIn = false` on migration

User keeps them as custom modes they can edit or delete.

---

## Files to Modify

### Phase 1: Data Layer

**`AIModeModel.swift`**
- Add `viewTypeRaw: String` property (default "enhance")
- Add `autoCopyOutput: Bool` property (default false)
- Add `AIModeViewType` enum + computed `viewType` property
- Update `createDefaultModes()` → only 2 modes (Correct Me + Chat)
- Set Chat's viewTypeRaw = "chat", Correct Me's autoCopyOutput = true

**`SchemaVersioning.swift`**
- Add V4 schema with new fields
- Lightweight migration plan V3 → V4

**`ModelContainer+Config.swift`**
- Update `seedDefaultAIModes()` → 2 modes only
- Add `demoteDeprecatedBuiltIns()` → set isBuiltIn=false for "Enhance Prompt" and "Explain"
- Add `migrateViewTypeForExistingModes()`:
  - Chat mode → viewTypeRaw = "chat"
  - All others → viewTypeRaw = "enhance" (if nil)
  - Correct Me → autoCopyOutput = true
- Remove `seedExplainModeIfNeeded()` (no longer built-in)

### Phase 2: Settings UI

**`AIModesSettingsView.swift`**
- Mode editor form changes:
  - Add viewType picker (Enhance / Chat)
  - Add autoCopyOutput toggle (only shown when viewType == enhance)
  - Remove supportsAttachments toggle
  - System prompt: show but disable editing for isBuiltIn modes
  - Name: disable for isBuiltIn
- List row: show view type indicator (icon or label)

### Phase 3: View Integration

**`EnhanceMeView.swift`**
- Remove `supportsAttachments` checks → enhance view = text only
- Remove attachment bar, drop handler, paste handler for attachments
- Add auto-copy logic: if `mode.autoCopyOutput`, copy result to clipboard after enhancement completes
- Mode cycling: only cycle through modes where viewType == .enhance

**`ChatView.swift`**
- Remove `currentModeSupportsAttachments` computed property
- Chat view always supports attachments (provider permitting)
- Mode resolution: filter for viewType == .chat (if multiple chat modes exist)

**`ChatInputView.swift`**
- Remove `supportsAttachments` parameter
- Always show attachment button (chat view inherently supports it)

### Phase 4: Cleanup

- Remove `supportsAttachments` references from all files
- Remove `seedExplainModeIfNeeded()` from ModelContainer+Config
- Remove `seedChatModeIfNeeded()` duplicate logic (handled by migration)
- Update `removeDeprecatedBuiltInModesIfNeeded()` to also handle Enhance Prompt / Explain demotion

---

## Migration Strategy (Existing Users)

1. App launches → V4 schema migration (lightweight, additive)
2. `demoteDeprecatedBuiltIns()` runs:
   - "Enhance Prompt" → isBuiltIn = false (user can now edit/delete)
   - "Explain" → isBuiltIn = false
3. `migrateViewTypeForExistingModes()` runs:
   - "Chat" → viewTypeRaw = "chat"
   - All others → viewTypeRaw = "enhance"
   - "Correct Me" → autoCopyOutput = true
4. If "Chat" mode missing → seed it
5. If "Correct Me" mode missing → seed it

### Fresh Install:
- `createDefaultModes()` creates only 2 modes
- No migration needed

---

## Success Criteria

- [ ] Only 2 built-in modes (Correct Me, Chat)
- [ ] Built-in modes: model editable, name + system prompt read-only
- [ ] Custom modes: fully editable (name, prompt, model, viewType, autoCopy)
- [ ] ViewType picker in mode editor (Enhance / Chat)
- [ ] AutoCopyOutput toggle in mode editor (enhance only)
- [ ] Enhance view: text-only, no attachments, auto-copy when enabled
- [ ] Chat view: always supports attachments
- [ ] Existing "Enhance Prompt" and "Explain" modes demoted to custom (not deleted)
- [ ] Mode cycling in enhance view skips chat modes
- [ ] Builds and compiles without errors
