# TASKS.md — Phase 0 Work Items (prioritized)

Priority legend: P0 (critical path), P1 (important), P2 (nice-to-have)

1) P0 — Solution scaffolding and CI build
- AC: .sln + projects compile; health endpoint returns 200; CI runs build/test.
- Tests: smoke unit test.

2) P0 — EF Core DbContext + initial migration
- AC: Entities, DbContext, initial migration applies; config via env.
- Tests: Integration test spins SQL container and migrates.

3) P0 — Redis adapter + hold lock service
- AC: SET NX EX, release, TTL from config.
- Tests: Integration tests acquire/reject/expire.

4) P0 — Availability computation service
- AC: Work patterns → slots; skill check; overlap removal; caching.
- Tests: Unit tests grid/overlaps/skills; cache hit path.

5) P0 — Public endpoints: availability/hold/confirm/cancel
- AC: Controllers + validations + ProblemDetails; Swagger visible.
- Tests: Integration happy + conflict (409).

6) P1 — Mock notifications + hosted reminders
- AC: Mock outbox, reminder service flips to sent; App Insights events.
- Tests: Integration verifies queued → sent.

7) P1 — Admin calendar range + appointments PATCH
- AC: Range query; PATCH reschedule with conflict checks; optional ETag.
- Tests: Integration for reschedule and conflict.

8) P1 — Services/Staff/Clients CRUD
- AC: CRUD endpoints; role policies enforced; validators.
- Tests: Unit validator tests; integration CRUD roundtrip.

9) P1 — Analytics KPIs + CSV export
- AC: KPIs; CSV columns finalized; Blob storage write/read.
- Tests: Unit KPI calc; integration CSV content.

10) P1 — WebPublic wizard (happy path)
- AC: 5-step flow; ICS download; mock SMS toast; conflict error UX.
- Tests: Playwright happy + conflict.

11) P1 — WebAdmin basics: login + calendar DnD
- AC: Google auth stub; calendar create/move/cancel; role-gated routes.
- Tests: Playwright admin scenario.

12) P2 — Observability dashboards + perf validation
- AC: Custom events, dashboards; Azure Load Testing check meets targets.
- Tests: Store/load perf report; assert thresholds.
