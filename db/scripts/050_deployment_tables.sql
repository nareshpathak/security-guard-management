/*==============================================================================
  050_deployment_tables.sql
  Deployment, movement, temporary events and daily turnout (schema: ops)
  Spec: docs/prd/01-database.md §2.6
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*-------------------------------------------------------------- DEPLOYMENT */
IF OBJECT_ID('ops.Deployment','U') IS NULL
CREATE TABLE ops.Deployment (
    DeploymentID      INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_Deployment PRIMARY KEY,
    CompanyID         INT           NOT NULL,
    BranchID          INT           NULL,
    UnitID            INT           NOT NULL,
    PostID            INT           NULL,
    EmpID             INT           NOT NULL,
    ShiftID           INT           NULL,
    DesignationID     INT           NULL,
    FromDate          DATE          NOT NULL,
    ToDate            DATE          NULL,
    IsReliever        BIT           NOT NULL CONSTRAINT DF_ops_Deployment_IsReliever DEFAULT (0),
    RelieverForEmpID  INT           NULL,
    Status            NVARCHAR(20)  NOT NULL CONSTRAINT DF_ops_Deployment_Status DEFAULT (N'Active'),
    Remark            NVARCHAR(500) NULL,
    IsApproved        BIT           NOT NULL CONSTRAINT DF_ops_Deployment_IsApproved DEFAULT (1),
    IsCancel          BIT           NOT NULL CONSTRAINT DF_ops_Deployment_IsCancel   DEFAULT (0),
    IsReject          BIT           NOT NULL CONSTRAINT DF_ops_Deployment_IsReject   DEFAULT (0),
    InsertDate        DATETIME2(0)  NOT NULL CONSTRAINT DF_ops_Deployment_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID      INT           NULL,
    UpdateDate        DATETIME2(0)  NULL,
    UpdateUserID      INT           NULL,
    CONSTRAINT FK_ops_Deployment_Company     FOREIGN KEY (CompanyID)        REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_Deployment_Branch      FOREIGN KEY (BranchID)         REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_ops_Deployment_Unit        FOREIGN KEY (UnitID)           REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_ops_Deployment_Post        FOREIGN KEY (PostID)           REFERENCES crm.UnitPost (PostID),
    CONSTRAINT FK_ops_Deployment_Employee    FOREIGN KEY (EmpID)            REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_ops_Deployment_Shift       FOREIGN KEY (ShiftID)          REFERENCES mst.Shift (ShiftID),
    CONSTRAINT FK_ops_Deployment_Designation FOREIGN KEY (DesignationID)    REFERENCES mst.Designation (DesignationID),
    CONSTRAINT FK_ops_Deployment_RelieverFor FOREIGN KEY (RelieverForEmpID) REFERENCES hr.Employee (EmpID),
    CONSTRAINT CK_ops_Deployment_Status CHECK (Status IN (N'Active',N'Moved',N'Ended')),
    CONSTRAINT CK_ops_Deployment_Dates  CHECK (ToDate IS NULL OR ToDate >= FromDate)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_ops_Deployment_Emp_Active' AND object_id=OBJECT_ID('ops.Deployment'))
    CREATE UNIQUE INDEX UX_ops_Deployment_Emp_Active
        ON ops.Deployment (CompanyID, EmpID, FromDate, ShiftID)
        WHERE Status = 'Active' AND IsCancel = 0;
GO

/*------------------------------------------------- INCREASE / DECREASE     */
IF OBJECT_ID('ops.DeploymentChange','U') IS NULL
CREATE TABLE ops.DeploymentChange (
    ChangeID        INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_DeploymentChange PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    UnitID          INT             NOT NULL,
    ChangeType      NVARCHAR(10)    NOT NULL,      -- Increase / Decrease
    Dated           DATE            NOT NULL,
    Timing          NVARCHAR(50)    NULL,
    Nop             INT             NOT NULL CONSTRAINT DF_ops_DeploymentChange_Nop DEFAULT (0),
    DesignationID   INT             NULL,
    ShiftID         INT             NULL,
    Remark          NVARCHAR(1000)  NULL,
    Status          NVARCHAR(20)    NOT NULL CONSTRAINT DF_ops_DeploymentChange_Status DEFAULT (N'Pending'),
    ApprovedBy      INT             NULL,
    ApprovedOn      DATETIME2(0)    NULL,
    IsApproved      BIT             NOT NULL CONSTRAINT DF_ops_DeploymentChange_IsApproved DEFAULT (0),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_ops_DeploymentChange_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_ops_DeploymentChange_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_DeploymentChange_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_ops_DeploymentChange_Company     FOREIGN KEY (CompanyID)     REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_DeploymentChange_Branch      FOREIGN KEY (BranchID)      REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_ops_DeploymentChange_Unit        FOREIGN KEY (UnitID)        REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_ops_DeploymentChange_Designation FOREIGN KEY (DesignationID) REFERENCES mst.Designation (DesignationID),
    CONSTRAINT FK_ops_DeploymentChange_Shift       FOREIGN KEY (ShiftID)       REFERENCES mst.Shift (ShiftID),
    CONSTRAINT CK_ops_DeploymentChange_Type   CHECK (ChangeType IN (N'Increase',N'Decrease')),
    CONSTRAINT CK_ops_DeploymentChange_Status CHECK (Status IN (N'Pending',N'Approved',N'Rejected',N'Applied'))
);
GO

/*---------------------------------------------------------------- MOVEMENT */
IF OBJECT_ID('ops.Movement','U') IS NULL
CREATE TABLE ops.Movement (
    MovementID      INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_Movement PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    EmpID           INT             NOT NULL,
    FromUnitID      INT             NULL,
    ToUnitID        INT             NULL,
    PostName        NVARCHAR(150)   NULL,
    MovementDate    DATE            NOT NULL,
    MovementTime    TIME(0)         NULL,
    InstructionBy   NVARCHAR(150)   NULL,
    Remark          NVARCHAR(1000)  NULL,
    IsApproved      BIT             NOT NULL CONSTRAINT DF_ops_Movement_IsApproved DEFAULT (0),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_ops_Movement_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_ops_Movement_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_Movement_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_ops_Movement_Company  FOREIGN KEY (CompanyID)  REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_Movement_Branch   FOREIGN KEY (BranchID)   REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_ops_Movement_Employee FOREIGN KEY (EmpID)      REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_ops_Movement_FromUnit FOREIGN KEY (FromUnitID) REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_ops_Movement_ToUnit   FOREIGN KEY (ToUnitID)   REFERENCES crm.Unit (UnitID)
);
GO

/*--------------------------------------------------------- TEMPORARY EVENT */
IF OBJECT_ID('ops.TemporaryEvent','U') IS NULL
CREATE TABLE ops.TemporaryEvent (
    EventID         INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_TemporaryEvent PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    UnitID          INT             NULL,
    ClientID        INT             NULL,
    TypeOfService   NVARCHAR(100)   NULL,
    ServiceTypeID   INT             NULL,
    StartDate       DATE            NOT NULL,
    EndDate         DATE            NULL,
    StartTime       TIME(0)         NULL,
    EndTime         TIME(0)         NULL,
    NOP             INT             NOT NULL CONSTRAINT DF_ops_TemporaryEvent_NOP DEFAULT (0),
    RatePerGuard    DECIMAL(18,2)   NULL,
    Remark          NVARCHAR(1000)  NULL,
    IsApproved      BIT             NOT NULL CONSTRAINT DF_ops_TemporaryEvent_IsApproved DEFAULT (0),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_ops_TemporaryEvent_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_ops_TemporaryEvent_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_TemporaryEvent_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_ops_TemporaryEvent_Company     FOREIGN KEY (CompanyID)     REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_TemporaryEvent_Branch      FOREIGN KEY (BranchID)      REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_ops_TemporaryEvent_Unit        FOREIGN KEY (UnitID)        REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_ops_TemporaryEvent_Client      FOREIGN KEY (ClientID)      REFERENCES crm.Client (ClientID),
    CONSTRAINT FK_ops_TemporaryEvent_ServiceType FOREIGN KEY (ServiceTypeID) REFERENCES mst.ServiceType (ServiceTypeID),
    CONSTRAINT CK_ops_TemporaryEvent_Dates CHECK (EndDate IS NULL OR EndDate >= StartDate)
);
GO

/*----------------------------------------------------------------- TURNOUT */
IF OBJECT_ID('ops.Turnout','U') IS NULL
CREATE TABLE ops.Turnout (
    TurnoutID       INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_Turnout PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    UnitID          INT             NOT NULL,
    TurnoutDate     DATE            NOT NULL,
    ShiftID         INT             NULL,
    RequiredNos     INT             NOT NULL CONSTRAINT DF_ops_Turnout_Required DEFAULT (0),
    PresentNos      INT             NOT NULL CONSTRAINT DF_ops_Turnout_Present  DEFAULT (0),
    AbsentNos       INT             NOT NULL CONSTRAINT DF_ops_Turnout_Absent   DEFAULT (0),
    RelieverNos     INT             NOT NULL CONSTRAINT DF_ops_Turnout_Reliever DEFAULT (0),
    VacantNos       AS (CASE WHEN RequiredNos - (PresentNos + RelieverNos) > 0
                             THEN RequiredNos - (PresentNos + RelieverNos) ELSE 0 END) PERSISTED,
    EnteredBy       INT             NULL,
    Remark          NVARCHAR(500)   NULL,
    IsCancel        BIT             NOT NULL CONSTRAINT DF_ops_Turnout_IsCancel   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_Turnout_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_ops_Turnout_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_Turnout_Branch  FOREIGN KEY (BranchID)  REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_ops_Turnout_Unit    FOREIGN KEY (UnitID)    REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_ops_Turnout_Shift   FOREIGN KEY (ShiftID)   REFERENCES mst.Shift (ShiftID)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_ops_Turnout_Unit_Date_Shift' AND object_id=OBJECT_ID('ops.Turnout'))
    CREATE UNIQUE INDEX UX_ops_Turnout_Unit_Date_Shift
        ON ops.Turnout (CompanyID, UnitID, TurnoutDate, ShiftID) WHERE IsCancel = 0;
GO

IF OBJECT_ID('ops.TurnoutDetail','U') IS NULL
CREATE TABLE ops.TurnoutDetail (
    TurnoutDetailID INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_TurnoutDetail PRIMARY KEY,
    TurnoutID       INT             NOT NULL,
    CompanyID       INT             NOT NULL,
    EmpID           INT             NOT NULL,
    EmpName         NVARCHAR(200)   NULL,
    Status          CHAR(2)         NOT NULL CONSTRAINT DF_ops_TurnoutDetail_Status DEFAULT ('P'),
    Remark          NVARCHAR(300)   NULL,
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_TurnoutDetail_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    CONSTRAINT FK_ops_TurnoutDetail_Turnout  FOREIGN KEY (TurnoutID) REFERENCES ops.Turnout (TurnoutID),
    CONSTRAINT FK_ops_TurnoutDetail_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_ops_TurnoutDetail_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT CK_ops_TurnoutDetail_Status CHECK (Status IN ('P','A','HD','WO','HO','LV','DS','RL')),
    CONSTRAINT UQ_ops_TurnoutDetail UNIQUE (TurnoutID, EmpID)
);
GO

PRINT '050_deployment_tables.sql  ->  OK  (6 tables)';
GO
