# Test Strategy — Phase 0

## Goals
- Prevent regressions in booking logic (availability, holds, confirm).
- Ensure admin calendar operations are conflict-safe.
- Verify notification mocks behave like real integrations would.

## Test Pyramid (targets)
- **Unit**: ~70% of total tests; **coverage ≥ 80%** for domain/services.
- **Integration**: critical flows; **coverage ≥ 60%** lines across API adapters, EF, Redis.
- **E2E**: happy paths + key edge paths; **5–10** core scenarios.

> Overall coverage (API + domain): **≥ 80%** statement coverage.
> Frontend unit/component coverage (WebPublic/WebAdmin): **≥ 70%**.

---

## Unit Tests (xUnit + FluentAssertions)
- **Availability service**
  - Working hours & exceptions; buffer enforcement; staff skill gating.
  - Slot grid alignment; overlapping appointments exclusion.
- **Hold service (Redis)**
  - Acquires lock for free slot; rejects existing; TTL expiration.
- **Booking service**
  - Confirm; state transitions; idempotency on holdId.
- **Notification composer (mock)**
  - Templates, payload fields.
- **Validation**
  - DTO validators (FluentValidation).

**Tooling:** xUnit, FluentAssertions, NSubstitute/Moq, Bogus for data.

---

## Integration Tests (WebApplicationFactory)
- **Public booking flow**: list → availability → hold → confirm.
- **Admin calendar**: create → conflicting create (409) → reschedule → cancel.
- **Notifications**: confirmation enqueues Notification; reminder marks as sent.

**Infra:** Testcontainers for SQL Server & Redis; Respawn to clean DB between tests.

---

## E2E Tests (Playwright)
- **Public happy path**: service→staff→time→contact→confirm; ICS link + mock SMS toast.
- **Conflict scenario**: two browsers try same slot; second sees error.
- **Admin calendar**: Google login (stub), create/move/cancel with visible updates.
- **Analytics**: seed few bookings, cancel one; dashboard reflects counts.

**Environment:** local dev services; seeded data fixture.

---

## Performance Tests (lightweight)
- K6 or Azure Load Testing targeting `/public/availability` @ 100 RPS for 5 min:
  - p95 ≤ 300 ms, error rate < 0.5%.
- Calendar load endpoint @ 30 RPS: p95 ≤ 1.5 s.

---

## Static Analysis & Linting
- **Backend:** .NET analyzers, Style via `.editorconfig`.
- **Frontend:** ESLint + Prettier; CI fails on lint errors.

---

## CI/CD Gates
- Build succeeds.
- Unit + Integration tests green.
- E2E smoke passes on staging.
- Coverage thresholds met (fail if below).
- Security scans: `dotnet list package --vulnerable` & `npm audit` (warn-only initially).

---

## Test Data & Seeding
- Minimal seed: 1 tenant, 1 branch, 3 services, 3 staff with skills, simple work pattern.
- Deterministic times (UTC) for repeatable assertions.

---

## Logging & Diagnostics in Tests
- Enable App Insights debug logging to console for diagnostics during CI (sampling off).
- Capture request/response bodies on failed assertions.

---

## Ownership
- Each PR must add/adjust tests for impacted modules.
- A failing test suite blocks merge.
