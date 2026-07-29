/*==============================================================================
  090_incident_complaint_tables.sql
  Incidents, field reports, complaints and gate pass (schema: ops)
  Spec: docs/prd/01-database.md §2.6
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*----------------------------------------------------------------- INCIDENT */
IF OBJECT_ID('ops.Incident','U') IS NULL
CREATE TABLE ops.Incident (
    IncidentID      INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_Incident PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    UnitID          INT             NULL,
    EmpID           INT             NULL,
    BeltNo          NVARCHAR(30)    NULL,
    FullName        NVARCHAR(200)   NULL,
    IncidentTypeID  INT             NULL,
    IncidentDate    DATE            NOT NULL,
    IncidentTime    TIME(0)         NULL,
    Severity        TINYINT         NOT NULL CONSTRAINT DF_ops_Incident_Severity DEFAULT (2),
    Remark          NVARCHAR(MAX)   NULL,
    ActionTaken     NVARCHAR(MAX)   NULL,
    PhotoUrl        NVARCHAR(500)   NULL,
    Latitude        DECIMAL(10,7)   NULL,
    Longitude       DECIMAL(10,7)   NULL,
    ReportedBy      INT             NULL,
    IsClosed        BIT             NOT NULL CONSTRAINT DF_ops_Incident_IsClosed DEFAULT (0),
    ClosedOn        DATETIME2(0)    NULL,
    ClientRequestId UNIQUEIDENTIFIER NULL,
    IsCancel        BIT             NOT NULL CONSTRAINT DF_ops_Incident_IsCancel   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_Incident_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_ops_Incident_Company    FOREIGN KEY (CompanyID)      REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_Incident_Branch     FOREIGN KEY (BranchID)       REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_ops_Incident_Unit       FOREIGN KEY (UnitID)         REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_ops_Incident_Employee   FOREIGN KEY (EmpID)          REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_ops_Incident_Type       FOREIGN KEY (IncidentTypeID) REFERENCES mst.IncidentType (IncidentTypeID),
    CONSTRAINT FK_ops_Incident_ReportedBy FOREIGN KEY (ReportedBy)     REFERENCES sec.Users (UserID),
    CONSTRAINT CK_ops_Incident_Severity CHECK (Severity BETWEEN 1 AND 4)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_ops_Incident_ClientRequestId' AND object_id=OBJECT_ID('ops.Incident'))
    CREATE UNIQUE INDEX UX_ops_Incident_ClientRequestId
        ON ops.Incident (ClientRequestId) WHERE ClientRequestId IS NOT NULL;
GO

/*------------------------------------------------------------- FIELD REPORT */
IF OBJECT_ID('ops.FieldReport','U') IS NULL
CREATE TABLE ops.FieldReport (
    ReportID        INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_FieldReport PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    UnitID          INT             NOT NULL,
    SupervisorEmpID INT             NULL,
    Createdate      DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_FieldReport_Createdate DEFAULT (SYSDATETIME()),
    ContactPerson   NVARCHAR(150)   NULL,
    Remark          NVARCHAR(MAX)   NULL,
    Latitude        DECIMAL(10,7)   NULL,
    Longitude       DECIMAL(10,7)   NULL,
    PhotoUrl        NVARCHAR(500)   NULL,
    ClientRequestId UNIQUEIDENTIFIER NULL,
    IsCancel        BIT             NOT NULL CONSTRAINT DF_ops_FieldReport_IsCancel   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_FieldReport_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_ops_FieldReport_Company    FOREIGN KEY (CompanyID)       REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_FieldReport_Branch     FOREIGN KEY (BranchID)        REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_ops_FieldReport_Unit       FOREIGN KEY (UnitID)          REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_ops_FieldReport_Supervisor FOREIGN KEY (SupervisorEmpID) REFERENCES hr.Employee (EmpID)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_ops_FieldReport_ClientRequestId' AND object_id=OBJECT_ID('ops.FieldReport'))
    CREATE UNIQUE INDEX UX_ops_FieldReport_ClientRequestId
        ON ops.FieldReport (ClientRequestId) WHERE ClientRequestId IS NOT NULL;
GO

IF OBJECT_ID('ops.FieldReportDetail','U') IS NULL
CREATE TABLE ops.FieldReportDetail (
    DetailID        INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_FieldReportDetail PRIMARY KEY,
    ReportID        INT             NOT NULL,
    CompanyID       INT             NOT NULL,
    EmpID           INT             NULL,
    Name            NVARCHAR(200)   NULL,
    DesignationName NVARCHAR(100)   NULL,
    Joindate        DATE            NULL,
    Photo           NVARCHAR(500)   NULL,
    Remark          NVARCHAR(1000)  NULL,
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_FieldReportDetail_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    CONSTRAINT FK_ops_FieldReportDetail_Report   FOREIGN KEY (ReportID)  REFERENCES ops.FieldReport (ReportID),
    CONSTRAINT FK_ops_FieldReportDetail_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_FieldReportDetail_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID)
);
GO

/*---------------------------------------------------------------- COMPLAINT */
IF OBJECT_ID('ops.Complaint','U') IS NULL
CREATE TABLE ops.Complaint (
    ComplaintID      INT            IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_Complaint PRIMARY KEY,
    CompanyID        INT            NOT NULL,
    BranchID         INT            NULL,
    UnitID           INT            NULL,
    ClientID         INT            NULL,
    RaisedByUserID   INT            NULL,
    ComplaintTypeID  INT            NULL,
    Complainttype    NVARCHAR(100)  NULL,          -- denormalised label, matches legacy DTO
    Description      NVARCHAR(MAX)  NOT NULL,
    PhotoUrl         NVARCHAR(500)  NULL,
    AssignedToEmpID  INT            NULL,
    DueOn            DATETIME2(0)   NULL,
    Status           NVARCHAR(20)   NOT NULL CONSTRAINT DF_ops_Complaint_Status   DEFAULT (N'Open'),
    IsClosed         BIT            NOT NULL CONSTRAINT DF_ops_Complaint_IsClosed DEFAULT (0),
    ClosedOn         DATETIME2(0)   NULL,
    ClosureRemark    NVARCHAR(1000) NULL,
    IsClientVisible  BIT            NOT NULL CONSTRAINT DF_ops_Complaint_IsClientVisible DEFAULT (1),
    IsCancel         BIT            NOT NULL CONSTRAINT DF_ops_Complaint_IsCancel   DEFAULT (0),
    InsertDate       DATETIME2(0)   NOT NULL CONSTRAINT DF_ops_Complaint_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID     INT            NULL,
    UpdateDate       DATETIME2(0)   NULL,
    UpdateUserID     INT            NULL,
    CONSTRAINT FK_ops_Complaint_Company    FOREIGN KEY (CompanyID)       REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_Complaint_Branch     FOREIGN KEY (BranchID)        REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_ops_Complaint_Unit       FOREIGN KEY (UnitID)          REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_ops_Complaint_Client     FOREIGN KEY (ClientID)        REFERENCES crm.Client (ClientID),
    CONSTRAINT FK_ops_Complaint_RaisedBy   FOREIGN KEY (RaisedByUserID)  REFERENCES sec.Users (UserID),
    CONSTRAINT FK_ops_Complaint_Type       FOREIGN KEY (ComplaintTypeID) REFERENCES mst.ComplaintType (ComplaintTypeID),
    CONSTRAINT FK_ops_Complaint_AssignedTo FOREIGN KEY (AssignedToEmpID) REFERENCES hr.Employee (EmpID),
    CONSTRAINT CK_ops_Complaint_Status CHECK (Status IN (N'Open',N'Assigned',N'InProgress',N'Closed',N'Rejected'))
);
GO

IF OBJECT_ID('ops.ComplaintHistory','U') IS NULL
CREATE TABLE ops.ComplaintHistory (
    HistoryID       INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_ComplaintHistory PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    ComplaintID     INT             NOT NULL,
    Status          NVARCHAR(20)    NOT NULL,
    Remark          NVARCHAR(1000)  NULL,
    ChangedBy       INT             NULL,
    ChangedOn       DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_ComplaintHistory_ChangedOn DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_ops_ComplaintHistory_Company   FOREIGN KEY (CompanyID)   REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_ComplaintHistory_Complaint FOREIGN KEY (ComplaintID) REFERENCES ops.Complaint (ComplaintID),
    CONSTRAINT FK_ops_ComplaintHistory_ChangedBy FOREIGN KEY (ChangedBy)   REFERENCES sec.Users (UserID)
);
GO

/*---------------------------------------------------------------- GATE PASS */
IF OBJECT_ID('ops.GatePass','U') IS NULL
CREATE TABLE ops.GatePass (
    GatePassID      INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_GatePass PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    UnitID          INT             NOT NULL,
    Dated           DATE            NOT NULL CONSTRAINT DF_ops_GatePass_Dated DEFAULT (CAST(SYSDATETIME() AS DATE)),
    Name            NVARCHAR(200)   NOT NULL,
    MobileNo        NVARCHAR(15)    NULL,
    Purpose         NVARCHAR(300)   NULL,
    WhomToMeet      NVARCHAR(200)   NULL,
    VehicleNo       NVARCHAR(30)    NULL,
    MaterialDetails NVARCHAR(1000)  NULL,
    VisitorImage    NVARCHAR(500)   NULL,
    InTime          DATETIME2(0)    NULL,
    OutTime         DATETIME2(0)    NULL,
    EnteredByEmpID  INT             NULL,
    ClientRequestId UNIQUEIDENTIFIER NULL,
    IsCancel        BIT             NOT NULL CONSTRAINT DF_ops_GatePass_IsCancel   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_GatePass_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_ops_GatePass_Company   FOREIGN KEY (CompanyID)      REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_GatePass_Branch    FOREIGN KEY (BranchID)       REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_ops_GatePass_Unit      FOREIGN KEY (UnitID)         REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_ops_GatePass_EnteredBy FOREIGN KEY (EnteredByEmpID) REFERENCES hr.Employee (EmpID),
    CONSTRAINT CK_ops_GatePass_Times CHECK (OutTime IS NULL OR InTime IS NULL OR OutTime >= InTime)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_ops_GatePass_ClientRequestId' AND object_id=OBJECT_ID('ops.GatePass'))
    CREATE UNIQUE INDEX UX_ops_GatePass_ClientRequestId
        ON ops.GatePass (ClientRequestId) WHERE ClientRequestId IS NOT NULL;
GO

PRINT '090_incident_complaint_tables.sql  ->  OK  (6 tables)';
GO
