# PLAN.md — Phase 0 Implementation Plan

## scope recap (authoritative docs)
- Public booking (anonymous): availability, hold (TTL 120s default), confirm, cancel, mock phone verify, ICS download.
- Admin calendar: day/week with DnD, conflict checks; CRUD for services/staff/clients; settings; mock SMS outbox.
- Notifications: mocked SMS; reminders via hosted background services.
- Analytics: KPIs and CSV export.
- Out of scope: payments/deposits, email, gateway/Front Door, API Dockerization, Azure Functions.

## repo structure and naming
```
/src
  BookPoint.Domain/              # Entities, value objects, domain services
  BookPoint.Application/         # CQRS (MediatR), DTOs, validators, policies, interfaces
  BookPoint.Infrastructure/      # EF Core (SQL), Redis, Storage, providers, migrations
  BookPoint.Api/                 # ASP.NET Core 8 API (controllers, DI, auth, Swagger)
  BookPoint.WebPublic/           # React + Vite SPA (public booking)
  BookPoint.WebAdmin/            # React + Vite SPA (admin calendar)
/tests
  BookPoint.Tests.Unit/          # MSTest + FluentAssertions + Moq
  BookPoint.Tests.Integration/   # WebApplicationFactory + Testcontainers (SQL/Redis) + Respawn
  BookPoint.Tests.E2E/           # Playwright specs for key flows
```

## incremental plan (milestones)
- Foundations: solution, DI, config, logging, ProblemDetails, health; DB/Redis wiring; initial migrations; Swagger.
- Domain & Application: availability, holds (Redis), confirm/cancel, ICS.
- Public API: branches, services, staff, availability, hold/confirm/cancel, verify-phone (mock).
- Admin API: calendar range, appointments CRUD/PATCH, services/staff/clients CRUD, analytics KPIs/export, mock SMS send.
- Background services: reminders/housekeeping via IHostedService; mock sender/outbox flow.
- SPAs: Public wizard; Admin calendar + management + auth.
- Observability & perf: App Insights (events/metrics), dashboards, perf validation.
- CI/CD: GitHub Actions build/test/integration, slot deploy, smokes, swap.

## deliverable work items (≤2h each)
1) Solution scaffolding and CI build
   - AC: .sln + projects created; build succeeds in CI; basic health endpoint alive.
   - Tests: trivial smoke unit test; CI pipeline runs build/test jobs.

2) EF Core DbContext + initial migration
   - AC: Entities and DbContext defined; migration applied locally; ConnectionStrings via config.
   - Tests: Integration test spins SQL container and applies migration (no errors).

3) Redis adapter and hold lock service
   - AC: IHoldLockService with SET NX EX; configurable TTL; idempotent release.
   - Tests: Integration tests verify acquire/reject/expire behavior.

4) Availability computation service
   - AC: Generates slots from work patterns, skills, buffers; caches with short TTL.
   - Tests: Unit tests for grid alignment, overlaps, skills; cache hit path.

5) Public endpoints: availability + hold + confirm + cancel
   - AC: Controllers expose endpoints with ProblemDetails errors; Swagger shows contracts.
   - Tests: Integration tests cover happy path and conflict (409) on second hold/confirm.

6) Mock notifications + hosted reminders
   - AC: Mock sender persists to Notifications, logs events; reminder service flips to sent.
   - Tests: Integration test enqueues confirmation; background service processes to sent.

7) Admin calendar range + appointments PATCH
   - AC: Range query returns staff blocks; PATCH updates times with conflict check; optional If-Match.
   - Tests: Integration test for reschedule happy path and conflict.

8) Services/Staff/Clients CRUD (admin)
   - AC: CRUD endpoints with validation and RBAC policies.
   - Tests: Unit validator tests; integration CRUD roundtrip.

9) Analytics KPIs + CSV export
   - AC: KPIs endpoint computes basic metrics; export writes CSV to Blob and streams download.
   - Tests: Unit for KPI calc; integration generates CSV with expected headers.

10) WebPublic wizard (happy path)
   - AC: 5-step flow; ICS download; mock SMS toast; error on conflict.
   - Tests: Playwright happy + conflict scenarios.

11) WebAdmin basics: login + calendar DnD
   - AC: Google auth stub in dev; calendar view with create/move/cancel; role-gated routes.
   - Tests: Playwright admin create/move/cancel.

12) Observability & perf validation
   - AC: App Insights custom events (BookingHold, BookingConfirmed, SmsQueuedMock, SmsSentMock), dashboards; perf check meets targets.
   - Tests: Optional Azure Load Testing runbook; asserts p95 thresholds in report.

## rbac matrix (Phase 0)

Roles: Owner, Manager, Receptionist, Staff. All permissions are scoped to the tenant. In Phase 0, branch scoping is not enforced (can be added later).

Endpoint/Capability → Roles
- Calendar (GET /admin/calendar): Owner, Manager, Receptionist, Staff (Staff limited to own schedule).
- Appointments (POST /admin/appointments): Owner, Manager, Receptionist; Staff may create for self only (policy-enforced).
- Appointments (PATCH /admin/appointments/{id}): Owner, Manager, Receptionist; Staff can modify own appointments only.
- Clients (GET /admin/clients/search, CRUD): Owner, Manager, Receptionist (read/write); Staff read-only.
- Services (GET/POST /admin/services, PATCH /admin/services/{id}): Owner, Manager (read/write); Receptionist/Staff read-only.
- Staff (GET/POST /admin/staff, PATCH /admin/staff/{id}): Owner, Manager (read/write); Receptionist/Staff read-only.
- Analytics (GET /admin/analytics/kpis): Owner, Manager, Receptionist, Staff (read-only).
- Analytics Export (GET /admin/analytics/export): Owner, Manager.
- Mock SMS send (POST /mock/sms/send): Owner, Manager. Receptionist may trigger appointment-specific reminder if exposed via appointment action; Staff no.

Authorization implementation
- Role policies: CanManageCatalog (Owner, Manager), CanManageStaff (Owner, Manager), CanManageAppointments (Owner, Manager, Receptionist, Staff-limited), CanManageClients (Owner, Manager, Receptionist), CanViewAnalytics (all), CanExportAnalytics (Owner, Manager).
- Resource-level checks: StaffSelfOnly requirement/handler to restrict Staff to own appointments; Tenant requirement ensures data isolation.
- Controllers: decorate with [Authorize(Policy = "…")]; use resource-based authorization for self-only cases.

## assumptions, risks, questions
Assumptions
- Tenant context via header (e.g., X-Tenant-Id); EF global filter enforces TenantId.
- ICS delivered as file download from confirm response.
- Phone verification is mock-only and non-blocking.

Risks
- Double-booking under contention if Redis unavailable; mitigate with retries and clear errors.
- Complex work patterns; keep JSON simple in Phase 0; validate on save.
- Data model changes mid-implementation; keep migrations additive.

Decisions (resolved)
- Tenant header name: `X-Tenant-Id`.
- ETag for PATCH: deferred to Phase 1.
- CSV export: use local time zone/formatting.
- RBAC: see matrix above for role capabilities.

## tech choices & nfr confirmation
- Backend: ASP.NET Core 8 (Controllers), MediatR, EF Core, FluentValidation; manual mapping.
- Infra: Azure SQL (system of record), Redis (availability cache + slot locks), Blob Storage; hosted background services (IHostedService).
- Auth: Google OIDC; API issues bearer JWT with roles (no cookies).
- API docs: Swashbuckle (Swagger) code-first.
- Testing: MSTest + FluentAssertions + Moq; Integration via WebApplicationFactory + Testcontainers (Linux) + Respawn; E2E via Playwright; Perf via Azure Load Testing.
- Deployment: Azure App Service (Linux), slots for blue/green. No Front Door in Phase 0.
- NFRs: p95 /public/availability ≤ 300 ms @100 RPS; calendar ≤ 1.5 s @30 RPS; 99.9% availability; secure by default (CORS allow-list), rate limiting on /public/*; App Insights with dashboards/alerts.

## definition of done (per increment)
- Code + tests + docs updated; Swagger reflects current endpoints.
- Build/lint/tests green locally and in CI; coverage meets thresholds per TEST_STRATEGY.md.
- Minimal E2E added for user-facing flow when applicable.
- Observability for new paths: logs/metrics/events.
