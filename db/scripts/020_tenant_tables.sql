/*==============================================================================
  020_tenant_tables.sql
  Tenant / company tables (schema: org) and authentication (schema: sec)
  Spec: docs/prd/01-database.md §2.1 and §2.2

  FKs from sec.Users to hr.Employee and crm.Client are forward references and
  are created in 150_foreign_keys.sql.
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*==============================  org  ======================================*/

IF OBJECT_ID('org.Plan','U') IS NULL
CREATE TABLE org.[Plan] (
    PlanID              INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_org_Plan PRIMARY KEY,
    PlanName            NVARCHAR(100)   NOT NULL,
    MaxUsers            INT             NOT NULL CONSTRAINT DF_org_Plan_MaxUsers DEFAULT (25),
    MaxUnits            INT             NOT NULL CONSTRAINT DF_org_Plan_MaxUnits DEFAULT (10),
    PricePerUserMonth   DECIMAL(18,2)   NOT NULL CONSTRAINT DF_org_Plan_Price    DEFAULT (0),
    Features            NVARCHAR(MAX)   NULL,     -- JSON
    IsActive            BIT             NOT NULL CONSTRAINT DF_org_Plan_IsActive DEFAULT (1),
    IsCancel            BIT             NOT NULL CONSTRAINT DF_org_Plan_IsCancel DEFAULT (0),
    InsertDate          DATETIME2(0)    NOT NULL CONSTRAINT DF_org_Plan_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID        INT             NULL,
    UpdateDate          DATETIME2(0)    NULL,
    UpdateUserID        INT             NULL,
    CONSTRAINT UQ_org_Plan_Name UNIQUE (PlanName),
    CONSTRAINT CK_org_Plan_Features CHECK (Features IS NULL OR ISJSON(Features) = 1)
);
GO

IF OBJECT_ID('org.Company','U') IS NULL
CREATE TABLE org.Company (
    CompanyID       INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_org_Company PRIMARY KEY,
    CompanyName     NVARCHAR(200)   NOT NULL,
    CompanyCode     NVARCHAR(30)    NOT NULL,
    CompanyAddress  NVARCHAR(500)   NULL,
    CityID          INT             NULL,
    StateID         INT             NULL,
    Pin             NVARCHAR(10)    NULL,
    Mobile          NVARCHAR(15)    NULL,
    Email           NVARCHAR(150)   NULL,
    GSTIN           NVARCHAR(15)    NULL,
    PAN             NVARCHAR(10)    NULL,
    PFCode          NVARCHAR(30)    NULL,
    ESICCode        NVARCHAR(30)    NULL,
    LicenceNo       NVARCHAR(50)    NULL,          -- PSARA licence
    LicenceExpiry   DATE            NULL,
    LogoUrl         NVARCHAR(500)   NULL,
    ThemeColor      NVARCHAR(7)     NULL,
    TimeZone        NVARCHAR(50)    NOT NULL CONSTRAINT DF_org_Company_TimeZone  DEFAULT (N'India Standard Time'),
    PlanID          INT             NULL,
    UserCount       INT             NOT NULL CONSTRAINT DF_org_Company_UserCount DEFAULT (0),
    MaxUsers        INT             NOT NULL CONSTRAINT DF_org_Company_MaxUsers  DEFAULT (25),
    LoginCount      INT             NOT NULL CONSTRAINT DF_org_Company_LoginCount DEFAULT (0),
    IsExpired       BIT             NOT NULL CONSTRAINT DF_org_Company_IsExpired DEFAULT (0),
    ExpiryDate      DATE            NULL,
    IsActive        BIT             NOT NULL CONSTRAINT DF_org_Company_IsActive  DEFAULT (1),
    IsApproved      BIT             NOT NULL CONSTRAINT DF_org_Company_IsApproved DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_org_Company_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_org_Company_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_org_Company_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_org_Company_Plan  FOREIGN KEY (PlanID)  REFERENCES org.[Plan] (PlanID),
    CONSTRAINT FK_org_Company_City  FOREIGN KEY (CityID)  REFERENCES mst.City (CityID),
    CONSTRAINT FK_org_Company_State FOREIGN KEY (StateID) REFERENCES mst.State (StateID),
    CONSTRAINT UQ_org_Company_Code  UNIQUE (CompanyCode)
);
GO

IF OBJECT_ID('org.Branch','U') IS NULL
CREATE TABLE org.Branch (
    BranchID        INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_org_Branch PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchName      NVARCHAR(150)   NOT NULL,
    BranchCode      NVARCHAR(30)    NULL,
    Address         NVARCHAR(500)   NULL,
    CityID          INT             NULL,
    StateID         INT             NULL,
    RegionID        INT             NULL,
    AreaID          INT             NULL,
    Pin             NVARCHAR(10)    NULL,
    ContactPerson   NVARCHAR(150)   NULL,
    Mobile          NVARCHAR(15)    NULL,
    Email           NVARCHAR(150)   NULL,
    IsHeadOffice    BIT             NOT NULL CONSTRAINT DF_org_Branch_IsHeadOffice DEFAULT (0),
    IsActive        BIT             NOT NULL CONSTRAINT DF_org_Branch_IsActive   DEFAULT (1),
    IsApproved      BIT             NOT NULL CONSTRAINT DF_org_Branch_IsApproved DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_org_Branch_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_org_Branch_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_org_Branch_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_org_Branch_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_org_Branch_City    FOREIGN KEY (CityID)    REFERENCES mst.City (CityID),
    CONSTRAINT FK_org_Branch_State   FOREIGN KEY (StateID)   REFERENCES mst.State (StateID),
    CONSTRAINT FK_org_Branch_Region  FOREIGN KEY (RegionID)  REFERENCES mst.Region (RegionID),
    CONSTRAINT FK_org_Branch_Area    FOREIGN KEY (AreaID)    REFERENCES mst.Area (AreaID),
    CONSTRAINT UQ_org_Branch_Code    UNIQUE (CompanyID, BranchName)
);
GO

IF OBJECT_ID('org.CompanyModule','U') IS NULL
CREATE TABLE org.CompanyModule (
    CompanyID       INT             NOT NULL,
    ModuleCode      NVARCHAR(20)    NOT NULL,      -- M1 .. M16
    IsEnabled       BIT             NOT NULL CONSTRAINT DF_org_CompanyModule_IsEnabled DEFAULT (1),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_org_CompanyModule_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT PK_org_CompanyModule PRIMARY KEY (CompanyID, ModuleCode),
    CONSTRAINT FK_org_CompanyModule_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID)
);
GO

IF OBJECT_ID('org.CompanySetting','U') IS NULL
CREATE TABLE org.CompanySetting (
    CompanyID       INT             NOT NULL,
    SettingKey      NVARCHAR(100)   NOT NULL,      -- GeofenceRadiusMeters, SelfieMandatory, AttendanceCutOff...
    SettingValue    NVARCHAR(500)   NULL,
    DataType        NVARCHAR(20)    NOT NULL CONSTRAINT DF_org_CompanySetting_DataType DEFAULT (N'string'),
    Description     NVARCHAR(300)   NULL,
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_org_CompanySetting_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT PK_org_CompanySetting PRIMARY KEY (CompanyID, SettingKey),
    CONSTRAINT FK_org_CompanySetting_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID)
);
GO

/*==============================  sec  ======================================*/

IF OBJECT_ID('sec.Role','U') IS NULL
CREATE TABLE sec.Role (
    RoleID          INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_sec_Role PRIMARY KEY,
    CompanyID       INT             NULL,          -- NULL = system role available to all tenants
    RoleCode        NVARCHAR(30)    NOT NULL,      -- SUPER_ADMIN, COMPANY_ADMIN, ... CLIENT
    RoleName        NVARCHAR(100)   NOT NULL,
    Description     NVARCHAR(300)   NULL,
    IsSystem        BIT             NOT NULL CONSTRAINT DF_sec_Role_IsSystem DEFAULT (0),
    IsActive        BIT             NOT NULL CONSTRAINT DF_sec_Role_IsActive DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_sec_Role_IsCancel DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_sec_Role_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_sec_Role_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_sec_Role_Code' AND object_id = OBJECT_ID('sec.Role'))
    CREATE UNIQUE INDEX UX_sec_Role_Code ON sec.Role (RoleCode) WHERE CompanyID IS NULL;
GO

IF OBJECT_ID('sec.Permission','U') IS NULL
CREATE TABLE sec.Permission (
    PermissionID    INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_sec_Permission PRIMARY KEY,
    Module          NVARCHAR(10)    NOT NULL,      -- M1 .. M16
    Code            NVARCHAR(80)    NOT NULL,      -- M8.Attendance.Approve
    Name            NVARCHAR(150)   NOT NULL,
    Entity          NVARCHAR(50)    NULL,
    [Action]        NVARCHAR(30)    NULL,
    SortOrder       INT             NOT NULL CONSTRAINT DF_sec_Permission_SortOrder DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_sec_Permission_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT UQ_sec_Permission_Code UNIQUE (Code)
);
GO

IF OBJECT_ID('sec.RolePermission','U') IS NULL
CREATE TABLE sec.RolePermission (
    RoleID          INT             NOT NULL,
    PermissionID    INT             NOT NULL,
    CanView         BIT             NOT NULL CONSTRAINT DF_sec_RolePermission_View    DEFAULT (0),
    CanCreate       BIT             NOT NULL CONSTRAINT DF_sec_RolePermission_Create  DEFAULT (0),
    CanEdit         BIT             NOT NULL CONSTRAINT DF_sec_RolePermission_Edit    DEFAULT (0),
    CanDelete       BIT             NOT NULL CONSTRAINT DF_sec_RolePermission_Delete  DEFAULT (0),
    CanApprove      BIT             NOT NULL CONSTRAINT DF_sec_RolePermission_Approve DEFAULT (0),
    CanExport       BIT             NOT NULL CONSTRAINT DF_sec_RolePermission_Export  DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_sec_RolePermission_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT PK_sec_RolePermission PRIMARY KEY (RoleID, PermissionID),
    CONSTRAINT FK_sec_RolePermission_Role       FOREIGN KEY (RoleID)       REFERENCES sec.Role (RoleID),
    CONSTRAINT FK_sec_RolePermission_Permission FOREIGN KEY (PermissionID) REFERENCES sec.Permission (PermissionID)
);
GO

IF OBJECT_ID('sec.Users','U') IS NULL
CREATE TABLE sec.Users (
    UserID              INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_sec_Users PRIMARY KEY,
    CompanyID           INT             NULL,      -- NULL only for SUPER_ADMIN
    BranchID            INT             NULL,
    EmpID               INT             NULL,      -- FK added in 150_foreign_keys.sql
    ClientID            INT             NULL,      -- FK added in 150_foreign_keys.sql
    UserName            NVARCHAR(100)   NOT NULL,
    MobileNo            NVARCHAR(15)    NOT NULL,
    EmailID             NVARCHAR(150)   NULL,
    PasswordHash        NVARCHAR(500)   NULL,
    PasswordSalt        NVARCHAR(200)   NULL,
    LegacyPasswordHash  NVARCHAR(500)   NULL,
    MustChangePassword  BIT             NOT NULL CONSTRAINT DF_sec_Users_MustChangePassword DEFAULT (0),
    LoginType           INT             NULL,
    RoleID              INT             NOT NULL,
    DeviceID            NVARCHAR(200)   NULL,
    DeviceModel         NVARCHAR(120)   NULL,
    FcmToken            NVARCHAR(500)   NULL,
    PhotoUrl            NVARCHAR(500)   NULL,
    IsActive            BIT             NOT NULL CONSTRAINT DF_sec_Users_IsActive    DEFAULT (1),
    IsLocked            BIT             NOT NULL CONSTRAINT DF_sec_Users_IsLocked    DEFAULT (0),
    FailedLoginCount    INT             NOT NULL CONSTRAINT DF_sec_Users_FailedLogin DEFAULT (0),
    LockedUntil         DATETIME2(0)    NULL,
    LastLoginAt         DATETIME2(0)    NULL,
    ExpiresOn           DATE            NULL,
    IsApproved          BIT             NOT NULL CONSTRAINT DF_sec_Users_IsApproved DEFAULT (1),
    IsCancel            BIT             NOT NULL CONSTRAINT DF_sec_Users_IsCancel   DEFAULT (0),
    IsReject            BIT             NOT NULL CONSTRAINT DF_sec_Users_IsReject   DEFAULT (0),
    InsertDate          DATETIME2(0)    NOT NULL CONSTRAINT DF_sec_Users_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID        INT             NULL,
    UpdateDate          DATETIME2(0)    NULL,
    UpdateUserID        INT             NULL,
    CONSTRAINT FK_sec_Users_Company   FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_sec_Users_Branch    FOREIGN KEY (BranchID)  REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_sec_Users_Role      FOREIGN KEY (RoleID)    REFERENCES sec.Role (RoleID),
    CONSTRAINT FK_sec_Users_LoginType FOREIGN KEY (LoginType) REFERENCES mst.LoginType (LoginTypeID)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_sec_Users_Company_UserName' AND object_id = OBJECT_ID('sec.Users'))
    CREATE UNIQUE INDEX UX_sec_Users_Company_UserName ON sec.Users (CompanyID, UserName) WHERE IsCancel = 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_sec_Users_Company_Mobile' AND object_id = OBJECT_ID('sec.Users'))
    CREATE UNIQUE INDEX UX_sec_Users_Company_Mobile ON sec.Users (CompanyID, MobileNo) WHERE IsCancel = 0;
GO

IF OBJECT_ID('sec.UserBranch','U') IS NULL
CREATE TABLE sec.UserBranch (
    UserID          INT             NOT NULL,
    BranchID        INT             NOT NULL,
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_sec_UserBranch_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    CONSTRAINT PK_sec_UserBranch PRIMARY KEY (UserID, BranchID),
    CONSTRAINT FK_sec_UserBranch_User   FOREIGN KEY (UserID)   REFERENCES sec.Users (UserID),
    CONSTRAINT FK_sec_UserBranch_Branch FOREIGN KEY (BranchID) REFERENCES org.Branch (BranchID)
);
GO

IF OBJECT_ID('sec.RefreshToken','U') IS NULL
CREATE TABLE sec.RefreshToken (
    TokenID                 BIGINT          IDENTITY(1,1) NOT NULL CONSTRAINT PK_sec_RefreshToken PRIMARY KEY,
    UserID                  INT             NOT NULL,
    TokenHash               NVARCHAR(200)   NOT NULL,
    ExpiresAt               DATETIME2(0)    NOT NULL,
    RevokedAt               DATETIME2(0)    NULL,
    ReplacedByTokenHash     NVARCHAR(200)   NULL,
    CreatedByIp             NVARCHAR(45)    NULL,
    DeviceID                NVARCHAR(200)   NULL,
    InsertDate              DATETIME2(0)    NOT NULL CONSTRAINT DF_sec_RefreshToken_InsertDate DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_sec_RefreshToken_User FOREIGN KEY (UserID) REFERENCES sec.Users (UserID)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_sec_RefreshToken_Hash' AND object_id = OBJECT_ID('sec.RefreshToken'))
    CREATE INDEX IX_sec_RefreshToken_Hash ON sec.RefreshToken (TokenHash) INCLUDE (UserID, ExpiresAt, RevokedAt);
GO

IF OBJECT_ID('sec.LoginLog','U') IS NULL
CREATE TABLE sec.LoginLog (
    LoginLogID      BIGINT          IDENTITY(1,1) NOT NULL CONSTRAINT PK_sec_LoginLog PRIMARY KEY,
    CompanyID       INT             NULL,
    UserID          INT             NULL,
    LoginAt         DATETIME2(0)    NOT NULL CONSTRAINT DF_sec_LoginLog_LoginAt DEFAULT (SYSDATETIME()),
    LogoutAt        DATETIME2(0)    NULL,
    IpAddress       NVARCHAR(45)    NULL,
    DeviceID        NVARCHAR(200)   NULL,
    AppVersion      NVARCHAR(20)    NULL,
    Platform        NVARCHAR(20)    NULL,          -- Android / iOS / Web
    IsSuccess       BIT             NOT NULL CONSTRAINT DF_sec_LoginLog_IsSuccess DEFAULT (1),
    FailReason      NVARCHAR(200)   NULL,
    CONSTRAINT FK_sec_LoginLog_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_sec_LoginLog_User    FOREIGN KEY (UserID)    REFERENCES sec.Users (UserID)
);
GO

IF OBJECT_ID('sec.Otp','U') IS NULL
CREATE TABLE sec.Otp (
    OtpID           BIGINT          IDENTITY(1,1) NOT NULL CONSTRAINT PK_sec_Otp PRIMARY KEY,
    MobileNo        NVARCHAR(15)    NOT NULL,
    OtpHash         NVARCHAR(200)   NOT NULL,
    Purpose         NVARCHAR(30)    NOT NULL,      -- Login / ForgotPassword / DeviceChange
    ExpiresAt       DATETIME2(0)    NOT NULL,
    AttemptCount    INT             NOT NULL CONSTRAINT DF_sec_Otp_AttemptCount DEFAULT (0),
    ConsumedAt      DATETIME2(0)    NULL,
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_sec_Otp_InsertDate DEFAULT (SYSDATETIME()),
    CONSTRAINT CK_sec_Otp_Purpose CHECK (Purpose IN (N'Login',N'ForgotPassword',N'DeviceChange',N'Register'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_sec_Otp_Mobile' AND object_id = OBJECT_ID('sec.Otp'))
    CREATE INDEX IX_sec_Otp_Mobile ON sec.Otp (MobileNo, Purpose, ExpiresAt DESC);
GO

PRINT '020_tenant_tables.sql  ->  OK  (5 org + 8 sec = 13 tables)';
GO
