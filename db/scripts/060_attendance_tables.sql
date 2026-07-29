/*==============================================================================
  060_attendance_tables.sql
  Attendance: the core transactional table, its monthly rollup and the
  table-valued parameter used by the mobile offline sync batch.
  Spec: docs/prd/01-database.md §2.6 ; docs/prd/02-api.md §3.6
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*--------------------------------------------------------------- ATTENDANCE */
IF OBJECT_ID('ops.Attendance','U') IS NULL
CREATE TABLE ops.Attendance (
    AttendanceID       BIGINT         IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_Attendance PRIMARY KEY,
    CompanyID          INT            NOT NULL,
    BranchID           INT            NULL,
    UnitID             INT            NOT NULL,
    PostID             INT            NULL,
    EmpID              INT            NOT NULL,
    ShiftID            INT            NULL,
    AttendanceDate     DATE           NOT NULL,

    InTime             DATETIME2(0)   NULL,
    OutTime            DATETIME2(0)   NULL,
    InLatitude         DECIMAL(10,7)  NULL,
    InLongitude        DECIMAL(10,7)  NULL,
    OutLatitude        DECIMAL(10,7)  NULL,
    OutLongitude       DECIMAL(10,7)  NULL,
    InDistanceMeters   INT            NULL,      -- set by trigger, never by the client
    OutDistanceMeters  INT            NULL,      -- set by trigger, never by the client
    InSelfieUrl        NVARCHAR(500)  NULL,
    OutSelfieUrl       NVARCHAR(500)  NULL,

    Status             CHAR(2)        NOT NULL CONSTRAINT DF_ops_Attendance_Status DEFAULT ('P'),
    WorkedHours        DECIMAL(5,2)   NULL,
    OtHours            DECIMAL(5,2)   NOT NULL CONSTRAINT DF_ops_Attendance_OtHours DEFAULT (0),
    Source             TINYINT        NOT NULL CONSTRAINT DF_ops_Attendance_Source  DEFAULT (1),  -- 1 SelfPunch 2 Supervisor 3 Biometric 4 Import

    ClientRequestId    UNIQUEIDENTIFIER NULL,    -- idempotency key from the mobile outbox
    IsOffline          BIT            NOT NULL CONSTRAINT DF_ops_Attendance_IsOffline DEFAULT (0),
    ClientPunchAt      DATETIME2(0)   NULL,      -- when the guard actually punched, not when it synced
    SyncedAt           DATETIME2(0)   NULL,
    IsMockLocation     BIT            NOT NULL CONSTRAINT DF_ops_Attendance_IsMock   DEFAULT (0),

    ApprovalStatus     TINYINT        NOT NULL CONSTRAINT DF_ops_Attendance_ApprovalStatus DEFAULT (0), -- 0 Pending 1 Approved 2 Rejected
    ApprovedBy         INT            NULL,
    ApprovedOn         DATETIME2(0)   NULL,
    RejectReason       NVARCHAR(300)  NULL,

    DeviceID           NVARCHAR(200)  NULL,
    AppVersion         NVARCHAR(20)   NULL,
    Remark             NVARCHAR(500)  NULL,

    IsCancel           BIT            NOT NULL CONSTRAINT DF_ops_Attendance_IsCancel   DEFAULT (0),
    InsertDate         DATETIME2(0)   NOT NULL CONSTRAINT DF_ops_Attendance_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID       INT            NULL,
    UpdateDate         DATETIME2(0)   NULL,
    UpdateUserID       INT            NULL,

    CONSTRAINT FK_ops_Attendance_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_Attendance_Branch   FOREIGN KEY (BranchID)  REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_ops_Attendance_Unit     FOREIGN KEY (UnitID)    REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_ops_Attendance_Post     FOREIGN KEY (PostID)    REFERENCES crm.UnitPost (PostID),
    CONSTRAINT FK_ops_Attendance_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_ops_Attendance_Shift    FOREIGN KEY (ShiftID)   REFERENCES mst.Shift (ShiftID),
    CONSTRAINT CK_ops_Attendance_Status   CHECK (Status IN ('P','A','HD','WO','HO','LV','DS')),
    CONSTRAINT CK_ops_Attendance_Approval CHECK (ApprovalStatus IN (0,1,2)),
    CONSTRAINT CK_ops_Attendance_Source   CHECK (Source IN (1,2,3,4)),
    CONSTRAINT CK_ops_Attendance_InLat    CHECK (InLatitude   IS NULL OR InLatitude   BETWEEN -90  AND 90),
    CONSTRAINT CK_ops_Attendance_InLng    CHECK (InLongitude  IS NULL OR InLongitude  BETWEEN -180 AND 180),
    CONSTRAINT CK_ops_Attendance_OutLat   CHECK (OutLatitude  IS NULL OR OutLatitude  BETWEEN -90  AND 90),
    CONSTRAINT CK_ops_Attendance_OutLng   CHECK (OutLongitude IS NULL OR OutLongitude BETWEEN -180 AND 180),
    CONSTRAINT CK_ops_Attendance_Times    CHECK (OutTime IS NULL OR InTime IS NULL OR OutTime >= InTime)
);
GO

-- One punch row per employee / date / shift.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_ops_Attendance_Emp_Date_Shift' AND object_id=OBJECT_ID('ops.Attendance'))
    CREATE UNIQUE INDEX UX_ops_Attendance_Emp_Date_Shift
        ON ops.Attendance (CompanyID, EmpID, AttendanceDate, ShiftID) WHERE IsCancel = 0;
GO

-- Offline replays must be idempotent on the client-generated request id.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_ops_Attendance_ClientRequestId' AND object_id=OBJECT_ID('ops.Attendance'))
    CREATE UNIQUE INDEX UX_ops_Attendance_ClientRequestId
        ON ops.Attendance (ClientRequestId) WHERE ClientRequestId IS NOT NULL;
GO

/*----------------------------------------------------- MONTHLY ROLLUP      */
IF OBJECT_ID('ops.AttendanceSummary','U') IS NULL
CREATE TABLE ops.AttendanceSummary (
    SummaryID       INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_AttendanceSummary PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    UnitID          INT             NULL,
    EmpID           INT             NOT NULL,
    MonthYear       CHAR(7)         NOT NULL,      -- 'YYYY-MM'
    PresentDays     DECIMAL(5,1)    NOT NULL CONSTRAINT DF_ops_AttendanceSummary_Present  DEFAULT (0),
    AbsentDays      DECIMAL(5,1)    NOT NULL CONSTRAINT DF_ops_AttendanceSummary_Absent   DEFAULT (0),
    HalfDays        DECIMAL(5,1)    NOT NULL CONSTRAINT DF_ops_AttendanceSummary_HalfDays DEFAULT (0),
    WeekOff         DECIMAL(5,1)    NOT NULL CONSTRAINT DF_ops_AttendanceSummary_WeekOff  DEFAULT (0),
    Holidays        DECIMAL(5,1)    NOT NULL CONSTRAINT DF_ops_AttendanceSummary_Holidays DEFAULT (0),
    LeaveDays       DECIMAL(5,1)    NOT NULL CONSTRAINT DF_ops_AttendanceSummary_Leave    DEFAULT (0),
    OtHours         DECIMAL(7,2)    NOT NULL CONSTRAINT DF_ops_AttendanceSummary_Ot       DEFAULT (0),
    DoubleShifts    INT             NOT NULL CONSTRAINT DF_ops_AttendanceSummary_DS       DEFAULT (0),
    PayableDays     DECIMAL(5,1)    NOT NULL CONSTRAINT DF_ops_AttendanceSummary_Payable  DEFAULT (0),
    RefreshedAt     DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_AttendanceSummary_Refreshed DEFAULT (SYSDATETIME()),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_AttendanceSummary_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_ops_AttendanceSummary_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_AttendanceSummary_Branch   FOREIGN KEY (BranchID)  REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_ops_AttendanceSummary_Unit     FOREIGN KEY (UnitID)    REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_ops_AttendanceSummary_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT UQ_ops_AttendanceSummary UNIQUE (CompanyID, EmpID, MonthYear)
);
GO

/*------------------------------------- TVP for the mobile offline sync batch */
IF TYPE_ID('ops.AttendancePunchList') IS NULL
CREATE TYPE ops.AttendancePunchList AS TABLE (
    ClientRequestId UNIQUEIDENTIFIER NOT NULL,
    EmpID           INT              NOT NULL,
    UnitID          INT              NOT NULL,
    ShiftID         INT              NULL,
    PunchAt         DATETIME2(0)     NOT NULL,
    Latitude        DECIMAL(10,7)    NULL,
    Longitude       DECIMAL(10,7)    NULL,
    Direction       CHAR(3)          NOT NULL,     -- 'IN ' or 'OUT'
    SelfieUrl       NVARCHAR(500)    NULL,
    IsMockLocation  BIT              NOT NULL,
    DeviceID        NVARCHAR(200)    NULL,
    AppVersion      NVARCHAR(20)     NULL,
    PRIMARY KEY (ClientRequestId)
);
GO

PRINT '060_attendance_tables.sql  ->  OK  (2 tables + 1 table type)';
GO
