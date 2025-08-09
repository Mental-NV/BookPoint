# Development Guide

## Prerequisites
- .NET 8 SDK
- Node.js 20+ and PNPM or npm
- Docker (for local SQL Server + Redis)
- VS Code + recommended extensions: C#, ESLint, Prettier, Tailwind CSS, Azure Resources

## Services (local via Docker)
Create `docker-compose.override.yml` (or use the snippet below):

```yaml
version: '3.9'
services:
  sql:
    image: mcr.microsoft.com/mssql/server:2022-latest
    environment:
      - ACCEPT_EULA=Y
      - SA_PASSWORD=Your_strong_password123
    ports: ['1433:1433']
    healthcheck:
      test: ["CMD", "/opt/mssql-tools/bin/sqlcmd", "-S", "localhost", "-U", "sa", "-P", "Your_strong_password123", "-Q", "select 1"]
      interval: 10s
      retries: 10
  redis:
    image: redis:7-alpine
    ports: ['6379:6379']
```

Run:
```bash
docker compose up -d
```

> Note: Use EF Core migrations to create/update the database once the backend exists; no separate SQL file is maintained at this stage.

## Projects
- `src/Domain` — Entities, value objects, domain services (no external deps)
- `src/Application` — Use cases (MediatR), DTOs, validators, policies
- `src/Infrastructure` — EF Core, repositories, providers (SQL, Redis, Storage, mocks)
- `src/Api` — ASP.NET Core API (controllers, DI, auth, middleware)
- `src/WebPublic` — React SPA (public booking)
- `src/WebAdmin` — React SPA (admin)
- `tests/Unit` — unit tests (Domain/Application)
- `tests/Integration` — API + Infrastructure integration tests
- `tests/E2E` — end-to-end tests (Playwright/Cypress)

## Environment Variables

Create `/.env.local` files or use `dotnet user-secrets` for API:

**API**
```
ASPNETCORE_ENVIRONMENT=Development
ConnectionStrings__Default=Server=localhost,1433;Database=Booking;User Id=sa;Password=Your_strong_password123;TrustServerCertificate=True;
Redis__Connection=localhost:6379
Auth__Google__ClientId=YOUR_GOOGLE_CLIENT_ID
Auth__Google__ClientSecret=YOUR_GOOGLE_CLIENT_SECRET
Jwt__Issuer=http://localhost
Jwt__Audience=booking-admin
Jwt__SigningKey=dev-secret-signing-key-change
Features__UseMockSms=true
Booking__HoldTtlSeconds=120
Booking__SlotGridMinutes=15
```

**WebPublic**
```
VITE_API_BASE_URL=http://localhost:5000/api
```

**WebAdmin**
```
VITE_API_BASE_URL=http://localhost:5000/api
VITE_GOOGLE_CLIENT_ID=YOUR_GOOGLE_CLIENT_ID
```

## Running locally

### API
```bash
cd src/Api
dotnet restore
dotnet build
dotnet run
```

### WebPublic
```bash
cd src/WebPublic
pnpm i
pnpm dev  # or npm run dev
```

### WebAdmin
```bash
cd src/WebAdmin
pnpm i
pnpm dev
```

Open:
- Public: http://localhost:5173
- Admin:  http://localhost:5174

## Testing
See `TEST_STRATEGY.md` for details. Quick start:
```bash
# Unit
dotnet test tests/Unit

# Integration
dotnet test tests/Integration

# E2E (Playwright)
cd tests/E2E
pnpm i
pnpm test
```

## Migrations
If using EF Core:
```bash
dotnet ef migrations add Init --project src/Infrastructure --startup-project src/Api
dotnet ef database update --project src/Infrastructure --startup-project src/Api
```

The EF Core migrations are the source of truth. Use them to create and update the database instead of the template SQL file.

## Troubleshooting
- **SQL login failed** → ensure SA password meets complexity; add `TrustServerCertificate=True`.
- **Port conflicts** → change ports in launch configs or docker compose.
- **Google login** → set OAuth redirect URIs to your local Admin SPA URL.
