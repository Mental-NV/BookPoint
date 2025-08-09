# DESIGN.md

## Product: Booking Platform — **Phase 0**

Scope limited to: **core booking**, **admin calendar**, **mocked SMS**, **basic analytics**.  
Platform: **Web-only**, hosted fully on **Azure**.  
Auth: **Google Sign-In** for back office (admins/staff). Public booking is anonymous.

---

## 1) Goals & Success Criteria

### Goals
- Frictionless **online booking** without admin help.
- Reliable **admin calendar** with conflict prevention & DnD.
- **Notifications** shown as **mock SMS** now; swappable later.
- **Basic analytics** (occupancy, appointments).
- Horizontally **scalable** & observable on Azure.

### Success Criteria (Phase 0)
- Users complete UC-001…UC-007 (below) without errors.
- p95 public availability request < **300 ms** (warm cache).
- p95 admin calendar load < **1.5 s** (week view).
- Zero-downtime deploys; App Insights dashboards show green KPIs.

---

## 2) Personas

- **Client (Guest):** books from public site; no login.
- **Receptionist/Administrator:** manages bookings; phone/walk-ins.
- **Staff member:** sees own schedule; minor edits.
- **Owner/Manager:** configures catalog/hours; sees analytics.

---

## 3) Use Cases

1. **UC-001: Client books online**
   - **Trigger:** Client opens public site.
   - **Flow:** Select branch → service → (optional) staff → time → contact → confirmation + ICS.
   - **Post:** Show “(mock) SMS sent”.
   - **Failure:** Lock timeout → slot released.

2. **UC-002: Client verifies phone (mock)**
   - **Trigger:** Enter phone during booking.
   - **Flow:** Click “Send code” → UI shows fake code → user enters code → continue.
   - **Alt:** Wrong/expired code → retry.

3. **UC-003: Admin creates booking (walk-in/phone)**
   - **Flow:** Admin DnD on calendar → modal with client + service → save.
   - **Validations:** Staff skills, time conflicts, buffers.

4. **UC-004: Admin reschedules or cancels**
   - **Reschedule:** DnD to new time → hard check; notify client (mock SMS).
   - **Cancel:** Mark canceled → release slot → (mock) notify.

5. **UC-005: Configure catalog/staff/hours**
   - Services (duration, price).
   - Staff (skills/hours/breaks/vacations).
   - Branch hours; booking buffers; last‑minute cutoff.

6. **UC-006: View analytics**
   - Tiles: appointments, occupancy, cancellations.
   - Filters: branch, date range; CSV export.

7. **UC-007: Admin/Staff login with Google**
   - First owner invites others; assign roles.

---

## 4) Functional Requirements

### Public Booking
- Browse **branches**, **services**, **staff** (optional filter).
- **Availability** by service/staff/day; 5–15 min grid alignment.
- **Slot hold** on confirm step (TTL 120s) with Redis; release on timeout.
- **Contact**: name, phone, email (optional); phone verification (mock).
- Confirmation screen with booking code + **ICS** file; (mock) SMS.

### Admin / Back Office
- **Calendar**: Day/Week, DnD create/move/resize; conflict detection; filters by staff/service.
- **Clients**: quick create; notes.
- **Services**: CRUD; duration, price.
- **Staff**: CRUD; skills; working hours, breaks, vacations.
- **Settings**: buffers, cutoffs, mock toggles.
- **Mock console**: “SMS Outbox”.

### Notifications (Mocked)
- Confirmation/reschedule/reminder **queued** to `Notifications` table and visible in UI.
- Timer job can “send” reminders by flipping status to `sent`.

- KPIs: **Occupancy %**, **Total appointments**, **Cancellation rate**, **Lead time**.
- Charts: Appointments by day, Occupancy by staff, Service mix.
- CSV export.

---

## 5) Non-Functional Requirements

- **Scalability:** App Service autoscale; stateless API; Redis for locks/cache.
- **Performance:** p95 availability < 300ms, calendar < 1.5s; cache hot paths.
- **Availability:** 99.9% target; multi‑instance API.
- **Security:** HTTPS; WAF; Google OAuth for admin; tenant isolation by `TenantId`; RBAC.
- **Reliability:** Idempotent confirms; durable state in SQL.
- **Observability:** App Insights traces, logs, metrics; dashboards; alerts.
- **Backups/DR:** Azure SQL PITR; daily logical backups; restore drills.
- **Maintainability:** Clean architecture; DI for providers; feature flags for mocks.
- **Internationalization:** RU first; i18n-ready strings.

---

## 6) Domain Rules (Phase 0)

- Appointment time = start to start + service duration (+ optional buffer).
- Staff must have skill for service.
- No double-booking per staff; resource management beyond staff is **out of scope**.
- Holds expire automatically (120s default).
- Appointment states: `Pending → Confirmed | Canceled | NoShow (manual)`.

---

## 7) Data Definitions (key)

- **Services**: `DurationMin`, `BasePrice`.
- **Staff**: `Skills[]` (service ids), `WorkPattern` (weekly schedule + exceptions).
- **Appointments**: `StartUtc`, `EndUtc`, `Status`, `Source(web|admin)`.
- **Notifications**: `Channel(sms|email)`, `Template`, `Payload`, `Status`.

---

## 8) Testing Strategy (summary)

- **Unit:** availability, lock/confirm.
- **Integration:** booking flow, admin DnD, cancellations.
- **E2E:** public wizard + admin calendar happy paths; conflict scenario.
- **Load:** Availability @100 RPS p95<300ms; Calendar @30 RPS p95<1.5s.
- **Security:** role checks; input validation; rate limiting on `/public/*`.

---

## 9) Milestones

- **M1 Foundations:** infra + auth + CRUD (tenant/branch/staff/services).
- **M2 Booking Engine:** availability + holds + public wizard.
- **M3 Notifications & Reminders:** mock SMS + reminders.
- **M4 Analytics & Polish:** KPIs, exports, dashboards, E2E & load tests.
