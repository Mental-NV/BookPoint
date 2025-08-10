# BookPoint — Booking Platform (Phase 0)

## Getting Started

Prerequisites
- .NET 9 SDK
- Node.js 20+ (for SPAs later), PNPM or npm
- Docker (for local SQL/Redis later — not required for Work Item 1)

Clone and build
```pwsh
# from repo root
 dotnet restore BookPoint.sln
 dotnet build BookPoint.sln -v minimal
```

Run the API locally
```pwsh
 dotnet run --project src/BookPoint.Api
# Open http://localhost:5191/health  → { "status": "ok" }
```

## Running Tests

Unit tests
```pwsh
 dotnet test BookPoint.sln -v minimal
```

Notes
- This repository uses MSTest + FluentAssertions for unit tests.
- CI via GitHub Actions runs restore, build, and test on PRs and pushes to main.
