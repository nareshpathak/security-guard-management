/*==============================================================================
  140_audit_tables.sql
  Audit trail (schema: aud)
  Spec: docs/prd/01-database.md §2.10

  aud.AuditLog is append-only. No UPDATE or DELETE is ever issued against it by
  application code; retention is handled by partition switching, not by deletes.
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('aud.AuditLog','U') IS NULL
CREATE TABLE aud.AuditLog (
    AuditID         BIGINT          IDENTITY(1,1) NOT NULL CONSTRAINT PK_aud_AuditLog PRIMARY KEY,
    CompanyID       INT             NULL,
    UserID          INT             NULL,
    TableName       NVARCHAR(150)   NOT NULL,
    RecordID        NVARCHAR(50)    NULL,
    [Action]        CHAR(1)         NOT NULL,      -- I / U / D
    OldValues       NVARCHAR(MAX)   NULL,          -- JSON
    NewValues       NVARCHAR(MAX)   NULL,          -- JSON
    ChangedAt       DATETIME2(0)    NOT NULL CONSTRAINT DF_aud_AuditLog_ChangedAt DEFAULT (SYSDATETIME()),
    IpAddress       NVARCHAR(45)    NULL,
    UserAgent       NVARCHAR(300)   NULL,
    TraceId         NVARCHAR(60)    NULL,
    CONSTRAINT CK_aud_AuditLog_Action CHECK ([Action] IN ('I','U','D')),
    CONSTRAINT CK_aud_AuditLog_OldJson CHECK (OldValues IS NULL OR ISJSON(OldValues) = 1),
    CONSTRAINT CK_aud_AuditLog_NewJson CHECK (NewValues IS NULL OR ISJSON(NewValues) = 1)
);
GO

IF OBJECT_ID('aud.ImpersonationLog','U') IS NULL
CREATE TABLE aud.ImpersonationLog (
    LogID            BIGINT         IDENTITY(1,1) NOT NULL CONSTRAINT PK_aud_ImpersonationLog PRIMARY KEY,
    SuperAdminUserID INT            NOT NULL,
    TargetCompanyID  INT            NOT NULL,
    TargetUserID     INT            NULL,
    StartedAt        DATETIME2(0)   NOT NULL CONSTRAINT DF_aud_ImpersonationLog_StartedAt DEFAULT (SYSDATETIME()),
    EndedAt          DATETIME2(0)   NULL,
    Reason           NVARCHAR(500)  NULL,
    IpAddress        NVARCHAR(45)   NULL,
    CONSTRAINT FK_aud_ImpersonationLog_SuperAdmin FOREIGN KEY (SuperAdminUserID) REFERENCES sec.Users (UserID),
    CONSTRAINT FK_aud_ImpersonationLog_Company    FOREIGN KEY (TargetCompanyID)  REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_aud_ImpersonationLog_TargetUser FOREIGN KEY (TargetUserID)     REFERENCES sec.Users (UserID)
);
GO

IF OBJECT_ID('aud.ApiRequestLog','U') IS NULL
CREATE TABLE aud.ApiRequestLog (
    LogID           BIGINT          IDENTITY(1,1) NOT NULL CONSTRAINT PK_aud_ApiRequestLog PRIMARY KEY,
    TraceId         NVARCHAR(60)    NULL,
    CompanyID       INT             NULL,
    UserID          INT             NULL,
    Method          NVARCHAR(10)    NOT NULL,
    Path            NVARCHAR(500)   NOT NULL,
    StatusCode      INT             NOT NULL,
    DurationMs      INT             NOT NULL,
    ErrorCode       NVARCHAR(60)    NULL,
    Platform        NVARCHAR(20)    NULL,
    AppVersion      NVARCHAR(20)    NULL,
    RequestedAt     DATETIME2(0)    NOT NULL CONSTRAINT DF_aud_ApiRequestLog_RequestedAt DEFAULT (SYSDATETIME())
);
GO

PRINT '140_audit_tables.sql  ->  OK  (3 tables)';
GO
