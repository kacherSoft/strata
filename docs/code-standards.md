# Code Standards

_Last updated: 2026-03-10_

Coding conventions for the Strata codebase. These reflect existing patterns — not aspirational.

---

## File Organization

- **File naming**: kebab-case with descriptive names (e.g., `entitlement-backend-client.swift`, `scheduled-cleanup.ts`)
- **Max 200 LOC per file** — split at logical boundaries (service, view, helper)
- Swift: group by layer (`Data/`, `Services/`, `Views/`, `Windows/`, `AI/`, `Shortcuts/`)
- TypeScript: flat `src/` with `routes/` subdirectory for route handlers

---

## Swift Standards

### @Model Classes
- Properties use value types (`String`, `UUID`, `Date`, `Bool`, `Int`) for persistence compatibility
- Relationships annotated with `@Relationship(deleteRule: .cascade)`
- Always include `id: UUID = UUID()`, `createdAt: Date = Date()`, `updatedAt: Date`
- Call `touch()` helper (updates `updatedAt`) when mutating

### Repository Pattern
```swift
@MainActor
final class TaskRepository: ObservableObject {
    private let modelContext: ModelContext
    init(modelContext: ModelContext) { ... }
    func fetchAll(filter:sortOrder:searchText:) throws -> [TaskModel]
    func create(title:...) -> TaskModel
    func update(_ task: TaskModel)
    func delete(_ task: TaskModel)
    private func saveContext() { /* swallows + logs error */ }
}
```
- Repositories are `@MainActor final class` with `ObservableObject`
- `saveContext()` catches and logs — never throws to callers from mutation methods
- `fetch*` methods throw — let callers handle SwiftData errors

### Service Layer
- Services are `final class` (not @Model, not @MainActor unless UI state)
- Use `async throws` for I/O operations
- Dependency inject `ModelContext` or environment objects via init

### View Composition
- Extract subviews when a view body exceeds ~50 lines
- Use `@ViewBuilder` for conditional content helpers
- Pass only the data a subview needs — avoid passing parent `@State` objects down
- Use `PreferenceKey` for child→parent communication

### Error Handling
```swift
do {
    try someOperation()
} catch let error as SomeTypedError {
    // handle typed case
} catch {
    // fallback
}
```
- No `try!` or `try?` in production paths (except well-understood nil-returning cases)

---

## TypeScript Standards

### AppError Pattern
```typescript
throw new AppError(statusCode: number, errorCode: string, message: string)
// e.g.
throw new AppError(400, "INVALID_INSTALL_ID", "install_id must be a valid UUID")
```
- All user-facing errors go through `AppError`
- `handleError()` in the catch block converts to JSON response
- Never leak internal error messages to responses

### Route Handler Structure
```typescript
export async function handleXxx(request: Request, env: Env, ctx?: ExecutionContext): Promise<Response> {
    const requestId = generateRequestId();
    try {
        // 1. Rate limit check
        // 2. Parse + validate body (requireUUID, requireEmail, requireNonEmptyString)
        // 3. Auth check (requireAuthSession)
        // 4. Business logic
        // 5. Return JSON response
    } catch (error) {
        return handleError(error, requestId);
    }
}
```
- Rate limit before auth check (fail fast)
- Auth before business logic
- Always return structured JSON (never raw strings)

### Validation Helpers (`validation.ts`)
```typescript
requireUUID(value, fieldName, errorCode)   // validates UUID format
requireEmail(value)                        // validates + normalizes email
requireNonEmptyString(value, code, msg)    // rejects empty/whitespace
sanitizeNickname(value)                    // strips control chars, max 100
```
- Use these for all request body fields — never inline validation

### D1 Query Patterns
```typescript
// Prepared statements — always
await env.STRATA_DB.prepare("SELECT ... WHERE id = ?").bind(id).first<Row>();
await env.STRATA_DB.prepare("INSERT ...").bind(a, b).run();

// Batch API for multiple statements
await env.STRATA_DB.batch([stmt1, stmt2]);

// Best-effort (fire-and-forget) — add .catch(() => {})
await env.STRATA_DB.prepare("UPDATE ...").bind(x).run().catch(() => {});
```
- Never string-interpolate SQL — always use `?` placeholders
- `.first<T>()` returns `T | null` — handle null explicitly

### Typing
- Prefer explicit `interface` over `type` for object shapes
- Input types go in `types.ts`; route handlers import from there
- Avoid `any` — use `unknown` and narrow with type guards

---

## Testing

### Backend (Vitest)
```typescript
import { env } from "cloudflare:test";
describe("route", () => {
    it("returns 400 for invalid input", async () => {
        const res = await handler(new Request(...), env);
        expect(res.status).toBe(400);
        const body = await res.json();
        expect(body.error_code).toBe("EXPECTED_CODE");
    });
});
```
- Use `cloudflare:test` env binding — no manual mocking of D1
- Test error codes, not just status codes
- Cover: happy path, missing fields, invalid format, rate limit hit, auth failure

---

## Commit Messages

Follow Conventional Commits:
```
feat(scope): short description
fix(scope): what was fixed
chore: what was done
refactor(scope): what changed and why
docs: what was documented
```
- Scope: `app`, `backend`, `ui`, `auth`, `inline-enhance`, etc.
- Body optional — add when "why" isn't obvious from subject
