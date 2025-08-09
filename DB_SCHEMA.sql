/*
=====================================================================
    TEMPLATE ONLY — NON-AUTHORITATIVE (Phase 0)

    This SQL file is an illustrative, skeletal template meant to convey
    the target tables, indexes, and naming conventions. It is intentionally
    incomplete and may not compile as-is.

    Source of truth for the database schema will be EF Core Code‑First
    Migrations generated from the backend project. When the backend is
    implemented, prefer applying migrations or using the generated SQL
    script from EF over this file.

    Use cases for this file:
        - Documentation and quick reference during design
        - Optional scratch DB scaffolding during very early prototyping

    Do NOT use in production. Replace with EF migrations outputs once available.
=====================================================================
*/

------------------------------------------------------------
-- 0) Safety
------------------------------------------------------------
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

------------------------------------------------------------
-- 1) Tenancy & Core Reference
------------------------------------------------------------
CREATE TABLE dbo.Tenants (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Tenants PRIMARY KEY,
    Name NVARCHAR(200) NOT NULL,
    Timezone NVARCHAR(100) NOT NULL CONSTRAINT DF_Tenants_Timezone DEFAULT ('Europe/Moscow'),
    SettingsJson NVARCHAR(MAX) NULL,
    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Tenants_CreatedAt DEFAULT (SYSUTCDATETIME())
);
GO

CREATE TABLE dbo.Branches (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Branches PRIMARY KEY,
    TenantId UNIQUEIDENTIFIER NOT NULL,
    Name NVARCHAR(200) NOT NULL,
    Address NVARCHAR(400) NULL,
    Timezone NVARCHAR(100) NOT NULL CONSTRAINT DF_Branches_Timezone DEFAULT ('Europe/Moscow'),
    WorkHoursJson NVARCHAR(MAX) NULL,
    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Branches_CreatedAt DEFAULT (SYSUTCDATETIME()),
    RowVersion ROWVERSION NOT NULL,
    CONSTRAINT FK_Branches_Tenants FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(Id) ON DELETE CASCADE
);
GO
CREATE INDEX IX_Branches_Tenant ON dbo.Branches(TenantId);
GO

------------------------------------------------------------
-- 2) Admin Users (Google OIDC mapping) & Roles
------------------------------------------------------------
CREATE TABLE dbo.AdminUsers (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_AdminUsers PRIMARY KEY,
    TenantId UNIQUEIDENTIFIER NOT NULL,
    Email NVARCHAR(256) NOT NULL,
    GoogleSubject NVARCHAR(128) NULL, -- sub claim from Google
    DisplayName NVARCHAR(200) NULL,
    Role NVARCHAR(32) NOT NULL, -- Owner|Manager|Receptionist|Barber
    IsActive BIT NOT NULL CONSTRAINT DF_AdminUsers_IsActive DEFAULT (1),
    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_AdminUsers_CreatedAt DEFAULT (SYSUTCDATETIME()),
    RowVersion ROWVERSION NOT NULL,
    CONSTRAINT FK_AdminUsers_Tenants FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(Id) ON DELETE CASCADE,
    CONSTRAINT CK_AdminUsers_Role CHECK (Role IN (N'Owner', N'Manager', N'Receptionist', N'Barber'))
);
GO
CREATE UNIQUE INDEX UX_AdminUsers_Tenant_Email ON dbo.AdminUsers(TenantId, Email);
CREATE UNIQUE INDEX UX_AdminUsers_GoogleSubject ON dbo.AdminUsers(GoogleSubject) WHERE GoogleSubject IS NOT NULL;
GO

------------------------------------------------------------
-- 3) Catalog & Staff
------------------------------------------------------------
CREATE TABLE dbo.Services (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Services PRIMARY KEY,
    TenantId UNIQUEIDENTIFIER NOT NULL,
    Name NVARCHAR(200) NOT NULL,
    DurationMin INT NOT NULL CONSTRAINT CK_Services_Duration CHECK (DurationMin > 0),
    BasePrice DECIMAL(12,2) NOT NULL CONSTRAINT CK_Services_BasePrice CHECK (BasePrice >= 0),
    RequiresDeposit BIT NOT NULL CONSTRAINT DF_Services_RequiresDeposit DEFAULT (0),
    DepositType VARCHAR(10) NULL CONSTRAINT CK_Services_DepositType CHECK (DepositType IN ('fixed','percent')),
    DepositValue DECIMAL(12,2) NULL CONSTRAINT CK_Services_DepositValue CHECK (DepositValue >= 0),
    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Services_CreatedAt DEFAULT (SYSUTCDATETIME()),
    RowVersion ROWVERSION NOT NULL,
    CONSTRAINT FK_Services_Tenants FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(Id) ON DELETE CASCADE
);
GO
CREATE INDEX IX_Services_Tenant ON dbo.Services(TenantId);
GO

CREATE TABLE dbo.Staff (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Staff PRIMARY KEY,
    TenantId UNIQUEIDENTIFIER NOT NULL,
    BranchId UNIQUEIDENTIFIER NOT NULL,
    DisplayName NVARCHAR(200) NOT NULL,
    Email NVARCHAR(256) NULL,
    WorkPatternJson NVARCHAR(MAX) NULL, -- weekly schedule + exceptions
    IsActive BIT NOT NULL CONSTRAINT DF_Staff_IsActive DEFAULT (1),
    UserId UNIQUEIDENTIFIER NULL, -- optional link to AdminUsers for barbers
    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Staff_CreatedAt DEFAULT (SYSUTCDATETIME()),
    RowVersion ROWVERSION NOT NULL,
    CONSTRAINT FK_Staff_Tenants FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(Id) ON DELETE CASCADE,
    CONSTRAINT FK_Staff_Branches FOREIGN KEY (BranchId) REFERENCES dbo.Branches(Id),
    CONSTRAINT FK_Staff_AdminUsers FOREIGN KEY (UserId) REFERENCES dbo.AdminUsers(Id)
);
GO
CREATE INDEX IX_Staff_TenantBranch ON dbo.Staff(TenantId, BranchId);
GO

CREATE TABLE dbo.StaffSkills (
    StaffId UNIQUEIDENTIFIER NOT NULL,
    ServiceId UNIQUEIDENTIFIER NOT NULL,
    CONSTRAINT PK_StaffSkills PRIMARY KEY (StaffId, ServiceId),
    CONSTRAINT FK_StaffSkills_Staff FOREIGN KEY (StaffId) REFERENCES dbo.Staff(Id) ON DELETE CASCADE,
    CONSTRAINT FK_StaffSkills_Services FOREIGN KEY (ServiceId) REFERENCES dbo.Services(Id) ON DELETE CASCADE
);
GO
CREATE INDEX IX_StaffSkills_Service ON dbo.StaffSkills(ServiceId);
GO

------------------------------------------------------------
-- 4) Clients
------------------------------------------------------------
CREATE TABLE dbo.Clients (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Clients PRIMARY KEY,
    TenantId UNIQUEIDENTIFIER NOT NULL,
    Name NVARCHAR(200) NOT NULL,
    Phone NVARCHAR(50) NOT NULL,
    Email NVARCHAR(256) NULL,
    Notes NVARCHAR(1000) NULL,
    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Clients_CreatedAt DEFAULT (SYSUTCDATETIME()),
    RowVersion ROWVERSION NOT NULL,
    CONSTRAINT FK_Clients_Tenants FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(Id) ON DELETE CASCADE
);
GO
CREATE INDEX IX_Clients_Tenant_Phone ON dbo.Clients(TenantId, Phone);
GO

------------------------------------------------------------
-- 5) Appointments & Deposits
------------------------------------------------------------
CREATE TABLE dbo.Appointments (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Appointments PRIMARY KEY,
    TenantId UNIQUEIDENTIFIER NOT NULL,
    BranchId UNIQUEIDENTIFIER NOT NULL,
    StaffId UNIQUEIDENTIFIER NOT NULL,
    ServiceId UNIQUEIDENTIFIER NOT NULL,
    ClientId UNIQUEIDENTIFIER NOT NULL,
    StartUtc DATETIME2 NOT NULL,
    EndUtc DATETIME2 NOT NULL,
    Status VARCHAR(20) NOT NULL CONSTRAINT CK_Appointments_Status CHECK (Status IN ('Pending','Confirmed','Canceled','NoShow')),
    DepositStatus VARCHAR(20) NOT NULL CONSTRAINT CK_Appointments_DepositStatus CHECK (DepositStatus IN ('NotRequired','Required','Captured','Refunded','Failed')),
    Source VARCHAR(10) NOT NULL CONSTRAINT CK_Appointments_Source CHECK (Source IN ('web','admin')),
    BookingCode NVARCHAR(16) NOT NULL, -- used for public cancel/reschedule links
    Notes NVARCHAR(1000) NULL,
    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Appointments_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt DATETIME2 NOT NULL CONSTRAINT DF_Appointments_UpdatedAt DEFAULT (SYSUTCDATETIME()),
    RowVersion ROWVERSION NOT NULL,
    CONSTRAINT FK_Appointments_Tenants FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(Id) ON DELETE CASCADE,
    CONSTRAINT FK_Appointments_Branches FOREIGN KEY (BranchId) REFERENCES dbo.Branches(Id),
    CONSTRAINT FK_Appointments_Staff FOREIGN KEY (StaffId) REFERENCES dbo.Staff(Id),
    CONSTRAINT FK_Appointments_Services FOREIGN KEY (ServiceId) REFERENCES dbo.Services(Id),
    CONSTRAINT FK_Appointments_Clients FOREIGN KEY (ClientId) REFERENCES dbo.Clients(Id),
    CONSTRAINT CK_Appointments_Time CHECK (EndUtc > StartUtc)
);
GO
CREATE INDEX IX_Appointments_Tenant_Staff_Time ON dbo.Appointments(TenantId, StaffId, StartUtc);
CREATE INDEX IX_Appointments_Tenant_Branch_Time ON dbo.Appointments(TenantId, BranchId, StartUtc);
CREATE INDEX IX_Appointments_Client ON dbo.Appointments(ClientId, StartUtc);
CREATE UNIQUE INDEX UX_Appointments_Tenant_BookingCode ON dbo.Appointments(TenantId, BookingCode);
GO

CREATE TABLE dbo.DepositTransactions (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_DepositTransactions PRIMARY KEY,
    TenantId UNIQUEIDENTIFIER NOT NULL,
    AppointmentId UNIQUEIDENTIFIER NOT NULL,
    Provider VARCHAR(50) NOT NULL CONSTRAINT DF_Deposits_Provider DEFAULT ('Mock'),
    Amount DECIMAL(12,2) NOT NULL CONSTRAINT CK_Deposits_Amount CHECK (Amount >= 0),
    Currency CHAR(3) NOT NULL CONSTRAINT DF_Deposits_Currency DEFAULT ('RUB'),
    Status VARCHAR(20) NOT NULL CONSTRAINT CK_Deposits_Status CHECK (Status IN ('succeeded','failed','refunded')),
    ExternalRef NVARCHAR(100) NULL,
    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Deposits_CreatedAt DEFAULT (SYSUTCDATETIME()),
    RowVersion ROWVERSION NOT NULL,
    CONSTRAINT FK_Deposits_Tenants FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(Id) ON DELETE CASCADE,
    CONSTRAINT FK_Deposits_Appointments FOREIGN KEY (AppointmentId) REFERENCES dbo.Appointments(Id) ON DELETE CASCADE
);
GO
CREATE INDEX IX_Deposits_Tenant_Status ON dbo.DepositTransactions(TenantId, Status);
GO

------------------------------------------------------------
-- 6) Notifications (Mock SMS/Email log)
------------------------------------------------------------
CREATE TABLE dbo.Notifications (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Notifications PRIMARY KEY,
    TenantId UNIQUEIDENTIFIER NOT NULL,
    AppointmentId UNIQUEIDENTIFIER NULL,
    Channel VARCHAR(10) NOT NULL CONSTRAINT CK_Notifications_Channel CHECK (Channel IN ('sms','email')),
    Template NVARCHAR(100) NOT NULL,
    PayloadJson NVARCHAR(MAX) NULL,
    Status VARCHAR(10) NOT NULL CONSTRAINT CK_Notifications_Status CHECK (Status IN ('queued','sent','failed')),
    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Notifications_CreatedAt DEFAULT (SYSUTCDATETIME()),
    RowVersion ROWVERSION NOT NULL,
    CONSTRAINT FK_Notifications_Tenants FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(Id) ON DELETE CASCADE,
    CONSTRAINT FK_Notifications_Appointments FOREIGN KEY (AppointmentId) REFERENCES dbo.Appointments(Id) ON DELETE SET NULL
);
GO
CREATE INDEX IX_Notifications_Tenant_Status ON dbo.Notifications(TenantId, Status, CreatedAt DESC);
GO

------------------------------------------------------------
-- 7) Audit
------------------------------------------------------------
CREATE TABLE dbo.AuditLogs (
    Id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AuditLogs PRIMARY KEY,
    TenantId UNIQUEIDENTIFIER NOT NULL,
    ActorId UNIQUEIDENTIFIER NULL, -- AdminUsers.Id if available
    Action NVARCHAR(100) NOT NULL,
    EntityType NVARCHAR(100) NOT NULL,
    EntityId NVARCHAR(100) NOT NULL,
    BeforeJson NVARCHAR(MAX) NULL,
    AfterJson NVARCHAR(MAX) NULL,
    Timestamp DATETIME2 NOT NULL CONSTRAINT DF_AuditLogs_Timestamp DEFAULT (SYSUTCDATETIME())
);
GO
CREATE INDEX IX_Audit_Tenant_Time ON dbo.AuditLogs(TenantId, Timestamp DESC);
GO

------------------------------------------------------------
-- 8) Helper: Deterministic Booking Code generator (optional sample)
------------------------------------------------------------
-- You can generate codes at the application layer. If you prefer SQL helper:
-- Example: produce a 8-12 char uppercase code from NEWID()
-- SELECT UPPER(REPLACE(CONVERT(VARCHAR(12), NEWID()), '-', ''));
-- Ensure uniqueness per tenant before insert.

------------------------------------------------------------
-- 9) Seed (optional)
------------------------------------------------------------
-- INSERT INTO dbo.Tenants(Id, Name) VALUES (NEWID(), N'Demo Barbershop');
