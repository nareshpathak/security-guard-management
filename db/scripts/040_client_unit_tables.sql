/*==============================================================================
  040_client_unit_tables.sql
  Clients, units (sites), sales and contracts (schema: crm)
  Spec: docs/prd/01-database.md §2.5
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*------------------------------------------------------------------ CLIENT */
IF OBJECT_ID('crm.Client','U') IS NULL
CREATE TABLE crm.Client (
    ClientID        INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_crm_Client PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    ClientName      NVARCHAR(200)   NOT NULL,
    ClientCode      NVARCHAR(30)    NULL,
    CompanyAddress  NVARCHAR(500)   NULL,
    CityID          INT             NULL,
    StateID         INT             NULL,
    Pin             NVARCHAR(10)    NULL,
    GSTIN           NVARCHAR(15)    NULL,
    PAN             NVARCHAR(10)    NULL,
    ContactPerson   NVARCHAR(150)   NULL,
    ContactNo       NVARCHAR(15)    NULL,
    Email           NVARCHAR(150)   NULL,
    IsActive        BIT             NOT NULL CONSTRAINT DF_crm_Client_IsActive   DEFAULT (1),
    IsExpired       BIT             NOT NULL CONSTRAINT DF_crm_Client_IsExpired  DEFAULT (0),
    IsApproved      BIT             NOT NULL CONSTRAINT DF_crm_Client_IsApproved DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_crm_Client_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_crm_Client_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_crm_Client_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_crm_Client_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_crm_Client_Branch  FOREIGN KEY (BranchID)  REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_crm_Client_City    FOREIGN KEY (CityID)    REFERENCES mst.City (CityID),
    CONSTRAINT FK_crm_Client_State   FOREIGN KEY (StateID)   REFERENCES mst.State (StateID)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_crm_Client_Company_Code' AND object_id = OBJECT_ID('crm.Client'))
    CREATE UNIQUE INDEX UX_crm_Client_Company_Code ON crm.Client (CompanyID, ClientCode) WHERE ClientCode IS NOT NULL AND IsCancel = 0;
GO

IF OBJECT_ID('crm.ClientContact','U') IS NULL
CREATE TABLE crm.ClientContact (
    ContactID       INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_crm_ClientContact PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    ClientID        INT             NOT NULL,
    ContactPerson   NVARCHAR(150)   NOT NULL,
    Designation     NVARCHAR(100)   NULL,
    MobileNo        NVARCHAR(15)    NULL,
    Email           NVARCHAR(150)   NULL,
    IsPrimary       BIT             NOT NULL CONSTRAINT DF_crm_ClientContact_IsPrimary DEFAULT (0),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_crm_ClientContact_IsCancel  DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_crm_ClientContact_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_crm_ClientContact_Client  FOREIGN KEY (ClientID)  REFERENCES crm.Client (ClientID),
    CONSTRAINT FK_crm_ClientContact_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID)
);
GO

/*-------------------------------------------------------------- UNIT / SITE */
IF OBJECT_ID('crm.Unit','U') IS NULL
CREATE TABLE crm.Unit (
    UnitID                INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_crm_Unit PRIMARY KEY,
    CompanyID             INT           NOT NULL,
    BranchID              INT           NULL,
    ClientID              INT           NOT NULL,
    UnitName              NVARCHAR(200) NOT NULL,
    UnitCode              NVARCHAR(30)  NULL,
    Address               NVARCHAR(500) NULL,
    CityID                INT           NULL,
    StateID               INT           NULL,
    Pin                   NVARCHAR(10)  NULL,
    Latitude              DECIMAL(10,7) NULL,
    Longitude             DECIMAL(10,7) NULL,
    GeofenceRadiusMeters  INT           NOT NULL CONSTRAINT DF_crm_Unit_Geofence DEFAULT (150),
    SupervisorEmpID       INT           NULL,
    AgreementNo           NVARCHAR(50)  NULL,
    AgreementExpDate      DATE          NULL,
    OrderNo               NVARCHAR(50)  NULL,
    OrderDate             DATE          NULL,
    OrderExpiryDate       DATE          NULL,
    WorkStartDate         DATE          NULL,
    BillingCycle          NVARCHAR(20)  NOT NULL CONSTRAINT DF_crm_Unit_BillingCycle DEFAULT (N'Monthly'),
    IsActive              BIT           NOT NULL CONSTRAINT DF_crm_Unit_IsActive   DEFAULT (1),
    IsApproved            BIT           NOT NULL CONSTRAINT DF_crm_Unit_IsApproved DEFAULT (1),
    IsCancel              BIT           NOT NULL CONSTRAINT DF_crm_Unit_IsCancel   DEFAULT (0),
    IsReject              BIT           NOT NULL CONSTRAINT DF_crm_Unit_IsReject   DEFAULT (0),
    InsertDate            DATETIME2(0)  NOT NULL CONSTRAINT DF_crm_Unit_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID          INT           NULL,
    UpdateDate            DATETIME2(0)  NULL,
    UpdateUserID          INT           NULL,
    CONSTRAINT FK_crm_Unit_Company    FOREIGN KEY (CompanyID)       REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_crm_Unit_Branch     FOREIGN KEY (BranchID)        REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_crm_Unit_Client     FOREIGN KEY (ClientID)        REFERENCES crm.Client (ClientID),
    CONSTRAINT FK_crm_Unit_City       FOREIGN KEY (CityID)          REFERENCES mst.City (CityID),
    CONSTRAINT FK_crm_Unit_State      FOREIGN KEY (StateID)         REFERENCES mst.State (StateID),
    CONSTRAINT FK_crm_Unit_Supervisor FOREIGN KEY (SupervisorEmpID) REFERENCES hr.Employee (EmpID),
    CONSTRAINT CK_crm_Unit_Latitude   CHECK (Latitude  IS NULL OR Latitude  BETWEEN -90  AND 90),
    CONSTRAINT CK_crm_Unit_Longitude  CHECK (Longitude IS NULL OR Longitude BETWEEN -180 AND 180),
    CONSTRAINT CK_crm_Unit_Geofence   CHECK (GeofenceRadiusMeters BETWEEN 10 AND 5000)
);
GO

IF OBJECT_ID('crm.UnitPost','U') IS NULL
CREATE TABLE crm.UnitPost (
    PostID            INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_crm_UnitPost PRIMARY KEY,
    CompanyID         INT           NOT NULL,
    UnitID            INT           NOT NULL,
    PostName          NVARCHAR(150) NOT NULL,
    DesignationID     INT           NULL,
    ShiftID           INT           NULL,
    RequiredStrength  INT           NOT NULL CONSTRAINT DF_crm_UnitPost_Required DEFAULT (1),
    RatePerGuard      DECIMAL(18,2) NOT NULL CONSTRAINT DF_crm_UnitPost_Rate     DEFAULT (0),
    IsArmed           BIT           NOT NULL CONSTRAINT DF_crm_UnitPost_IsArmed  DEFAULT (0),
    EffectiveFrom     DATE          NULL,
    EffectiveTo       DATE          NULL,
    IsActive          BIT           NOT NULL CONSTRAINT DF_crm_UnitPost_IsActive DEFAULT (1),
    IsCancel          BIT           NOT NULL CONSTRAINT DF_crm_UnitPost_IsCancel DEFAULT (0),
    InsertDate        DATETIME2(0)  NOT NULL CONSTRAINT DF_crm_UnitPost_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID      INT           NULL,
    UpdateDate        DATETIME2(0)  NULL,
    UpdateUserID      INT           NULL,
    CONSTRAINT FK_crm_UnitPost_Unit        FOREIGN KEY (UnitID)        REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_crm_UnitPost_Company     FOREIGN KEY (CompanyID)     REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_crm_UnitPost_Designation FOREIGN KEY (DesignationID) REFERENCES mst.Designation (DesignationID),
    CONSTRAINT FK_crm_UnitPost_Shift       FOREIGN KEY (ShiftID)       REFERENCES mst.Shift (ShiftID),
    CONSTRAINT CK_crm_UnitPost_Required    CHECK (RequiredStrength >= 0)
);
GO

IF OBJECT_ID('crm.UnitLocation','U') IS NULL
CREATE TABLE crm.UnitLocation (
    LocationID      INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_crm_UnitLocation PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    UnitID          INT             NOT NULL,
    LocationName    NVARCHAR(150)   NOT NULL,
    Latitude        DECIMAL(10,7)   NULL,
    Longitude       DECIMAL(10,7)   NULL,
    Description     NVARCHAR(500)   NULL,
    IsActive        BIT             NOT NULL CONSTRAINT DF_crm_UnitLocation_IsActive DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_crm_UnitLocation_IsCancel DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_crm_UnitLocation_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_crm_UnitLocation_Unit    FOREIGN KEY (UnitID)    REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_crm_UnitLocation_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT CK_crm_UnitLocation_Lat CHECK (Latitude  IS NULL OR Latitude  BETWEEN -90  AND 90),
    CONSTRAINT CK_crm_UnitLocation_Lng CHECK (Longitude IS NULL OR Longitude BETWEEN -180 AND 180)
);
GO

/*--------------------------------------------------------- CLIENT RELATION  */
IF OBJECT_ID('crm.ClientRelationVisit','U') IS NULL
CREATE TABLE crm.ClientRelationVisit (
    VisitID         INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_crm_ClientRelationVisit PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    UnitID          INT             NULL,
    ExecutiveEmpID  INT             NULL,
    ContactPerson   NVARCHAR(150)   NULL,
    MobileNo        NVARCHAR(15)    NULL,
    Dated           DATE            NOT NULL,
    Timing          NVARCHAR(50)    NULL,
    Remark          NVARCHAR(1000)  NULL,
    Latitude        DECIMAL(10,7)   NULL,
    Longitude       DECIMAL(10,7)   NULL,
    PhotoUrl        NVARCHAR(500)   NULL,
    IsCancel        BIT             NOT NULL CONSTRAINT DF_crm_ClientRelationVisit_IsCancel DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_crm_ClientRelationVisit_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_crm_ClientRelationVisit_Company   FOREIGN KEY (CompanyID)      REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_crm_ClientRelationVisit_Branch    FOREIGN KEY (BranchID)       REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_crm_ClientRelationVisit_Unit      FOREIGN KEY (UnitID)         REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_crm_ClientRelationVisit_Executive FOREIGN KEY (ExecutiveEmpID) REFERENCES hr.Employee (EmpID)
);
GO

/*---------------------------------------------------------------- SALES CRM */
IF OBJECT_ID('crm.SalesVisit','U') IS NULL
CREATE TABLE crm.SalesVisit (
    VisitID         INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_crm_SalesVisit PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    EmpID           INT             NULL,
    CompanyName     NVARCHAR(200)   NOT NULL,
    ContactPerson   NVARCHAR(150)   NULL,
    ContactNo       NVARCHAR(15)    NULL,
    Location        NVARCHAR(300)   NULL,
    Latitude        DECIMAL(10,7)   NULL,
    Longitude       DECIMAL(10,7)   NULL,
    Purpose         NVARCHAR(300)   NULL,
    Remark          NVARCHAR(1000)  NULL,
    VisitDate       DATE            NOT NULL,
    PhotoUrl        NVARCHAR(500)   NULL,
    IsCancel        BIT             NOT NULL CONSTRAINT DF_crm_SalesVisit_IsCancel DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_crm_SalesVisit_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_crm_SalesVisit_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_crm_SalesVisit_Branch   FOREIGN KEY (BranchID)  REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_crm_SalesVisit_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID)
);
GO

IF OBJECT_ID('crm.FollowUp','U') IS NULL
CREATE TABLE crm.FollowUp (
    FollowupID          INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_crm_FollowUp PRIMARY KEY,
    CompanyID           INT             NOT NULL,
    BranchID            INT             NULL,
    SalesVisitID        INT             NULL,
    EmpID               INT             NULL,
    CompanyName         NVARCHAR(200)   NOT NULL,
    ContactPerson       NVARCHAR(150)   NULL,
    ContactNo           NVARCHAR(15)    NULL,
    Location            NVARCHAR(300)   NULL,
    Purpose             NVARCHAR(300)   NULL,
    FollowupDate        DATE            NOT NULL,
    NextFollowupDate    DATE            NULL,
    Remark              NVARCHAR(1000)  NULL,
    StopFollow          BIT             NOT NULL CONSTRAINT DF_crm_FollowUp_StopFollow DEFAULT (0),
    IsCancel            BIT             NOT NULL CONSTRAINT DF_crm_FollowUp_IsCancel   DEFAULT (0),
    InsertDate          DATETIME2(0)    NOT NULL CONSTRAINT DF_crm_FollowUp_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID        INT             NULL,
    UpdateDate          DATETIME2(0)    NULL,
    UpdateUserID        INT             NULL,
    CONSTRAINT FK_crm_FollowUp_Company    FOREIGN KEY (CompanyID)    REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_crm_FollowUp_Branch     FOREIGN KEY (BranchID)     REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_crm_FollowUp_SalesVisit FOREIGN KEY (SalesVisitID) REFERENCES crm.SalesVisit (VisitID),
    CONSTRAINT FK_crm_FollowUp_Employee   FOREIGN KEY (EmpID)        REFERENCES hr.Employee (EmpID)
);
GO

/*---------------------------------------------------------------- CONTRACTS */
IF OBJECT_ID('crm.Contract','U') IS NULL
CREATE TABLE crm.Contract (
    ContractID      INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_crm_Contract PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    ClientID        INT             NULL,
    UnitID          INT             NULL,
    ContractType    NVARCHAR(20)    NOT NULL,      -- New / Renewal / Termination / Temporary
    Dated           DATE            NOT NULL,
    Nop             INT             NOT NULL CONSTRAINT DF_crm_Contract_Nop DEFAULT (0),
    Timing          NVARCHAR(50)    NULL,
    Remark          NVARCHAR(1000)  NULL,
    EffectiveFrom   DATE            NULL,
    EffectiveTo     DATE            NULL,
    Status          NVARCHAR(20)    NOT NULL CONSTRAINT DF_crm_Contract_Status DEFAULT (N'Pending'),
    ApprovedBy      INT             NULL,
    ApprovedOn      DATETIME2(0)    NULL,
    IsApproved      BIT             NOT NULL CONSTRAINT DF_crm_Contract_IsApproved DEFAULT (0),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_crm_Contract_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_crm_Contract_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_crm_Contract_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_crm_Contract_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_crm_Contract_Branch  FOREIGN KEY (BranchID)  REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_crm_Contract_Client  FOREIGN KEY (ClientID)  REFERENCES crm.Client (ClientID),
    CONSTRAINT FK_crm_Contract_Unit    FOREIGN KEY (UnitID)    REFERENCES crm.Unit (UnitID),
    CONSTRAINT CK_crm_Contract_Type   CHECK (ContractType IN (N'New',N'Renewal',N'Termination',N'Temporary')),
    CONSTRAINT CK_crm_Contract_Status CHECK (Status IN (N'Pending',N'Approved',N'Active',N'Expired',N'Terminated',N'Rejected'))
);
GO

PRINT '040_client_unit_tables.sql  ->  OK  (9 tables)';
GO
