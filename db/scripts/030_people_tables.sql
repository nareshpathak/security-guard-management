/*==============================================================================
  030_people_tables.sql
  People: recruits, employees and their satellites (schema: hr)
  Spec: docs/prd/01-database.md §2.4

  The legacy Addrecruitmodel$Datum carries 196 fields. They are preserved but
  normalised into hr.Employee plus ten satellite tables. Legacy column names
  are kept verbatim so a future migration is a 1:1 map.

  FKs pointing at crm.Unit / crm.Client are forward references and are created
  in 150_foreign_keys.sql.
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*------------------------------------------------------ RECRUITMENT PIPELINE */
IF OBJECT_ID('hr.Recruit','U') IS NULL
CREATE TABLE hr.Recruit (
    RecruitID       INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_hr_Recruit PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    Name            NVARCHAR(200)   NOT NULL,
    Mobile          NVARCHAR(15)    NULL,
    AdharCardNo     NVARCHAR(12)    NULL,
    OldEmpCode      NVARCHAR(30)    NULL,
    Dated           DATE            NOT NULL CONSTRAINT DF_hr_Recruit_Dated DEFAULT (CAST(SYSDATETIME() AS DATE)),
    SourceBy        NVARCHAR(100)   NULL,
    DesignationID   INT             NULL,
    Status          NVARCHAR(20)    NOT NULL CONSTRAINT DF_hr_Recruit_Status DEFAULT (N'New'),
    EmpID           INT             NULL,          -- set on conversion; FK in 150
    Remark          NVARCHAR(500)   NULL,
    IsApproved      BIT             NOT NULL CONSTRAINT DF_hr_Recruit_IsApproved DEFAULT (0),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_hr_Recruit_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_hr_Recruit_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_hr_Recruit_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_hr_Recruit_Company     FOREIGN KEY (CompanyID)     REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_hr_Recruit_Branch      FOREIGN KEY (BranchID)      REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_hr_Recruit_Designation FOREIGN KEY (DesignationID) REFERENCES mst.Designation (DesignationID),
    CONSTRAINT CK_hr_Recruit_Status CHECK (Status IN (N'New',N'Screened',N'Verified',N'Approved',N'Waitlist',N'Rejected',N'Converted'))
);
GO

/*----------------------------------------------------------- EMPLOYEE CORE  */
IF OBJECT_ID('hr.Employee','U') IS NULL
CREATE TABLE hr.Employee (
    EmpID           INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_hr_Employee PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    EmpCode         NVARCHAR(30)    NOT NULL,
    OldEmpCode      NVARCHAR(30)    NULL,
    Salutation      NVARCHAR(10)    NULL,
    FirstName       NVARCHAR(100)   NOT NULL,
    Middlename      NVARCHAR(100)   NULL,
    LastName        NVARCHAR(100)   NULL,
    EmpFullName     AS (LTRIM(RTRIM(
                        ISNULL(FirstName,N'') + N' ' +
                        ISNULL(Middlename,N'') + N' ' +
                        ISNULL(LastName,N'')))) PERSISTED,
    Gender          NVARCHAR(10)    NULL,
    Dob             DATE            NULL,
    BirthPlace      NVARCHAR(100)   NULL,
    Bloodgroup      NVARCHAR(5)     NULL,
    Nationality     NVARCHAR(50)    NULL,
    OtherNationality NVARCHAR(50)   NULL,
    Married         BIT             NOT NULL CONSTRAINT DF_hr_Employee_Married DEFAULT (0),
    SpouseName      NVARCHAR(150)   NULL,
    Mobile1         NVARCHAR(15)    NULL,
    Mobile2         NVARCHAR(15)    NULL,
    EmailId1        NVARCHAR(150)   NULL,
    EmailId2        NVARCHAR(150)   NULL,
    DesignationID   INT             NULL,
    GradeID         INT             NULL,
    CategoryID      INT             NULL,
    ShiftID         INT             NULL,
    UnitID          INT             NULL,          -- FK in 150
    Clientid        INT             NULL,          -- FK in 150
    RegionID        INT             NULL,
    AreaID          INT             NULL,
    Employeetype    NVARCHAR(50)    NULL,
    EmpStatus       NVARCHAR(20)    NOT NULL CONSTRAINT DF_hr_Employee_EmpStatus DEFAULT (N'Active'),
    Doj             DATE            NULL,
    Dol             DATE            NULL,
    DateofLeft      DATE            NULL,
    LeftReason      NVARCHAR(300)   NULL,
    DoDeployment    DATE            NULL,
    BeltNo          NVARCHAR(30)    NULL,
    CardNo          NVARCHAR(30)    NULL,
    SwipeNo         NVARCHAR(30)    NULL,
    IdCardNo        NVARCHAR(30)    NULL,
    IdCardIssueDate DATE            NULL,
    IdCardExpireDate DATE           NULL,
    Photo           NVARCHAR(500)   NULL,
    Selfie          NVARCHAR(500)   NULL,
    EmpSign         NVARCHAR(500)   NULL,
    IdentitySign    NVARCHAR(300)   NULL,
    IsPermanent     BIT             NOT NULL CONSTRAINT DF_hr_Employee_IsPermanent DEFAULT (0),
    IsGunman        BIT             NOT NULL CONSTRAINT DF_hr_Employee_IsGunman    DEFAULT (0),
    IsReliever      BIT             NOT NULL CONSTRAINT DF_hr_Employee_IsReliever  DEFAULT (0),
    IsExService     BIT             NOT NULL CONSTRAINT DF_hr_Employee_IsExService DEFAULT (0),
    IsNotBilling    BIT             NOT NULL CONSTRAINT DF_hr_Employee_IsNotBilling DEFAULT (0),
    IsBlackListed   BIT             NOT NULL CONSTRAINT DF_hr_Employee_IsBlackListed DEFAULT (0),
    BlackListedDate DATE            NULL,
    BlackListedReason NVARCHAR(500) NULL,
    IsApplyEmpSalaryStructure BIT   NOT NULL CONSTRAINT DF_hr_Employee_IsApplySal DEFAULT (0),
    Isform11pf      BIT             NOT NULL CONSTRAINT DF_hr_Employee_Isform11pf DEFAULT (0),
    Isformfullfinal BIT             NOT NULL CONSTRAINT DF_hr_Employee_Isformff   DEFAULT (0),
    Comments        NVARCHAR(1000)  NULL,
    Userid          INT             NULL,
    IsApproved      BIT             NOT NULL CONSTRAINT DF_hr_Employee_IsApproved DEFAULT (0),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_hr_Employee_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_hr_Employee_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_hr_Employee_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_hr_Employee_Company     FOREIGN KEY (CompanyID)     REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_hr_Employee_Branch      FOREIGN KEY (BranchID)      REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_hr_Employee_Designation FOREIGN KEY (DesignationID) REFERENCES mst.Designation (DesignationID),
    CONSTRAINT FK_hr_Employee_Grade       FOREIGN KEY (GradeID)       REFERENCES mst.Grade (GradeID),
    CONSTRAINT FK_hr_Employee_Category    FOREIGN KEY (CategoryID)    REFERENCES mst.Category (CategoryID),
    CONSTRAINT FK_hr_Employee_Shift       FOREIGN KEY (ShiftID)       REFERENCES mst.Shift (ShiftID),
    CONSTRAINT FK_hr_Employee_Region      FOREIGN KEY (RegionID)      REFERENCES mst.Region (RegionID),
    CONSTRAINT FK_hr_Employee_Area        FOREIGN KEY (AreaID)        REFERENCES mst.Area (AreaID),
    CONSTRAINT CK_hr_Employee_EmpStatus CHECK (EmpStatus IN (N'Active',N'Resigned',N'Left',N'Suspended',N'Blacklisted',N'Retired'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_hr_Employee_Company_EmpCode' AND object_id = OBJECT_ID('hr.Employee'))
    CREATE UNIQUE INDEX UX_hr_Employee_Company_EmpCode ON hr.Employee (CompanyID, EmpCode) WHERE IsCancel = 0;
GO

/*---------------------------------------------------------------- ADDRESSES */
IF OBJECT_ID('hr.EmployeeAddress','U') IS NULL
CREATE TABLE hr.EmployeeAddress (
    AddressID       INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_hr_EmployeeAddress PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    EmpID           INT             NOT NULL,
    AddressType     CHAR(1)         NOT NULL,      -- P = Permanent, R = Present/Residential
    Address1        NVARCHAR(300)   NULL,
    Address2        NVARCHAR(300)   NULL,
    City            NVARCHAR(100)   NULL,
    StateID         INT             NULL,
    DistrictID      INT             NULL,
    Pin             NVARCHAR(10)    NULL,
    Telephone       NVARCHAR(20)    NULL,
    AddressDuration NVARCHAR(50)    NULL,
    ForeignAddress  NVARCHAR(500)   NULL,
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_hr_EmployeeAddress_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_hr_EmployeeAddress_Employee FOREIGN KEY (EmpID)      REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_hr_EmployeeAddress_Company  FOREIGN KEY (CompanyID)  REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_hr_EmployeeAddress_State    FOREIGN KEY (StateID)    REFERENCES mst.State (StateID),
    CONSTRAINT FK_hr_EmployeeAddress_District FOREIGN KEY (DistrictID) REFERENCES mst.District (DistrictID),
    CONSTRAINT CK_hr_EmployeeAddress_Type CHECK (AddressType IN ('P','R')),
    CONSTRAINT UQ_hr_EmployeeAddress UNIQUE (EmpID, AddressType)
);
GO

/*------------------------------------------------------------------- FAMILY */
IF OBJECT_ID('hr.EmployeeFamily','U') IS NULL
CREATE TABLE hr.EmployeeFamily (
    FamilyID        INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_hr_EmployeeFamily PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    EmpID           INT             NOT NULL,
    Relation        NVARCHAR(30)    NOT NULL,      -- Father / Mother / Wife / Husband / Child / Nominee
    Name            NVARCHAR(200)   NOT NULL,
    Dob             DATE            NULL,
    Occupation      NVARCHAR(100)   NULL,
    Dependent       BIT             NOT NULL CONSTRAINT DF_hr_EmployeeFamily_Dependent DEFAULT (0),
    SharePercent    DECIMAL(5,2)    NULL,
    AadhaarNo       NVARCHAR(12)    NULL,
    IsCancel        BIT             NOT NULL CONSTRAINT DF_hr_EmployeeFamily_IsCancel DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_hr_EmployeeFamily_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_hr_EmployeeFamily_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_hr_EmployeeFamily_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID)
);
GO

/*----------------------------------------------------------------- PHYSICAL */
IF OBJECT_ID('hr.EmployeePhysical','U') IS NULL
CREATE TABLE hr.EmployeePhysical (
    EmpID              INT          NOT NULL CONSTRAINT PK_hr_EmployeePhysical PRIMARY KEY,
    CompanyID          INT          NOT NULL,
    Height             NVARCHAR(20) NULL,
    Weight             NVARCHAR(20) NULL,
    Chest              NVARCHAR(20) NULL,
    Waist              NVARCHAR(20) NULL,
    Shoesize           NVARCHAR(10) NULL,
    Trousersize        NVARCHAR(10) NULL,
    TshirtSize         NVARCHAR(10) NULL,
    EmployeeEyes       NVARCHAR(30) NULL,
    IdentificationMark NVARCHAR(200) NULL,
    InsertDate         DATETIME2(0) NOT NULL CONSTRAINT DF_hr_EmployeePhysical_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID       INT          NULL,
    UpdateDate         DATETIME2(0) NULL,
    UpdateUserID       INT          NULL,
    CONSTRAINT FK_hr_EmployeePhysical_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_hr_EmployeePhysical_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID)
);
GO

/*---------------------------------------------------------------- STATUTORY */
IF OBJECT_ID('hr.EmployeeStatutory','U') IS NULL
CREATE TABLE hr.EmployeeStatutory (
    EmpID           INT             NOT NULL CONSTRAINT PK_hr_EmployeeStatutory PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    AdharCardNo     NVARCHAR(12)    NULL,
    PanCardNo       NVARCHAR(10)    NULL,
    Pan             NVARCHAR(10)    NULL,
    VoterId         NVARCHAR(30)    NULL,
    DlNo            NVARCHAR(30)    NULL,
    UANNo           NVARCHAR(12)    NULL,
    PFNo            NVARCHAR(30)    NULL,
    ESICNo          NVARCHAR(20)    NULL,
    [Percent]       DECIMAL(5,2)    NULL,
    PaymentMode     NVARCHAR(30)    NULL,
    BankForSalary   BIT             NOT NULL CONSTRAINT DF_hr_EmployeeStatutory_BankForSalary DEFAULT (1),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_hr_EmployeeStatutory_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_hr_EmployeeStatutory_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_hr_EmployeeStatutory_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID)
);
GO

/*--------------------------------------------------------------------- BANK */
IF OBJECT_ID('hr.EmployeeBank','U') IS NULL
CREATE TABLE hr.EmployeeBank (
    BankAccountID          INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_hr_EmployeeBank PRIMARY KEY,
    CompanyID              INT           NOT NULL,
    EmpID                  INT           NOT NULL,
    IsJoint                BIT           NOT NULL CONSTRAINT DF_hr_EmployeeBank_IsJoint DEFAULT (0),
    BankID                 INT           NULL,
    BankName               NVARCHAR(150) NULL,
    BankName1              NVARCHAR(150) NULL,
    BranchName             NVARCHAR(150) NULL,
    BankAcNo               NVARCHAR(30)  NULL,
    IFSCcode               NVARCHAR(11)  NULL,
    IfscCodeId             INT           NULL,
    AcType                 NVARCHAR(30)  NULL,
    NameInBankPassbook     NVARCHAR(150) NULL,
    NameInBankPassbookLast NVARCHAR(150) NULL,
    JointAcName            NVARCHAR(150) NULL,
    JointAcNo              NVARCHAR(30)  NULL,
    JointBankId            INT           NULL,
    JointBankName          NVARCHAR(150) NULL,
    JointBranchName        NVARCHAR(150) NULL,
    JointIfscCodeId        INT           NULL,
    BankPassbook           NVARCHAR(500) NULL,
    Cheque                 NVARCHAR(500) NULL,
    IsBankAdded            BIT           NOT NULL CONSTRAINT DF_hr_EmployeeBank_IsBankAdded DEFAULT (0),
    BankAddedDate          DATETIME2(0)  NULL,
    BankAddedUserId        INT           NULL,
    IsCancel               BIT           NOT NULL CONSTRAINT DF_hr_EmployeeBank_IsCancel DEFAULT (0),
    InsertDate             DATETIME2(0)  NOT NULL CONSTRAINT DF_hr_EmployeeBank_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID           INT           NULL,
    UpdateDate             DATETIME2(0)  NULL,
    UpdateUserID           INT           NULL,
    CONSTRAINT FK_hr_EmployeeBank_Employee   FOREIGN KEY (EmpID)           REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_hr_EmployeeBank_Company    FOREIGN KEY (CompanyID)       REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_hr_EmployeeBank_Bank       FOREIGN KEY (BankID)          REFERENCES mst.Bank (BankID),
    CONSTRAINT FK_hr_EmployeeBank_JointBank  FOREIGN KEY (JointBankId)     REFERENCES mst.Bank (BankID),
    CONSTRAINT FK_hr_EmployeeBank_Ifsc       FOREIGN KEY (IfscCodeId)      REFERENCES mst.IfscCode (IfscCodeID),
    CONSTRAINT FK_hr_EmployeeBank_JointIfsc  FOREIGN KEY (JointIfscCodeId) REFERENCES mst.IfscCode (IfscCodeID)
);
GO

/*------------------------------------------------------------ QUALIFICATION */
IF OBJECT_ID('hr.EmployeeQualification','U') IS NULL
CREATE TABLE hr.EmployeeQualification (
    EmpQualID               INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_hr_EmployeeQualification PRIMARY KEY,
    CompanyID               INT           NOT NULL,
    EmpID                   INT           NOT NULL,
    QualificationID         INT           NULL,
    AddQualificationID      INT           NULL,
    InstituteName           NVARCHAR(200) NULL,
    HigestEducationInstitue NVARCHAR(200) NULL,
    ProfessionalQualification NVARCHAR(200) NULL,
    PassingYear             INT           NULL,
    [Percent]               DECIMAL(5,2)  NULL,
    IsCancel                BIT           NOT NULL CONSTRAINT DF_hr_EmployeeQualification_IsCancel DEFAULT (0),
    InsertDate              DATETIME2(0)  NOT NULL CONSTRAINT DF_hr_EmployeeQualification_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID            INT           NULL,
    UpdateDate              DATETIME2(0)  NULL,
    UpdateUserID            INT           NULL,
    CONSTRAINT FK_hr_EmployeeQualification_Employee FOREIGN KEY (EmpID)              REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_hr_EmployeeQualification_Company  FOREIGN KEY (CompanyID)          REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_hr_EmployeeQualification_Qual     FOREIGN KEY (QualificationID)    REFERENCES mst.Qualification (QualificationID),
    CONSTRAINT FK_hr_EmployeeQualification_AddQual  FOREIGN KEY (AddQualificationID) REFERENCES mst.Qualification (QualificationID)
);
GO

/*--------------------------------------------------------------- EX-SERVICE */
IF OBJECT_ID('hr.EmployeeExService','U') IS NULL
CREATE TABLE hr.EmployeeExService (
    EmpID             INT           NOT NULL CONSTRAINT PK_hr_EmployeeExService PRIMARY KEY,
    CompanyID         INT           NOT NULL,
    ServiceSno        NVARCHAR(50)  NULL,
    [Rank]            NVARCHAR(50)  NULL,
    Regiment          NVARCHAR(100) NULL,
    Dateofdischarge   DATE          NULL,
    Criminology       NVARCHAR(300) NULL,
    CharacterAssessed NVARCHAR(100) NULL,
    InsertDate        DATETIME2(0)  NOT NULL CONSTRAINT DF_hr_EmployeeExService_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID      INT           NULL,
    UpdateDate        DATETIME2(0)  NULL,
    UpdateUserID      INT           NULL,
    CONSTRAINT FK_hr_EmployeeExService_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_hr_EmployeeExService_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID)
);
GO

/*------------------------------------------------------ POLICE VERIFICATION */
IF OBJECT_ID('hr.EmployeeVerification','U') IS NULL
CREATE TABLE hr.EmployeeVerification (
    EmpID                 INT           NOT NULL CONSTRAINT PK_hr_EmployeeVerification PRIMARY KEY,
    CompanyID             INT           NOT NULL,
    IsPoliceVerification  BIT           NOT NULL CONSTRAINT DF_hr_EmployeeVerification_IsPV DEFAULT (0),
    PoliceVerificationNo  NVARCHAR(50)  NULL,
    PoliceStationName     NVARCHAR(150) NULL,
    RemarkByThana         NVARCHAR(500) NULL,
    Pvsenddate            DATE          NULL,
    Pvreturndate          DATE          NULL,
    PVValidUpTo           DATE          NULL,
    VerificationDate      DATE          NULL,
    PoliceCertificateImg  NVARCHAR(500) NULL,
    NotaryStampPadNo      NVARCHAR(50)  NULL,
    InsertDate            DATETIME2(0)  NOT NULL CONSTRAINT DF_hr_EmployeeVerification_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID          INT           NULL,
    UpdateDate            DATETIME2(0)  NULL,
    UpdateUserID          INT           NULL,
    CONSTRAINT FK_hr_EmployeeVerification_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_hr_EmployeeVerification_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID)
);
GO

/*------------------------------------------------------------------ MEDICAL */
IF OBJECT_ID('hr.EmployeeMedical','U') IS NULL
CREATE TABLE hr.EmployeeMedical (
    EmpID                        INT           NOT NULL CONSTRAINT PK_hr_EmployeeMedical PRIMARY KEY,
    CompanyID                    INT           NOT NULL,
    MedicalDate                  DATE          NULL,
    MedicalCertificateIssue      NVARCHAR(100) NULL,
    MedicalCertificateIssueDate  DATE          NULL,
    MedicalCertificateValidUpto  DATE          NULL,
    MedicalCertificateImg        NVARCHAR(500) NULL,
    Hospital                     NVARCHAR(200) NULL,
    Doctorname                   NVARCHAR(150) NULL,
    DoctorRegNo                  NVARCHAR(50)  NULL,
    DoctorQualification          NVARCHAR(150) NULL,
    DoctorDesignation            NVARCHAR(100) NULL,
    DoctorAddress                NVARCHAR(300) NULL,
    DoctorPhoneNo                NVARCHAR(20)  NULL,
    InsertDate                   DATETIME2(0)  NOT NULL CONSTRAINT DF_hr_EmployeeMedical_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID                 INT           NULL,
    UpdateDate                   DATETIME2(0)  NULL,
    UpdateUserID                 INT           NULL,
    CONSTRAINT FK_hr_EmployeeMedical_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_hr_EmployeeMedical_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID)
);
GO

/*-------------------------------------------------------------- GUN LICENCE */
IF OBJECT_ID('hr.EmployeeGunLicence','U') IS NULL
CREATE TABLE hr.EmployeeGunLicence (
    EmpID                INT           NOT NULL CONSTRAINT PK_hr_EmployeeGunLicence PRIMARY KEY,
    CompanyID            INT           NOT NULL,
    GunanType            NVARCHAR(50)  NULL,
    TypeArm              NVARCHAR(50)  NULL,
    GunNo                NVARCHAR(50)  NULL,
    GunModelNum          NVARCHAR(50)  NULL,
    LicenseNo            NVARCHAR(50)  NULL,
    Licenseexpire        DATE          NULL,
    LicenseProduce       NVARCHAR(100) NULL,
    AreaID               INT           NULL,
    AreainLicensevalid   NVARCHAR(200) NULL,
    IssueDate            DATE          NULL,
    Wcpno                NVARCHAR(50)  NULL,
    Wcpamount            DECIMAL(18,2) NULL,
    Wcpexpdate           DATE          NULL,
    InsertDate           DATETIME2(0)  NOT NULL CONSTRAINT DF_hr_EmployeeGunLicence_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID         INT           NULL,
    UpdateDate           DATETIME2(0)  NULL,
    UpdateUserID         INT           NULL,
    CONSTRAINT FK_hr_EmployeeGunLicence_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_hr_EmployeeGunLicence_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_hr_EmployeeGunLicence_Area     FOREIGN KEY (AreaID)    REFERENCES mst.Area (AreaID)
);
GO

/*---------------------------------------------------------- STATUS HISTORY  */
IF OBJECT_ID('hr.EmployeeStatusHistory','U') IS NULL
CREATE TABLE hr.EmployeeStatusHistory (
    HistoryID       INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_hr_EmployeeStatusHistory PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    EmpID           INT             NOT NULL,
    EventType       NVARCHAR(20)    NOT NULL,      -- Join / Resign / Left / Rejoin / Transfer / Blacklist / Unblacklist
    EventDate       DATE            NOT NULL,
    Timing          NVARCHAR(50)    NULL,
    FromUnitID      INT             NULL,          -- FK in 150
    ToUnitID        INT             NULL,          -- FK in 150
    Remark          NVARCHAR(500)   NULL,
    DocUrl          NVARCHAR(500)   NULL,
    ApprovedBy      INT             NULL,
    ApprovedOn      DATETIME2(0)    NULL,
    IsApproved      BIT             NOT NULL CONSTRAINT DF_hr_EmployeeStatusHistory_IsApproved DEFAULT (0),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_hr_EmployeeStatusHistory_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_hr_EmployeeStatusHistory_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_hr_EmployeeStatusHistory_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_hr_EmployeeStatusHistory_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_hr_EmployeeStatusHistory_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT CK_hr_EmployeeStatusHistory_EventType CHECK (EventType IN (N'Join',N'Resign',N'Left',N'Rejoin',N'Transfer',N'Blacklist',N'Unblacklist'))
);
GO

/*----------------------------------------------------------------- TRAINING */
IF OBJECT_ID('hr.Training','U') IS NULL
CREATE TABLE hr.Training (
    TrainingID      INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_hr_Training PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    UnitID          INT             NULL,          -- FK in 150
    TrainerEmpID    INT             NULL,
    Dated           DATE            NOT NULL,
    Timing          NVARCHAR(50)    NULL,
    Nop             INT             NOT NULL CONSTRAINT DF_hr_Training_Nop DEFAULT (0),
    Topic           NVARCHAR(200)   NULL,
    Remark          NVARCHAR(500)   NULL,
    PhotoUrl        NVARCHAR(500)   NULL,
    IsApproved      BIT             NOT NULL CONSTRAINT DF_hr_Training_IsApproved DEFAULT (0),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_hr_Training_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_hr_Training_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_hr_Training_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_hr_Training_Company FOREIGN KEY (CompanyID)    REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_hr_Training_Branch  FOREIGN KEY (BranchID)     REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_hr_Training_Trainer FOREIGN KEY (TrainerEmpID) REFERENCES hr.Employee (EmpID)
);
GO

IF OBJECT_ID('hr.TrainingAttendee','U') IS NULL
CREATE TABLE hr.TrainingAttendee (
    TrainingID      INT             NOT NULL,
    EmpID           INT             NOT NULL,
    IsPresent       BIT             NOT NULL CONSTRAINT DF_hr_TrainingAttendee_IsPresent DEFAULT (1),
    Score           DECIMAL(5,2)    NULL,
    Remark          NVARCHAR(300)   NULL,
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_hr_TrainingAttendee_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    CONSTRAINT PK_hr_TrainingAttendee PRIMARY KEY (TrainingID, EmpID),
    CONSTRAINT FK_hr_TrainingAttendee_Training FOREIGN KEY (TrainingID) REFERENCES hr.Training (TrainingID),
    CONSTRAINT FK_hr_TrainingAttendee_Employee FOREIGN KEY (EmpID)      REFERENCES hr.Employee (EmpID)
);
GO

/*-------------------------------------------------- REQUESTS & SUGGESTIONS  */
IF OBJECT_ID('hr.EmployeeRequest','U') IS NULL
CREATE TABLE hr.EmployeeRequest (
    RequestID       INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_hr_EmployeeRequest PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    EmpID           INT             NOT NULL,
    RequestType     NVARCHAR(20)    NOT NULL,      -- Leave / Advance / Transfer / Uniform / Other
    FromDate        DATE            NULL,
    ToDate          DATE            NULL,
    Amount          DECIMAL(18,2)   NULL,
    Reason          NVARCHAR(500)   NULL,
    Status          NVARCHAR(20)    NOT NULL CONSTRAINT DF_hr_EmployeeRequest_Status DEFAULT (N'Pending'),
    ApprovedBy      INT             NULL,
    ApprovedOn      DATETIME2(0)    NULL,
    Remark          NVARCHAR(500)   NULL,
    IsApproved      BIT             NOT NULL CONSTRAINT DF_hr_EmployeeRequest_IsApproved DEFAULT (0),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_hr_EmployeeRequest_IsCancel   DEFAULT (0),
    IsReject        BIT             NOT NULL CONSTRAINT DF_hr_EmployeeRequest_IsReject   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_hr_EmployeeRequest_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_hr_EmployeeRequest_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_hr_EmployeeRequest_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT CK_hr_EmployeeRequest_Type   CHECK (RequestType IN (N'Leave',N'Advance',N'Transfer',N'Uniform',N'Other')),
    CONSTRAINT CK_hr_EmployeeRequest_Status CHECK (Status IN (N'Pending',N'Approved',N'Rejected',N'Cancelled'))
);
GO

IF OBJECT_ID('hr.Suggestion','U') IS NULL
CREATE TABLE hr.Suggestion (
    SuggestionID    INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_hr_Suggestion PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    EmpID           INT             NULL,
    Subject         NVARCHAR(200)   NULL,
    Description     NVARCHAR(1000)  NOT NULL,
    IsRead          BIT             NOT NULL CONSTRAINT DF_hr_Suggestion_IsRead   DEFAULT (0),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_hr_Suggestion_IsCancel DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_hr_Suggestion_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_hr_Suggestion_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_hr_Suggestion_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID)
);
GO

PRINT '030_people_tables.sql  ->  OK  (17 tables)';
GO
