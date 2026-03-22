# Phase 5: Build & Test

**Priority:** High | **Status:** Complete
**Depends on:** Phases 1-4

## Overview

Build debug, verify compilation, manual test in app.

## Steps

1. Run `cd TaskManager && ./scripts/build-debug.sh`
2. Fix any compile errors
3. Launch app, go to Settings → AI Providers
4. Verify custom provider section appears with 3 fields
5. Test save/remove/test connection flow
6. Create an AI mode using custom provider, verify text enhancement works

## Todo

- [ ] Build compiles with zero errors
- [ ] Custom provider section visible in Settings
- [ ] Save/Remove/Test buttons work
- [ ] Enhancement via custom provider returns result
- [ ] Existing Gemini/z.ai still work (no regression)
