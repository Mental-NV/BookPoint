# ACCEPTANCE_CRITERIA.md

Barber Booking Platform — **Phase 0**  
Scope: Public booking, Admin calendar, Mock deposits, Mock SMS, Basic analytics, Google auth.

---

## Global Definition of Done (applies to all stories)
- **Functionality**: Implemented according to the acceptance criteria below; no critical or high bugs.
- **Tests**: Unit + integration tests cover happy path and main edge cases; E2E for critical flows.
- **Performance**: Meets NFRs — `/public/availability` p95 ≤ 300ms (warm cache); admin calendar load p95 ≤ 1.5s.
- **Security**: Input validation, authz checks (roles), rate limiting on `/public/*`.
- **Observability**: Logs, traces, and metrics for key events; App Insights dashboards updated.
- **Docs**: API.yaml updated, CHANGELOG entry, user-facing copy strings finalized.
- **Accessibility**: Keyboard navigation and labels for forms and modals; color-contrast pass.
- **i18n readiness**: Strings externalized; RU default.
- **Operational**: Feature flags for mock providers; config via env vars; health endpoints green.

---

## Epics Overview
- **E1. Public Booking**
- **E2. Admin Calendar & Management**
- **E3. Deposits (Mock Payment)**
- **E4. Notifications (Mock SMS)**
- **E5. Basic Analytics**
- **E6. Auth & Security (Google for Admin)**
- **E7. Observability & Ops**

---

## E1. Public Booking

### US-001 — Browse branches & services
**Acceptance Criteria**
- When I open the public site and provide a tenant, I can see a list of **branches** with `name`, `address`.
- Selecting a branch shows **services** with `name`, `duration`, `price`, and an indicator if **deposit** is required.
- Services reflect branch availability (only those offered in the branch).

**DoD**
- API `GET /public/branches`, `GET /public/services?branchId` implemented, tested, and documented.
- UI renders lists with empty/loading/error states.

---

### US-002 — View availability
**Acceptance Criteria**
- Given branch, service, (optional) staff, and date, the system returns **time slots** aligned to the configured grid.
- Returned slots exclude conflicts (existing appointments + buffers) and out-of-hours.
- Response time p95 ≤ 300ms with warm cache.
- Cache invalidates on appointment create/update/cancel.

**DoD**
- API `GET /public/availability` implemented with Redis cache; unit + integration tests for overlap logic.
- Telemetry records cache hit/miss and compute time.

---

### US-003 — Hold a slot
**Acceptance Criteria**
- Posting a valid slot creates a **hold** with a **TTL 120s** and returns `holdId` + `expiresAtUtc`.
- If the slot is already held/confirmed, API responds **409 Conflict**.
- Hold auto-expires after TTL; expired holds are rejected by confirm.

**DoD**
- API `POST /public/booking/hold` with Redis `SET NX EX` lock; tests for concurrency.
- App Insights event `BookingHold` with tenant/staff/slot.

---

### US-004 — Enter contact & confirm (no deposit)
**Acceptance Criteria**
- Required fields: `name`, `phone`; email optional.
- If the service **does not** require a deposit, confirm returns **`Appointment.Confirmed`** with a **booking code** and **ICS** link.
- Phone verification is **mocked**: user can request a code; system returns a visible code for demo/testing.

**DoD**
- API `POST /public/booking/confirm` (no deposit path) + `POST /public/booking/verify-phone` (mock) implemented.
- ICS generation validated; E2E test asserts ICS download exists.

---

### US-005 — Confirm with deposit (mock)
**Acceptance Criteria**
- If service requires a deposit, confirm returns a **deposit intent** with **checkoutUrl**.
- Approving the mock payment changes `Appointment.Status → Confirmed` and `DepositStatus → Captured`.
- Failing/canceling mock payment releases hold and shows clear error message on return.

**DoD**
- `POST /mock/payments/create-intent` + `/mock/payments/callback` implemented.
- E2E covers Approve/Fail branches; idempotency verified with repeated callbacks.

---

### US-006 — Client cancels with booking code
**Acceptance Criteria**
- Providing a valid **booking code** for a **future** appointment sets status to **Canceled** and frees the slot.
- A mock SMS notification is queued.
- Canceling a past appointment returns **400**.

**DoD**
- API `/public/booking/cancel` implemented with validation + tests.
- App Insights event `BookingCanceled` logged.

---

## E2. Admin Calendar & Management

### US-007 — Google sign-in & roles
**Acceptance Criteria**
- Admin can sign in via Google and is recognized with the correct **role** (Owner/Manager/Receptionist/Barber).
- Unauthorized users are denied with 401/403.
- Session/JWT expires and refreshes appropriately; logout works.

**DoD**
- OIDC configured; role claims injected; protected routes enforced; integration tests with test identity.

---

### US-008 — Calendar views
**Acceptance Criteria**
- Day and Week views display appointments by staff, color-coded by status.
- Initial load (typical week) p95 ≤ 1.5s.
- Empty, loading, and error states are handled gracefully.

**DoD**
- API `GET /admin/calendar` implemented; UI renders virtualized events; performance measured in CI run.

---

### US-009 — Create appointment (admin)
**Acceptance Criteria**
- Dragging on a free time range opens a modal to select service/client.
- On save, appointment is created without double-booking; conflicts return **409**.
- Staff must have the selected service in their **skills**.

**DoD**
- API `POST /admin/appointments` with validation; integration tests for conflicts and skills.

---

### US-010 — Reschedule & cancel (admin)
**Acceptance Criteria**
- Drag-and-drop move updates the appointment if conflict-free; otherwise shows error.
- Cancel updates status and frees the slot.
- Optional optimistic concurrency via ETag prevents overwriting changes from another admin.

**DoD**
- API `PATCH /admin/appointments/{id}` implemented; tests for reschedule/cancel/hard conflict.
- Telemetry event `AppointmentRescheduled` emitted.

---

### US-011 — Manage services and staff
**Acceptance Criteria**
- Admin can **CRUD** services (duration, price, deposit rule) and **CRUD** staff (skills, hours, breaks, vacations).
- Validation prevents zero/negative durations and invalid deposit configs.

**DoD**
- APIs `/admin/services` and `/admin/staff` implemented; form validations; unit tests for validators.

---

## E3. Deposits (Mock Payment)

### US-012 — Deposit calculation
**Acceptance Criteria**
- Deposit amount is computed correctly (fixed/percent of base price) with correct rounding to **2 decimals**.

**DoD**
- Unit tests for deposit calculator (edge: 0, fractions, large amounts).

---

### US-013 — Mock payment lifecycle
**Acceptance Criteria**
- Create intent → Approve/Fail updates `DepositTransactions` and appointment deposit status.
- Replayed callbacks are **idempotent** (no duplicates).

**DoD**
- Integration tests simulate duplicate callbacks; data remains consistent.

---

## E4. Notifications (Mock SMS)

### US-014 — Confirmation & reminder logs
**Acceptance Criteria**
- On appointment confirmation, system inserts a **Notification** row with Channel `sms`, Template `booking_confirmed`, Status `queued` then `sent`.
- Reminder entries are created at **T-24h** and **T-2h** by a timer job and marked as sent.

**DoD**
- Azure Functions timer implemented (dev) or background hosted service; tests assert state transitions.

---

### US-015 — Outbox UI
**Acceptance Criteria**
- Admin can view latest mock messages with timestamp, channel, template, and payload preview.
- Paging or infinite scroll supported for ≥ 1000 messages.

**DoD**
- API/UI built; performance verified with seeded data; telemetry `SmsOutboxViewed` event.

---

## E5. Basic Analytics

### US-016 — KPIs dashboard
**Acceptance Criteria**
- Given a date range (and optional branch), the dashboard displays:
  - **Total appointments**
  - **Cancellations** and **cancellation rate**
  - **Occupancy %** (Booked minutes / Available minutes)
  - **Deposits collected (mock)**
  - **Average lead time (hours)**
- Results consistent with database facts (±1 during concurrent updates).

**DoD**
- API `GET /admin/analytics/kpis` implemented; unit tests for calculations; E2E asserts values against seeded fixtures.

---

### US-017 — CSV export
**Acceptance Criteria**
- Admin can export appointments to CSV within the selected date range.
- File opens in Excel; UTF-8 with BOM; includes header row.

**DoD**
- API `GET /admin/analytics/export` returns `text/csv`; E2E verifies content & encoding.

---

## E6. Auth & Security

### US-018 — Access control & rate limiting
**Acceptance Criteria**
- Admin endpoints require valid JWT/session with role authorization.
- Public endpoints `/public/*` are throttled; excessive calls return **429** with `Retry-After` header.
- CORS only allows Admin/Public SPA origins.

**DoD**
- Middleware configured; integration tests for 401/403/429; security headers audited.

---

## E7. Observability & Ops

### US-019 — Tracing & dashboards
**Acceptance Criteria**
- Key events (`BookingConfirmed`, `DepositCapturedMock`, `SmsQueuedMock`) appear in App Insights with correlation IDs.
- Dashboards show p95 latency, error rate, RPS, and booking funnel.

**DoD**
- Telemetry enriched (tenant, branch, staff anonymized IDs); workbook or dashboard JSON committed.

---

### US-020 — Alerts
**Acceptance Criteria**
- Alerts fire on:
  - Error rate spike (>2% for 10 min).
  - API p95 > 800ms for 10 min.
  - SQL DTU > 80% for 10 min.
  - Redis connectivity failures.
- Alerts include actionable runbooks.

**DoD**
- Alert rules stored as infra-as-code; runbook docs linked from alert descriptions.

---

## Non-Functional Acceptance (release gate)
- **Availability**: API runs with ≥ 2 instances; health probes green for 24h.
- **Scalability**: Autoscale rule verified via synthetic load.
- **Backups**: Azure SQL PITR enabled; restore drill executed once before go-live.
- **Security review**: OWASP ASVS Level 2 checklist pass (Phase 0 scope).

