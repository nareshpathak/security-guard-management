/*==============================================================================
  070_patrol_location_tables.sql
  QR checkpoint patrol and live location tracking (schema: ops)
  Spec: docs/prd/01-database.md §2.6

  ops.LocationLog and ops.QrScanLog are the two highest-volume tables in the
  system. Both are BIGINT keyed and are candidates for monthly partitioning in
  200_indexes.sql once row counts justify it.
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*------------------------------------------------------------- CHECKPOINTS */
IF OBJECT_ID('ops.QrCheckpoint','U') IS NULL
CREATE TABLE ops.QrCheckpoint (
    QrID              INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_QrCheckpoint PRIMARY KEY,
    CompanyID         INT           NOT NULL,
    BranchID          INT           NULL,
    UnitID            INT           NOT NULL,
    LocationID        INT           NULL,
    QrCode            NVARCHAR(64)  NOT NULL,     -- GUID string printed into the QR image
    Name              NVARCHAR(150) NOT NULL,
    Location          NVARCHAR(300) NULL,
    Latitude          DECIMAL(10,7) NULL,
    Longitude         DECIMAL(10,7) NULL,
    MaxDistanceMeters INT           NOT NULL CONSTRAINT DF_ops_QrCheckpoint_MaxDistance DEFAULT (50),
    RequirePhoto      BIT           NOT NULL CONSTRAINT DF_ops_QrCheckpoint_RequirePhoto DEFAULT (0),
    Photo             NVARCHAR(500) NULL,
    Remark            NVARCHAR(500) NULL,
    SortOrder         INT           NOT NULL CONSTRAINT DF_ops_QrCheckpoint_SortOrder DEFAULT (0),
    IsActive          BIT           NOT NULL CONSTRAINT DF_ops_QrCheckpoint_IsActive   DEFAULT (1),
    IsCancel          BIT           NOT NULL CONSTRAINT DF_ops_QrCheckpoint_IsCancel   DEFAULT (0),
    InsertDate        DATETIME2(0)  NOT NULL CONSTRAINT DF_ops_QrCheckpoint_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID      INT           NULL,
    UpdateDate        DATETIME2(0)  NULL,
    UpdateUserID      INT           NULL,
    CONSTRAINT FK_ops_QrCheckpoint_Company  FOREIGN KEY (CompanyID)  REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_QrCheckpoint_Branch   FOREIGN KEY (BranchID)   REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_ops_QrCheckpoint_Unit     FOREIGN KEY (UnitID)     REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_ops_QrCheckpoint_Location FOREIGN KEY (LocationID) REFERENCES crm.UnitLocation (LocationID),
    CONSTRAINT UQ_ops_QrCheckpoint_Code     UNIQUE (QrCode),
    CONSTRAINT CK_ops_QrCheckpoint_Lat      CHECK (Latitude  IS NULL OR Latitude  BETWEEN -90  AND 90),
    CONSTRAINT CK_ops_QrCheckpoint_Lng      CHECK (Longitude IS NULL OR Longitude BETWEEN -180 AND 180),
    CONSTRAINT CK_ops_QrCheckpoint_MaxDist  CHECK (MaxDistanceMeters BETWEEN 5 AND 1000)
);
GO

/*----------------------------------------------------------------- ROUNDS  */
IF OBJECT_ID('ops.PatrolRound','U') IS NULL
CREATE TABLE ops.PatrolRound (
    RoundID              INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_PatrolRound PRIMARY KEY,
    CompanyID            INT           NOT NULL,
    UnitID               INT           NOT NULL,
    RoundName            NVARCHAR(100) NOT NULL,
    StartTime            TIME(0)       NOT NULL,
    EndTime              TIME(0)       NOT NULL,
    ExpectedCheckpoints  INT           NOT NULL CONSTRAINT DF_ops_PatrolRound_Expected DEFAULT (0),
    GraceMinutes         INT           NOT NULL CONSTRAINT DF_ops_PatrolRound_Grace    DEFAULT (15),
    DaysOfWeek           NVARCHAR(20)  NULL,      -- e.g. '1,2,3,4,5,6,7'
    IsActive             BIT           NOT NULL CONSTRAINT DF_ops_PatrolRound_IsActive DEFAULT (1),
    IsCancel             BIT           NOT NULL CONSTRAINT DF_ops_PatrolRound_IsCancel DEFAULT (0),
    InsertDate           DATETIME2(0)  NOT NULL CONSTRAINT DF_ops_PatrolRound_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID         INT           NULL,
    UpdateDate           DATETIME2(0)  NULL,
    UpdateUserID         INT           NULL,
    CONSTRAINT FK_ops_PatrolRound_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_PatrolRound_Unit    FOREIGN KEY (UnitID)    REFERENCES crm.Unit (UnitID)
);
GO

IF OBJECT_ID('ops.PatrolRoundCheckpoint','U') IS NULL
CREATE TABLE ops.PatrolRoundCheckpoint (
    RoundID         INT             NOT NULL,
    QrID            INT             NOT NULL,
    SequenceNo      INT             NOT NULL CONSTRAINT DF_ops_PatrolRoundCheckpoint_Seq DEFAULT (1),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_PatrolRoundCheckpoint_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    CONSTRAINT PK_ops_PatrolRoundCheckpoint PRIMARY KEY (RoundID, QrID),
    CONSTRAINT FK_ops_PatrolRoundCheckpoint_Round FOREIGN KEY (RoundID) REFERENCES ops.PatrolRound (RoundID),
    CONSTRAINT FK_ops_PatrolRoundCheckpoint_Qr    FOREIGN KEY (QrID)    REFERENCES ops.QrCheckpoint (QrID)
);
GO

/*--------------------------------------------------------------- SCAN LOG  */
IF OBJECT_ID('ops.QrScanLog','U') IS NULL
CREATE TABLE ops.QrScanLog (
    ScanID          BIGINT          IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_QrScanLog PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    QrID            INT             NOT NULL,
    UnitID          INT             NOT NULL,
    EmpID           INT             NULL,
    UserID          INT             NULL,
    RoundID         INT             NULL,
    RoundNo         INT             NULL,
    Scantime        DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_QrScanLog_Scantime DEFAULT (SYSDATETIME()),
    Latitude        DECIMAL(10,7)   NULL,
    Longitude       DECIMAL(10,7)   NULL,
    DistanceMeters  INT             NULL,      -- set by trigger, never by the client
    IsWithinRange   BIT             NOT NULL CONSTRAINT DF_ops_QrScanLog_IsWithinRange DEFAULT (0),
    ImageUrl        NVARCHAR(500)   NULL,
    Remark          NVARCHAR(500)   NULL,
    ClientRequestId UNIQUEIDENTIFIER NULL,     -- idempotency key from the mobile outbox
    IsOffline       BIT             NOT NULL CONSTRAINT DF_ops_QrScanLog_IsOffline DEFAULT (0),
    ClientScanAt    DATETIME2(0)    NULL,
    SyncedAt        DATETIME2(0)    NULL,
    IsMockLocation  BIT             NOT NULL CONSTRAINT DF_ops_QrScanLog_IsMock DEFAULT (0),
    DeviceID        NVARCHAR(200)   NULL,
    AppVersion      NVARCHAR(20)    NULL,
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_QrScanLog_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    CONSTRAINT FK_ops_QrScanLog_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_QrScanLog_Qr       FOREIGN KEY (QrID)      REFERENCES ops.QrCheckpoint (QrID),
    CONSTRAINT FK_ops_QrScanLog_Unit     FOREIGN KEY (UnitID)    REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_ops_QrScanLog_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_ops_QrScanLog_User     FOREIGN KEY (UserID)    REFERENCES sec.Users (UserID),
    CONSTRAINT FK_ops_QrScanLog_Round    FOREIGN KEY (RoundID)   REFERENCES ops.PatrolRound (RoundID),
    CONSTRAINT CK_ops_QrScanLog_Lat CHECK (Latitude  IS NULL OR Latitude  BETWEEN -90  AND 90),
    CONSTRAINT CK_ops_QrScanLog_Lng CHECK (Longitude IS NULL OR Longitude BETWEEN -180 AND 180)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_ops_QrScanLog_ClientRequestId' AND object_id=OBJECT_ID('ops.QrScanLog'))
    CREATE UNIQUE INDEX UX_ops_QrScanLog_ClientRequestId
        ON ops.QrScanLog (ClientRequestId) WHERE ClientRequestId IS NOT NULL;
GO

/*------------------------------------------------------------ LOCATION LOG */
IF OBJECT_ID('ops.LocationLog','U') IS NULL
CREATE TABLE ops.LocationLog (
    LogID           BIGINT          IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_LocationLog PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    UserID          INT             NULL,
    EmpID           INT             NULL,
    UnitID          INT             NULL,
    Latitude        DECIMAL(10,7)   NOT NULL,
    Longitude       DECIMAL(10,7)   NOT NULL,
    Accuracy        DECIMAL(7,2)    NULL,
    Speed           DECIMAL(7,2)    NULL,
    BatteryLevel    TINYINT         NULL,
    LoggedAt        DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_LocationLog_LoggedAt DEFAULT (SYSDATETIME()),
    Source          CHAR(2)         NOT NULL CONSTRAINT DF_ops_LocationLog_Source DEFAULT ('FG'),  -- FG foreground / BG background
    IsMockLocation  BIT             NOT NULL CONSTRAINT DF_ops_LocationLog_IsMock DEFAULT (0),
    DeviceID        NVARCHAR(200)   NULL,
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_LocationLog_InsertDate DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_ops_LocationLog_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_LocationLog_User     FOREIGN KEY (UserID)    REFERENCES sec.Users (UserID),
    CONSTRAINT FK_ops_LocationLog_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_ops_LocationLog_Unit     FOREIGN KEY (UnitID)    REFERENCES crm.Unit (UnitID),
    CONSTRAINT CK_ops_LocationLog_Lat    CHECK (Latitude  BETWEEN -90  AND 90),
    CONSTRAINT CK_ops_LocationLog_Lng    CHECK (Longitude BETWEEN -180 AND 180),
    CONSTRAINT CK_ops_LocationLog_Source CHECK (Source IN ('FG','BG'))
);
GO

/*---------------------- TVP for batched location pings from the mobile app  */
IF TYPE_ID('ops.LocationPingList') IS NULL
CREATE TYPE ops.LocationPingList AS TABLE (
    Latitude       DECIMAL(10,7) NOT NULL,
    Longitude      DECIMAL(10,7) NOT NULL,
    Accuracy       DECIMAL(7,2)  NULL,
    Speed          DECIMAL(7,2)  NULL,
    BatteryLevel   TINYINT       NULL,
    LoggedAt       DATETIME2(0)  NOT NULL,
    Source         CHAR(2)       NOT NULL,
    IsMockLocation BIT           NOT NULL
);
GO

PRINT '070_patrol_location_tables.sql  ->  OK  (5 tables + 1 table type)';
GO
