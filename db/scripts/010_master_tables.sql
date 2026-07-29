/*==============================================================================
  010_master_tables.sql
  Master / reference data tables (schema: mst)
  Spec: docs/prd/01-database.md §2.3

  NOTE ON CompanyID
  -----------------
  Masters carry CompanyID NULL: NULL = global platform master, non-null = tenant
  override. The FK to org.Company cannot be created here because org.Company is
  built in 020. All such forward-references are added in 150_foreign_keys.sql.

  Idempotent: safe to run repeatedly.
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*---------------------------------------------------------------- GEOGRAPHY */
IF OBJECT_ID('mst.Country','U') IS NULL
CREATE TABLE mst.Country (
    CountryID       INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_Country PRIMARY KEY,
    CountryName     NVARCHAR(100)   NOT NULL,
    IsoCode         NVARCHAR(3)     NULL,
    IsApproved      BIT             NOT NULL CONSTRAINT DF_mst_Country_IsApproved DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_Country_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_mst_Country_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_Country_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT UQ_mst_Country_Name UNIQUE (CountryName)
);
GO

IF OBJECT_ID('mst.State','U') IS NULL
CREATE TABLE mst.State (
    StateID         INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_State PRIMARY KEY,
    CountryID       INT             NOT NULL,
    StateName       NVARCHAR(100)   NOT NULL,
    StateCode       NVARCHAR(10)    NULL,
    GstStateCode    NVARCHAR(2)     NULL,
    CmpAddress      NVARCHAR(500)   NULL,
    GSTIN           NVARCHAR(15)    NULL,
    IsApproved      BIT             NOT NULL CONSTRAINT DF_mst_State_IsApproved DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_State_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_mst_State_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_State_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_mst_State_Country FOREIGN KEY (CountryID) REFERENCES mst.Country (CountryID),
    CONSTRAINT UQ_mst_State_Name    UNIQUE (CountryID, StateName)
);
GO

IF OBJECT_ID('mst.District','U') IS NULL
CREATE TABLE mst.District (
    DistrictID      INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_District PRIMARY KEY,
    StateID         INT             NOT NULL,
    DistrictName    NVARCHAR(100)   NOT NULL,
    IsApproved      BIT             NOT NULL CONSTRAINT DF_mst_District_IsApproved DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_District_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_mst_District_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_District_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_mst_District_State FOREIGN KEY (StateID) REFERENCES mst.State (StateID),
    CONSTRAINT UQ_mst_District_Name  UNIQUE (StateID, DistrictName)
);
GO

IF OBJECT_ID('mst.City','U') IS NULL
CREATE TABLE mst.City (
    CityID          INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_City PRIMARY KEY,
    DistrictID      INT             NULL,
    StateID         INT             NOT NULL,
    CityName        NVARCHAR(100)   NOT NULL,
    PhotoUrl        NVARCHAR(500)   NULL,
    IsApproved      BIT             NOT NULL CONSTRAINT DF_mst_City_IsApproved DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_City_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_mst_City_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_City_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_mst_City_State    FOREIGN KEY (StateID)    REFERENCES mst.State (StateID),
    CONSTRAINT FK_mst_City_District FOREIGN KEY (DistrictID) REFERENCES mst.District (DistrictID)
);
GO

/*--------------------------------------------- TENANT-SCOPED GEO GROUPINGS  */
IF OBJECT_ID('mst.Region','U') IS NULL
CREATE TABLE mst.Region (
    RegionID        INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_Region PRIMARY KEY,
    CompanyID       INT             NULL,          -- FK added in 150_foreign_keys.sql
    RegionName      NVARCHAR(100)   NOT NULL,
    IsApproved      BIT             NOT NULL CONSTRAINT DF_mst_Region_IsApproved DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_Region_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_mst_Region_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_Region_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL
);
GO

IF OBJECT_ID('mst.Area','U') IS NULL
CREATE TABLE mst.Area (
    AreaID          INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_Area PRIMARY KEY,
    RegionID        INT             NULL,
    CompanyID       INT             NULL,          -- FK added in 150_foreign_keys.sql
    AreaName        NVARCHAR(100)   NOT NULL,
    IsApproved      BIT             NOT NULL CONSTRAINT DF_mst_Area_IsApproved DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_Area_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_mst_Area_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_Area_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_mst_Area_Region FOREIGN KEY (RegionID) REFERENCES mst.Region (RegionID)
);
GO

/*------------------------------------------------------- HR CLASSIFICATION */
IF OBJECT_ID('mst.Grade','U') IS NULL
CREATE TABLE mst.Grade (
    GradeID         INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_Grade PRIMARY KEY,
    CompanyID       INT             NULL,
    GradeName       NVARCHAR(50)    NOT NULL,
    SortOrder       INT             NOT NULL CONSTRAINT DF_mst_Grade_SortOrder DEFAULT (0),
    IsApproved      BIT             NOT NULL CONSTRAINT DF_mst_Grade_IsApproved DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_Grade_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_mst_Grade_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_Grade_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL
);
GO

IF OBJECT_ID('mst.Category','U') IS NULL
CREATE TABLE mst.Category (
    CategoryID      INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_Category PRIMARY KEY,
    CompanyID       INT             NULL,
    CategoryName    NVARCHAR(50)    NOT NULL,      -- Unskilled / Semi-skilled / Skilled / Highly Skilled
    SortOrder       INT             NOT NULL CONSTRAINT DF_mst_Category_SortOrder DEFAULT (0),
    IsApproved      BIT             NOT NULL CONSTRAINT DF_mst_Category_IsApproved DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_Category_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_mst_Category_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_Category_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL
);
GO

IF OBJECT_ID('mst.Designation','U') IS NULL
CREATE TABLE mst.Designation (
    DesignationID   INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_Designation PRIMARY KEY,
    CompanyID       INT             NULL,
    DesignationName NVARCHAR(100)   NOT NULL,
    GradeID         INT             NULL,
    CategoryID      INT             NULL,
    IsGunmanRole    BIT             NOT NULL CONSTRAINT DF_mst_Designation_IsGunmanRole DEFAULT (0),
    SortOrder       INT             NOT NULL CONSTRAINT DF_mst_Designation_SortOrder    DEFAULT (0),
    IsApproved      BIT             NOT NULL CONSTRAINT DF_mst_Designation_IsApproved DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_Designation_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_mst_Designation_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_Designation_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_mst_Designation_Grade    FOREIGN KEY (GradeID)    REFERENCES mst.Grade (GradeID),
    CONSTRAINT FK_mst_Designation_Category FOREIGN KEY (CategoryID) REFERENCES mst.Category (CategoryID)
);
GO

IF OBJECT_ID('mst.Qualification','U') IS NULL
CREATE TABLE mst.Qualification (
    QualificationID   INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_Qualification PRIMARY KEY,
    CompanyID         INT           NULL,
    QualificationName NVARCHAR(100) NOT NULL,
    SortOrder         INT           NOT NULL CONSTRAINT DF_mst_Qualification_SortOrder DEFAULT (0),
    IsApproved        BIT           NOT NULL CONSTRAINT DF_mst_Qualification_IsApproved DEFAULT (1),
    IsCancel          BIT           NOT NULL CONSTRAINT DF_mst_Qualification_IsCancel   DEFAULT (0),
    IsReject          BIT           NOT NULL CONSTRAINT DF_mst_Qualification_IsReject   DEFAULT (0),
    InsertDate        DATETIME2(0)  NOT NULL CONSTRAINT DF_mst_Qualification_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID      INT           NULL,
    UpdateDate        DATETIME2(0)  NULL,
    UpdateUserID      INT           NULL
);
GO

IF OBJECT_ID('mst.Shift','U') IS NULL
CREATE TABLE mst.Shift (
    ShiftID         INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_Shift PRIMARY KEY,
    CompanyID       INT             NULL,
    ShiftName       NVARCHAR(50)    NOT NULL,
    StartTime       TIME(0)         NOT NULL,
    EndTime         TIME(0)         NOT NULL,
    IsNight         BIT             NOT NULL CONSTRAINT DF_mst_Shift_IsNight DEFAULT (0),
    GraceInMinutes  INT             NOT NULL CONSTRAINT DF_mst_Shift_GraceIn  DEFAULT (15),
    GraceOutMinutes INT             NOT NULL CONSTRAINT DF_mst_Shift_GraceOut DEFAULT (15),
    HalfDayHours    DECIMAL(5,2)    NOT NULL CONSTRAINT DF_mst_Shift_HalfDay  DEFAULT (4.00),
    FullDayHours    DECIMAL(5,2)    NOT NULL CONSTRAINT DF_mst_Shift_FullDay  DEFAULT (8.00),
    IsApproved      BIT             NOT NULL CONSTRAINT DF_mst_Shift_IsApproved DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_Shift_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_mst_Shift_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_Shift_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL
);
GO

/*------------------------------------------------------------------ BANKING */
IF OBJECT_ID('mst.Bank','U') IS NULL
CREATE TABLE mst.Bank (
    BankID          INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_Bank PRIMARY KEY,
    BankName        NVARCHAR(150)   NOT NULL,
    IsApproved      BIT             NOT NULL CONSTRAINT DF_mst_Bank_IsApproved DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_Bank_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_mst_Bank_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_Bank_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT UQ_mst_Bank_Name UNIQUE (BankName)
);
GO

IF OBJECT_ID('mst.IfscCode','U') IS NULL
CREATE TABLE mst.IfscCode (
    IfscCodeID      INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_IfscCode PRIMARY KEY,
    BankID          INT             NOT NULL,
    IFSCcode        NVARCHAR(11)    NOT NULL,
    BranchName      NVARCHAR(150)   NULL,
    Address         NVARCHAR(500)   NULL,
    CityID          INT             NULL,
    StateID         INT             NULL,
    IsApproved      BIT             NOT NULL CONSTRAINT DF_mst_IfscCode_IsApproved DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_IfscCode_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_mst_IfscCode_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_IfscCode_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_mst_IfscCode_Bank  FOREIGN KEY (BankID)  REFERENCES mst.Bank (BankID),
    CONSTRAINT FK_mst_IfscCode_City  FOREIGN KEY (CityID)  REFERENCES mst.City (CityID),
    CONSTRAINT FK_mst_IfscCode_State FOREIGN KEY (StateID) REFERENCES mst.State (StateID),
    CONSTRAINT UQ_mst_IfscCode_Code  UNIQUE (IFSCcode)
);
GO

/*------------------------------------------------------------ OPS LOOKUPS  */
IF OBJECT_ID('mst.ComplaintType','U') IS NULL
CREATE TABLE mst.ComplaintType (
    ComplaintTypeID   INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_ComplaintType PRIMARY KEY,
    CompanyID         INT           NULL,
    ComplaintTypeName NVARCHAR(100) NOT NULL,
    DefaultSlaHours   INT           NOT NULL CONSTRAINT DF_mst_ComplaintType_Sla DEFAULT (24),
    IsApproved        BIT           NOT NULL CONSTRAINT DF_mst_ComplaintType_IsApproved DEFAULT (1),
    IsCancel          BIT           NOT NULL CONSTRAINT DF_mst_ComplaintType_IsCancel   DEFAULT (0),
    IsReject          BIT           NOT NULL CONSTRAINT DF_mst_ComplaintType_IsReject   DEFAULT (0),
    InsertDate        DATETIME2(0)  NOT NULL CONSTRAINT DF_mst_ComplaintType_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID      INT           NULL,
    UpdateDate        DATETIME2(0)  NULL,
    UpdateUserID      INT           NULL
);
GO

IF OBJECT_ID('mst.IncidentType','U') IS NULL
CREATE TABLE mst.IncidentType (
    IncidentTypeID    INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_IncidentType PRIMARY KEY,
    CompanyID         INT           NULL,
    IncidentTypeName  NVARCHAR(100) NOT NULL,
    Severity          TINYINT       NOT NULL CONSTRAINT DF_mst_IncidentType_Severity DEFAULT (2),  -- 1 Low 2 Medium 3 High 4 Critical
    IsApproved        BIT           NOT NULL CONSTRAINT DF_mst_IncidentType_IsApproved DEFAULT (1),
    IsCancel          BIT           NOT NULL CONSTRAINT DF_mst_IncidentType_IsCancel   DEFAULT (0),
    IsReject          BIT           NOT NULL CONSTRAINT DF_mst_IncidentType_IsReject   DEFAULT (0),
    InsertDate        DATETIME2(0)  NOT NULL CONSTRAINT DF_mst_IncidentType_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID      INT           NULL,
    UpdateDate        DATETIME2(0)  NULL,
    UpdateUserID      INT           NULL,
    CONSTRAINT CK_mst_IncidentType_Severity CHECK (Severity BETWEEN 1 AND 4)
);
GO

IF OBJECT_ID('mst.ServiceType','U') IS NULL
CREATE TABLE mst.ServiceType (
    ServiceTypeID   INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_ServiceType PRIMARY KEY,
    CompanyID       INT             NULL,
    ServiceName     NVARCHAR(100)   NOT NULL,     -- Security Guard, Gunman, Housekeeping, Supervisor...
    IsApproved      BIT             NOT NULL CONSTRAINT DF_mst_ServiceType_IsApproved DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_ServiceType_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_mst_ServiceType_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_ServiceType_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL
);
GO

IF OBJECT_ID('mst.UniformItem','U') IS NULL
CREATE TABLE mst.UniformItem (
    ItemID          INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_UniformItem PRIMARY KEY,
    CompanyID       INT             NULL,
    ItemName        NVARCHAR(100)   NOT NULL,
    Rate            DECIMAL(18,2)   NOT NULL CONSTRAINT DF_mst_UniformItem_Rate DEFAULT (0),
    Uom             NVARCHAR(20)    NOT NULL CONSTRAINT DF_mst_UniformItem_Uom  DEFAULT (N'PCS'),
    IsReturnable    BIT             NOT NULL CONSTRAINT DF_mst_UniformItem_IsReturnable DEFAULT (1),
    IsApproved      BIT             NOT NULL CONSTRAINT DF_mst_UniformItem_IsApproved DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_UniformItem_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_mst_UniformItem_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_UniformItem_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL
);
GO

/*------------------------------------------------------------ TASK LOOKUPS */
IF OBJECT_ID('mst.TaskRepetition','U') IS NULL
CREATE TABLE mst.TaskRepetition (
    RepetitionID    INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_TaskRepetition PRIMARY KEY,
    Name            NVARCHAR(50)    NOT NULL,      -- None / Daily / Weekly / Monthly / Quarterly
    IntervalDays    INT             NOT NULL CONSTRAINT DF_mst_TaskRepetition_Interval DEFAULT (0),
    SortOrder       INT             NOT NULL CONSTRAINT DF_mst_TaskRepetition_SortOrder DEFAULT (0),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_TaskRepetition_IsCancel DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_TaskRepetition_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT UQ_mst_TaskRepetition_Name UNIQUE (Name)
);
GO

IF OBJECT_ID('mst.TaskStatus','U') IS NULL
CREATE TABLE mst.TaskStatus (
    TaskStatusID    INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_TaskStatus PRIMARY KEY,
    Name            NVARCHAR(50)    NOT NULL,      -- Pending / In-Progress / On-Hold / Completed / Closed / Rejected
    ColorHex        NVARCHAR(7)     NULL,
    IsTerminal      BIT             NOT NULL CONSTRAINT DF_mst_TaskStatus_IsTerminal DEFAULT (0),
    SortOrder       INT             NOT NULL CONSTRAINT DF_mst_TaskStatus_SortOrder  DEFAULT (0),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_TaskStatus_IsCancel   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_TaskStatus_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT UQ_mst_TaskStatus_Name UNIQUE (Name)
);
GO

IF OBJECT_ID('mst.Priority','U') IS NULL
CREATE TABLE mst.Priority (
    PriorityID      INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_Priority PRIMARY KEY,
    Name            NVARCHAR(50)    NOT NULL,      -- Low / Medium / High / Critical
    ColorHex        NVARCHAR(7)     NULL,
    SortOrder       INT             NOT NULL CONSTRAINT DF_mst_Priority_SortOrder DEFAULT (0),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_Priority_IsCancel  DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_Priority_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT UQ_mst_Priority_Name UNIQUE (Name)
);
GO

IF OBJECT_ID('mst.LoginType','U') IS NULL
CREATE TABLE mst.LoginType (
    LoginTypeID     INT             NOT NULL CONSTRAINT PK_mst_LoginType PRIMARY KEY,  -- fixed ids, not identity
    Name            NVARCHAR(50)    NOT NULL,      -- routes the app to the right dashboard
    RoleCode        NVARCHAR(30)    NOT NULL,
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_LoginType_IsCancel DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_LoginType_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT UQ_mst_LoginType_Name UNIQUE (Name)
);
GO

/*------------------------------------------------------------- STATUTORY   */
IF OBJECT_ID('mst.Holiday','U') IS NULL
CREATE TABLE mst.Holiday (
    HolidayID       INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_Holiday PRIMARY KEY,
    CompanyID       INT             NULL,
    StateID         INT             NULL,
    HolidayDate     DATE            NOT NULL,
    HolidayName     NVARCHAR(100)   NOT NULL,
    IsPaid          BIT             NOT NULL CONSTRAINT DF_mst_Holiday_IsPaid   DEFAULT (1),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_Holiday_IsCancel DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_Holiday_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_mst_Holiday_State FOREIGN KEY (StateID) REFERENCES mst.State (StateID)
);
GO

IF OBJECT_ID('mst.MinimumWage','U') IS NULL
CREATE TABLE mst.MinimumWage (
    MinWageID       INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_MinimumWage PRIMARY KEY,
    StateID         INT             NOT NULL,
    CategoryID      INT             NOT NULL,
    EffectiveFrom   DATE            NOT NULL,
    BasicPerDay     DECIMAL(18,2)   NOT NULL,
    VdaPerDay       DECIMAL(18,2)   NOT NULL CONSTRAINT DF_mst_MinimumWage_Vda DEFAULT (0),
    HraPercent      DECIMAL(5,2)    NOT NULL CONSTRAINT DF_mst_MinimumWage_Hra DEFAULT (0),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_MinimumWage_IsCancel DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_MinimumWage_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_mst_MinimumWage_State    FOREIGN KEY (StateID)    REFERENCES mst.State (StateID),
    CONSTRAINT FK_mst_MinimumWage_Category FOREIGN KEY (CategoryID) REFERENCES mst.Category (CategoryID),
    CONSTRAINT UQ_mst_MinimumWage UNIQUE (StateID, CategoryID, EffectiveFrom)
);
GO

IF OBJECT_ID('mst.StatutoryRate','U') IS NULL
CREATE TABLE mst.StatutoryRate (
    RateID          INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_StatutoryRate PRIMARY KEY,
    RateCode        NVARCHAR(30)    NOT NULL,      -- PF_EMP, PF_ER, ESIC_EMP, ESIC_ER, EDLI, ADMIN_CHG
    EffectiveFrom   DATE            NOT NULL,
    [Percent]       DECIMAL(6,3)    NOT NULL,
    CeilingAmount   DECIMAL(18,2)   NULL,
    Remark          NVARCHAR(200)   NULL,
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_StatutoryRate_IsCancel DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_StatutoryRate_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT UQ_mst_StatutoryRate UNIQUE (RateCode, EffectiveFrom)
);
GO

IF OBJECT_ID('mst.PtSlab','U') IS NULL
CREATE TABLE mst.PtSlab (
    PtSlabID        INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_PtSlab PRIMARY KEY,
    StateID         INT             NOT NULL,
    FromAmount      DECIMAL(18,2)   NOT NULL,
    ToAmount        DECIMAL(18,2)   NULL,          -- NULL = no upper bound
    Amount          DECIMAL(18,2)   NOT NULL,
    MonthNo         TINYINT         NULL,          -- some states charge extra in a specific month
    EffectiveFrom   DATE            NOT NULL,
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_PtSlab_IsCancel DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_PtSlab_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_mst_PtSlab_State FOREIGN KEY (StateID) REFERENCES mst.State (StateID)
);
GO

IF OBJECT_ID('mst.LwfSlab','U') IS NULL
CREATE TABLE mst.LwfSlab (
    LwfSlabID       INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_LwfSlab PRIMARY KEY,
    StateID         INT             NOT NULL,
    FromAmount      DECIMAL(18,2)   NOT NULL CONSTRAINT DF_mst_LwfSlab_From DEFAULT (0),
    ToAmount        DECIMAL(18,2)   NULL,
    EmployeeAmount  DECIMAL(18,2)   NOT NULL,
    EmployerAmount  DECIMAL(18,2)   NOT NULL CONSTRAINT DF_mst_LwfSlab_Employer DEFAULT (0),
    DeductionMonths NVARCHAR(30)    NULL,          -- e.g. '6,12' for June and December
    EffectiveFrom   DATE            NOT NULL,
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_LwfSlab_IsCancel DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_LwfSlab_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_mst_LwfSlab_State FOREIGN KEY (StateID) REFERENCES mst.State (StateID)
);
GO

IF OBJECT_ID('mst.DocumentType','U') IS NULL
CREATE TABLE mst.DocumentType (
    DocTypeID       INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_DocumentType PRIMARY KEY,
    CompanyID       INT             NULL,
    DocTypeName     NVARCHAR(100)   NOT NULL,
    OwnerType       NVARCHAR(20)    NOT NULL CONSTRAINT DF_mst_DocumentType_OwnerType DEFAULT (N'Employee'),
    IsMandatory     BIT             NOT NULL CONSTRAINT DF_mst_DocumentType_IsMandatory DEFAULT (0),
    HasExpiry       BIT             NOT NULL CONSTRAINT DF_mst_DocumentType_HasExpiry   DEFAULT (0),
    SortOrder       INT             NOT NULL CONSTRAINT DF_mst_DocumentType_SortOrder   DEFAULT (0),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_mst_DocumentType_IsCancel    DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_DocumentType_InsertDate  DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT CK_mst_DocumentType_OwnerType CHECK (OwnerType IN (N'Employee',N'Unit',N'Client',N'Company',N'Incident',N'Task'))
);
GO

PRINT '010_master_tables.sql  ->  OK  (27 tables)';
GO
