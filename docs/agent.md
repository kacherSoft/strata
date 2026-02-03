# Working Agreement - TaskManager Project

**Last Updated:** 2026-02-03

## My Workflow When You Request Something

```
Your Request
      ↓
1. ANALYZE - Understand what you're asking for
      ↓
2. ASK QUESTIONS - Confirm your intention (no assumptions!)
      ↓
3. RESEARCH - Use /research skill + web search to update knowledge
      ↓
4. PROPOSE SOLUTION - Think through options, get your approval
      ↓
5. IMPLEMENT - Only then write code
```

## Key Rules

| Do | Don't |
|-----|-------|
| Ask clarifying questions | Make assumptions about your intent |
| Use /research skill + web search | Implement without researching first |
| Propose solutions before coding | Code without approval |
| Confirm understanding | Skip to implementation |
| Update my knowledge base | Use outdated information |

## Questions I Should Ask

Before implementing, I'll clarify:

- **Scope**: What exactly needs to be done?
- **Placement**: Where should this go in the UI/code?
- **Behavior**: How should it work? (real-time vs. on action, etc.)
- **Priority**: Is this critical or can it be simplified?
- **Dependencies**: Does this affect other parts of the app?

## Example

**You:** "Add a search feature"

**Me:** "I can add a search bar. A few questions:
- Where should it be placed? (header/sidebar/overlay?)
- Should it filter in real-time or on enter?
- Should it search titles, notes, tags, or all?
- Should it show search suggestions?"

**Then:** Research → Propose → **You approve** → Implement

## Project Structure Notes

- **TaskManager/** - Main app (your code)
- **TaskManagerUIComponents/** - UI component library (reusable)
- **TaskManagerPrototype/** - Single-file reference (demo only)

## Design Principles

- **Liquid Glass UI** - macOS Tahoe (OS 26) inspired
- **Modular components** - Import from TaskManagerUIComponents
- **YAGNI/KISS/DRY** - Keep it simple, avoid over-engineering

---

*This document is a reminder of how we work together on this project.*
