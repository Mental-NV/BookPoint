# ARCHITECTURE.md

## Barber Booking Platform — Phase 0 Architecture
Scope: **Public booking**, **Admin calendar**, **Mock SMS**, **Mock deposits**, **Basic analytics**.  
Platform: **Web-only** on **Azure**. Admin auth: **Google** (OIDC). Public flow is anonymous.

---

## 1) High-Level Overview

```
[ Public SPA ]        [ Admin SPA (Google auth) ]
        \\             //
         \\           //
     Azure Front Door (WAF, TLS, routing)
                |
         App Service: API  (ASP.NET Core 8, stateless)
                |
         -------------------------------
         | Azure SQL | Azure Redis | Azure Storage | Azure Functions | App Insights |
         -------------------------------
```

**Key decisions**
- Single **ASP.NET Core API** for both SPAs. No separate gateway in Phase 0.
- **Azure SQL** is the system of record; **Redis** used for availability cache & slot locks.
- **Providers** (SMS, Payments) behind interfaces; **mock** implementations in Phase 0.
- Clean, modular solution with clear **domain boundaries** and **CQRS-light** in the application layer.

---

## 2) Target Stack

- **Frontend**: React + TypeScript, Vite, React Router, React Query, Redux, Tailwind.
- **Backend**: ASP.NET Core 8 (Controllers), MediatR, EF Core, FluentValidation.
- **Data**: Azure SQL (General Purpose tier), Azure Cache for Redis (Standard), Azure Storage (Blobs for CSV/ICS).
- **Jobs**: Azure Functions (timer jobs for reminders & housekeeping).
- **Auth**: Google OpenID Connect for Admin. JWT/cookie issued by API for session.
- **Observability**: Application Insights + Log Analytics.
- **CI/CD**: GitHub Actions, deployment slots (blue/green) for API.

---

## 3) Module Boundaries (Clean Architecture)

**Projects (suggested layout)**
```
/src
  /Domain            -- Entities, value objects, invariants, domain services
  /Application       -- Use cases (MediatR), DTOs, validators, policies
  /Infrastructure    -- EF Core, repositories, providers (SQL, Redis, Storage, SMS/Payments mocks)
  /Api               -- ASP.NET Core API (controllers, DI wiring, auth, middleware)
  /WebPublic         -- React SPA (public booking)
  /WebAdmin          -- React SPA (admin calendar & settings)
/tests
  /Unit              -- Domain/Application unit tests
  /Integration       -- API + Infrastructure integration tests
  /E2E               -- Playwright/Cypress end-to-end tests
```

**Dependency rules**
- Domain has no dependencies.
- Application depends only on Domain and abstractions.
- Infrastructure depends on Application and Domain to provide implementations.
- Api depends on Application and Infrastructure for runtime wiring.
- Web SPAs call Api over HTTP; no direct references to backend projects.

**Domain submodules**
- **Catalog**: Services (+ deposit policy).
- **Scheduling**: Staff, work patterns (weekly + exceptions).
- **Clients**: Simple CRM (name/phone/email/notes).
- **Booking**: Availability, holds, create/confirm/cancel, ICS export.
- **Payments**: `IPaymentGateway` abstraction (mock now).
- **Notifications**: `ISmsSender` abstraction (mock now), reminder scheduler.
- **Analytics**: KPI queries (may include simple rollups later).

**Application layer patterns**
- **MediatR** commands/queries, **FluentValidation** for input DTOs.
- **Policies/Rules** encapsulated as services (e.g., deposit calculation, buffer policy).

---

## 4) Data Model (Phase 0, concise)

Core tables (see `DB_SCHEMA.sql` for full DDL):
- `Tenants`, `Branches`
- `Services` (duration, price, deposit rules)
- `Staff`, `StaffSkills`, `Clients`
- `Appointments` (Status: Pending|Confirmed|Canceled|NoShow; DepositStatus)
- `DepositTransactions` (Provider='Mock' in Phase 0)
- `Notifications` (Channel sms|email; Status queued|sent|failed)
- `AuditLogs`

**Indexes (key)**
- `Appointments(TenantId, StaffId, StartUtc)`
- `Appointments(TenantId, BranchId, StartUtc)`
- `Clients(TenantId, Phone)`

**Tenancy**
- All rows include `TenantId`. API injects tenant context (e.g., subdomain or header). Repositories must filter by `TenantId` by default (global query filter in EF).

---

## 5) Availability & Slot Holds

**Availability computation**
1. Build staff work segments from `WorkPatternJson` minus exceptions (breaks/vacations).
2. Align candidate starts to grid (e.g., 15 min).
3. Remove overlaps with existing appointments + optional buffers.
4. Enforce staff skill for selected service.
5. Cache result in Redis with short TTL (60–120s).

**Redis keys**
- Availability cache:
  - `avail:{tenant}:{branch}:{date}:{service}:{staff?}` → JSON slots, TTL 60–120s
- Slot hold locks:
  - `slot:{tenant}:{staff}:{startUtcTicks}` → GUID (holdId), `SET NX EX 120`

**Hold & confirm flow**
- Client hits `/public/booking/hold` → lock acquired (120s).
- `/public/booking/confirm` validates & persists `Appointment`.
- If deposit required → create mock payment intent → confirm on callback.
- On success → set `Status=Confirmed`, `DepositStatus=Captured`, release lock.

Idempotency: `holdId` is the idempotency key; duplicate confirms are no-ops.

---

## 6) Provider Abstractions

```csharp
public interface ISmsSender {
  Task SendAsync(string phone, string templateKey, object model, CancellationToken ct);
}

public interface IPaymentGateway {
  Task<CreateIntentResult> CreateIntentAsync(Guid appointmentId, Money amount, CancellationToken ct);
  Task<PaymentResult> CaptureAsync(string intentId, CancellationToken ct);
  Task<PaymentResult> RefundAsync(string intentId, CancellationToken ct);
}
```

**Phase 0 implementations**
- `MockSmsSender`: persists to `Notifications`, logs to App Insights, marks `queued` → `sent`.
- `MockPaymentGateway`: creates a fake `intentId` + `/mock/pay/{intentId}`; SPA Approve/Fail triggers callback; writes `DepositTransactions` and updates `Appointments`.

Swap for real providers by replacing DI registrations; no domain changes.

---

## 7) API Surface (summary)

Public (anonymous):
- `GET /public/branches`
- `GET /public/services?branchId`
- `GET /public/staff?branchId&serviceId?`
- `GET /public/availability?...`
- `POST /public/booking/hold`
- `POST /public/booking/confirm`
- `POST /public/booking/cancel`
- `POST /public/booking/verify-phone` (mock)

Admin (Google auth):
- `GET /admin/calendar?from&to&staffId?`
- `POST /admin/appointments`
- `PATCH /admin/appointments/{id}`
- `GET /admin/clients/search?q=`
- `GET/POST /admin/services`, `PATCH /admin/services/{id}`
- `GET/POST /admin/staff`, `PATCH /admin/staff/{id}`
- `GET /admin/analytics/kpis`, `GET /admin/analytics/export`

Mock utility:
- `POST /mock/sms/send`
- `POST /mock/payments/create-intent`
- `POST /mock/payments/callback`

See `API.yaml` for OpenAPI details.

---

## 8) Frontend Architecture

**WebPublic (client booking)**
- **Pages**: Select Service → Select Staff → Select Time → Contact & Confirm → (Mock payment) → Confirmation.
- **State**: React Query for server state; local state for wizard steps.
- **UX**: show “(mock) SMS sent” toast; ICS file download; clear error for conflicts.

**WebAdmin (calendar)**
- **Views**: Day/Week calendar with DnD (create/move/resize).
- **Panels**: Appointment details panel (status, notes, mock send reminder).
- **Management**: Services CRUD, Staff CRUD, Settings, Mock Outbox, Payment Events.
- **Auth**: Google Sign-In; backend session/JWT; role-based routes.

---

## 9) Security & Auth

- **Admin** only via **Google OIDC**. API issues JWT/cookie with roles.
- **RBAC** roles: Owner, Manager, Receptionist, Barber.
- **Rate limiting**: IP throttle on `/public/*` + circuit breakers for provider calls.
- **CORS**: allow Admin/Public SPAs origins only.
- **Validation**: FluentValidation; `ProblemDetails` responses on errors.
- **Secrets**: Dev via env vars; Prod via Azure **Key Vault** + Managed Identity.

---

## 10) Deployment Topology (Azure)

**Resources**
- **Azure Front Door**: HTTPS termination, WAF, path-based routing to SPAs/API.
- **App Service – API**: ASP.NET Core, Linux plan, autoscale (min 2).
- **App Service – WebPublic**: static SPA hosting.
- **App Service – WebAdmin**: static SPA hosting.
- **Azure SQL Database**: General Purpose, PITR enabled.
- **Azure Cache for Redis**: Standard/Premium (TLS).
- **Azure Storage (Blob)**: CSV exports, ICS files.
- **Azure Functions**: Timer triggers (reminders, lock cleanup).
- **Application Insights**: telemetry for all apps.

**Autoscale (API)**
- Rules: scale out when
  - CPU > 65% for 10 min **or**
  - Requests > 300/sec for 5 min **or**
  - p95 latency > 800 ms for 5 min (custom metric).
- Cooldown 10–15 min; scale in gradually.

**Networking**
- App Service VNet integration (optional Phase 0).
- Private endpoints for SQL/Redis (later phases).

---

## 11) Observability

**Tracing & logs**
- Correlation IDs per request.
- Custom events: `BookingHold`, `BookingConfirmed`, `DepositCapturedMock`, `SmsQueuedMock`, `SmsSentMock`.
- Metrics: availability cache hit ratio, 409 conflicts, hold timeouts, deposit success rate.

**Dashboards**
- API p95 latency, error rate, RPS.
- Booking funnel: availability → holds → confirms.
- Notifications sent (mock).

**Alerts**
- Error rate spike.
- API p95 > 800 ms for 10 min.
- SQL DTU > 80% for 10 min.
- Redis connectivity failures.
- Hold timeout rate anomaly.

---

## 12) Error Handling & Idempotency

- Return **RFC 7807 ProblemDetails** for 4xx/5xx with codes: `validation_error`, `slot_conflict`, `hold_expired`, `not_found`, `forbidden`.
- Idempotent endpoints:
  - `/public/booking/confirm` keyed by `holdId`.
  - `/admin/appointments/{id}` PATCH guarded by `If-Match` (optional ETag) to avoid lost updates.

---

## 13) Configuration (Phase 0)

```
Features__UseMockSms=true
Features__UseMockPayments=true
Booking__HoldTtlSeconds=120
Booking__SlotGridMinutes=15
Auth__Google__ClientId=...
Auth__Google__ClientSecret=...
ConnectionStrings__Default=...
Redis__Connection=...
```

Feature flags allow seamless switch to real providers later.

---

## 14) CI/CD

**Pipeline (GitHub Actions)**
1. **Build & Test**: .NET restore/build/test; WebPublic/WebAdmin build & lint.
2. **Security checks**: dotnet vulnerable packages; npm audit (warn initially).
3. **Integration tests**: containerized SQL + Redis on CI.
4. **Deploy API**: to **staging slot**, run smoke tests, then **swap** to prod.
5. **Deploy SPAs**: to their App Services (invalidate Front Door cache).

**Migrations**
- EF Core migrations executed on deploy (guarded); zero-downtime (online migration practices).

---

## 15) Sequence Flows

**Public booking with deposit (mock)**
```
Client → GET /public/availability
Client → POST /public/booking/hold   -- lock in Redis
Client → POST /public/booking/confirm
 API  → Create Appointment(Pending, Required) + DepositIntent(Mock)
Client → (SPA) /mock/pay/{intent} → Approve
 SPA  → POST /mock/payments/callback(succeeded)
 API  → Update Appointment(Confirmed, Captured), release lock, enqueue mock SMS
```

**Admin reschedule**
```
Admin DnD → PATCH /admin/appointments/{id}
 API → Check conflicts/buffers → Update times → queue mock SMS
```

---

## 16) Performance Considerations

- Hot-path caching for availability; TTL short to reflect near-real-time changes.
- Avoid N+1: aggregate queries for calendar (range per staff).
- Use `AsNoTracking` for read models; select only required fields.
- Batching: persist Notifications in bulk when possible (timer job).

---

## 17) Risks & Mitigations (Phase 0)

- **Double-booking**: Redis `SET NX` locks + transactional create; integration tests for races.
- **Mock drift from real providers**: contracts mirror real-world (intent/capture/refund), with webhook-style callbacks.
- **Complex work patterns**: keep JSON pattern simple; validate on save; advanced rules deferred to later phases.

---

## 18) ADR Snapshot (key decisions)

- **ADR-001**: Use Clean Architecture with CQRS-light (MediatR) — maintainable & testable.
- **ADR-002**: Use Redis for holds & cache — prevents double-booking; fast availability.
- **ADR-003**: Provider abstractions for SMS/Payments — enable easy swap to real vendors later.
- **ADR-004**: Single API, no gateway in Phase 0 — simpler operations; revisit later if needed.
- **ADR-005**: Google-only admin auth — minimal setup; add providers later if needed.

---

## 19) Open Points (to refine during dev)

- Buffer rules per service (pre/post) default values.
- ICS delivery: download vs. email (email out of scope Phase 0).
- Admin DnD ETag support (optimistic concurrency) — optional in Phase 0.
