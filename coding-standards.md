# Coding Standards

## General
- Prefer **Clean Architecture**: Domain, Application, Infrastructure, API projects.
- Small, cohesive classes. Keep functions ≤ 40 lines where practical.
- Nullability enabled (`<Nullable>enable</Nullable>`). Avoid `!` null-forgiving unless justified.

## C# / .NET
- **Naming:** `PascalCase` for public members/types; `camelCase` for locals/params; `_camelCase` for private fields.
- **Async:** suffix with `Async`; never `async void` (except event handlers).
- **DI:** constructor injection; avoid service locator. Prefer **interfaces** on external boundaries (providers).
- **Logging:** use `ILogger<T>` with structured logs (`LogInformation("Confirmed {AppointmentId}", id)`).
- **Validation:** FluentValidation for request DTOs; return RFC7807 `ProblemDetails` on errors.
- **Mapping:** Use explicit/manual mapping. Keep mapping code close to DTOs; consider factory/extension methods for reuse. Avoid runtime mapping libraries.
- **Data access:** EF Core, `AsNoTracking` for queries; cancellation tokens everywhere.
- **Date/Time:** store UTC; convert only at UI boundary.
- **Transactions:** use `IDbContextTransaction` for multi-entity writes; keep short.
- **Idempotency:** key mutation endpoints (confirm, cancel) with idempotency keys/holdId.

## React / TypeScript
- **Components:** function components + hooks; colocate component + styles; keep components focused.
- **State:** React Query for server state; Redux for global app state (auth, tenant).
- **Types:** avoid `any`; use `unknown` + narrowing.
- **Styling:** Tailwind; design tokens; avoid ad‑hoc inline styles.
- **Accessibility:** labels for inputs, keyboard nav, aria attributes for dialogs.
- **Testing:** RTL + Playwright for E2E.

## Git / Repo
- Conventional commits (`feat:`, `fix:`, `docs:`).
- PRs must include tests for new logic and updated docs where relevant.
