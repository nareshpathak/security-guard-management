/*==============================================================================
  120_payroll_billing_tables.sql
  Payroll and client billing (schema: fin)
  Spec: docs/prd/01-database.md §2.8

  Column names in fin.Salary are taken verbatim from the legacy
  Salaryslipmodel$Datum DTO so the mobile salary slip screen maps 1:1.
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*-------------------------------------------------------- SALARY STRUCTURE */
IF OBJECT_ID('fin.SalaryStructure','U') IS NULL
CREATE TABLE fin.SalaryStructure (
    StructureID       INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_fin_SalaryStructure PRIMARY KEY,
    CompanyID         INT           NOT NULL,
    EmpID             INT           NOT NULL,
    EffectiveFrom     DATE          NOT NULL,
    BasicWages        DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_SalaryStructure_Basic     DEFAULT (0),
    HRAAmt            DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_SalaryStructure_HRA       DEFAULT (0),
    FoodAllow         DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_SalaryStructure_Food      DEFAULT (0),
    LeaveAllow        DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_SalaryStructure_Leave     DEFAULT (0),
    ReliverAllow      DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_SalaryStructure_Reliver   DEFAULT (0),
    SpAllowance       DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_SalaryStructure_SpAllow   DEFAULT (0),
    MixOther          DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_SalaryStructure_MixOther  DEFAULT (0),
    OtRatePerHour     DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_SalaryStructure_OtRate    DEFAULT (0),
    IsPfApplicable    BIT           NOT NULL CONSTRAINT DF_fin_SalaryStructure_Pf        DEFAULT (1),
    IsEsicApplicable  BIT           NOT NULL CONSTRAINT DF_fin_SalaryStructure_Esic      DEFAULT (1),
    IsPtApplicable    BIT           NOT NULL CONSTRAINT DF_fin_SalaryStructure_Pt        DEFAULT (1),
    IsLwfApplicable   BIT           NOT NULL CONSTRAINT DF_fin_SalaryStructure_Lwf       DEFAULT (1),
    IsCancel          BIT           NOT NULL CONSTRAINT DF_fin_SalaryStructure_IsCancel   DEFAULT (0),
    InsertDate        DATETIME2(0)  NOT NULL CONSTRAINT DF_fin_SalaryStructure_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID      INT           NULL,
    UpdateDate        DATETIME2(0)  NULL,
    UpdateUserID      INT           NULL,
    CONSTRAINT FK_fin_SalaryStructure_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_fin_SalaryStructure_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT UQ_fin_SalaryStructure UNIQUE (EmpID, EffectiveFrom)
);
GO

/*-------------------------------------------------------------- SALARY RUN */
IF OBJECT_ID('fin.SalaryRun','U') IS NULL
CREATE TABLE fin.SalaryRun (
    RunID             INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_fin_SalaryRun PRIMARY KEY,
    CompanyID         INT           NOT NULL,
    BranchID          INT           NULL,
    MonthYear         CHAR(7)       NOT NULL,      -- 'YYYY-MM'
    Status            NVARCHAR(20)  NOT NULL CONSTRAINT DF_fin_SalaryRun_Status DEFAULT (N'Draft'),
    GeneratedBy       INT           NULL,
    GeneratedOn       DATETIME2(0)  NOT NULL CONSTRAINT DF_fin_SalaryRun_GeneratedOn DEFAULT (SYSDATETIME()),
    LockedOn          DATETIME2(0)  NULL,
    LockedBy          INT           NULL,
    PaidOn            DATETIME2(0)  NULL,
    EmployeeCount     INT           NOT NULL CONSTRAINT DF_fin_SalaryRun_EmpCount DEFAULT (0),
    TotalNetPayable   DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_SalaryRun_TotalNet DEFAULT (0),
    Remark            NVARCHAR(500) NULL,
    IsCancel          BIT           NOT NULL CONSTRAINT DF_fin_SalaryRun_IsCancel   DEFAULT (0),
    InsertDate        DATETIME2(0)  NOT NULL CONSTRAINT DF_fin_SalaryRun_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID      INT           NULL,
    UpdateDate        DATETIME2(0)  NULL,
    UpdateUserID      INT           NULL,
    CONSTRAINT FK_fin_SalaryRun_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_fin_SalaryRun_Branch  FOREIGN KEY (BranchID)  REFERENCES org.Branch (BranchID),
    CONSTRAINT CK_fin_SalaryRun_Status  CHECK (Status IN (N'Draft',N'Locked',N'Paid'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_fin_SalaryRun_Company_Branch_Month' AND object_id=OBJECT_ID('fin.SalaryRun'))
    CREATE UNIQUE INDEX UX_fin_SalaryRun_Company_Branch_Month
        ON fin.SalaryRun (CompanyID, BranchID, MonthYear) WHERE IsCancel = 0;
GO

/*------------------------------------------------------------------ SALARY */
IF OBJECT_ID('fin.Salary','U') IS NULL
CREATE TABLE fin.Salary (
    WcsSalaryID       INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_fin_Salary PRIMARY KEY,
    RunID             INT           NOT NULL,
    CompanyID         INT           NOT NULL,
    BranchID          INT           NULL,
    EmpID             INT           NOT NULL,
    UnitID            INT           NULL,
    ClientName        NVARCHAR(200) NULL,
    MonthYear         CHAR(7)       NOT NULL,
    PresentDays       DECIMAL(5,1)  NOT NULL CONSTRAINT DF_fin_Salary_PresentDays DEFAULT (0),
    PayableDays       DECIMAL(5,1)  NOT NULL CONSTRAINT DF_fin_Salary_PayableDays DEFAULT (0),

    BasicWages        DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_Basic    DEFAULT (0),
    HRAAmt            DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_HRA      DEFAULT (0),
    FoodAllow         DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_Food     DEFAULT (0),
    LeaveAllow        DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_Leave    DEFAULT (0),
    ReliverAllow      DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_Reliver  DEFAULT (0),
    SpAllowance       DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_SpAllow  DEFAULT (0),
    BonusAmt          DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_Bonus    DEFAULT (0),
    MixOther          DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_MixOther DEFAULT (0),
    OtAmount          DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_OtAmount DEFAULT (0),
    TotalEarnings     DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_TotalEarnings DEFAULT (0),

    PFAmt             DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_PF       DEFAULT (0),
    ESICAmt           DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_ESIC     DEFAULT (0),
    PtEmp             DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_PtEmp    DEFAULT (0),
    LwfEmp            DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_LwfEmp   DEFAULT (0),
    AdvanceDeduction  DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_Advance  DEFAULT (0),
    UniformDeduction  DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_Uniform  DEFAULT (0),
    OtherDeduction    DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_Other    DEFAULT (0),
    DeductionAmt      DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_Deduction DEFAULT (0),
    NetPayble         DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Salary_NetPayble DEFAULT (0),

    PaymentMode       NVARCHAR(30)  NULL,
    PaidOn            DATE          NULL,
    UtrNo             NVARCHAR(50)  NULL,
    EditReason        NVARCHAR(500) NULL,          -- required when a draft row is edited by hand
    IsCancel          BIT           NOT NULL CONSTRAINT DF_fin_Salary_IsCancel   DEFAULT (0),
    InsertDate        DATETIME2(0)  NOT NULL CONSTRAINT DF_fin_Salary_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID      INT           NULL,
    UpdateDate        DATETIME2(0)  NULL,
    UpdateUserID      INT           NULL,
    CONSTRAINT FK_fin_Salary_Run      FOREIGN KEY (RunID)     REFERENCES fin.SalaryRun (RunID),
    CONSTRAINT FK_fin_Salary_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_fin_Salary_Branch   FOREIGN KEY (BranchID)  REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_fin_Salary_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_fin_Salary_Unit     FOREIGN KEY (UnitID)    REFERENCES crm.Unit (UnitID)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_fin_Salary_Run_Emp' AND object_id=OBJECT_ID('fin.Salary'))
    CREATE UNIQUE INDEX UX_fin_Salary_Run_Emp ON fin.Salary (RunID, EmpID) WHERE IsCancel = 0;
GO

/*----------------------------------------------------------------- ADVANCE */
IF OBJECT_ID('fin.Advance','U') IS NULL
CREATE TABLE fin.Advance (
    AdvanceID         INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_fin_Advance PRIMARY KEY,
    CompanyID         INT           NOT NULL,
    BranchID          INT           NULL,
    EmpID             INT           NOT NULL,
    Amount            DECIMAL(18,2) NOT NULL,
    IssueDate         DATE          NOT NULL CONSTRAINT DF_fin_Advance_IssueDate DEFAULT (CAST(SYSDATETIME() AS DATE)),
    Reason            NVARCHAR(500) NULL,
    InstallmentAmount DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Advance_Installment DEFAULT (0),
    BalanceAmount     DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Advance_Balance     DEFAULT (0),
    ApprovedBy        INT           NULL,
    ApprovedOn        DATETIME2(0)  NULL,
    Status            NVARCHAR(20)  NOT NULL CONSTRAINT DF_fin_Advance_Status DEFAULT (N'Pending'),
    IsApproved        BIT           NOT NULL CONSTRAINT DF_fin_Advance_IsApproved DEFAULT (0),
    IsCancel          BIT           NOT NULL CONSTRAINT DF_fin_Advance_IsCancel   DEFAULT (0),
    IsReject          BIT           NOT NULL CONSTRAINT DF_fin_Advance_IsReject   DEFAULT (0),
    InsertDate        DATETIME2(0)  NOT NULL CONSTRAINT DF_fin_Advance_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID      INT           NULL,
    UpdateDate        DATETIME2(0)  NULL,
    UpdateUserID      INT           NULL,
    CONSTRAINT FK_fin_Advance_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_fin_Advance_Branch   FOREIGN KEY (BranchID)  REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_fin_Advance_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT CK_fin_Advance_Status   CHECK (Status IN (N'Pending',N'Approved',N'Recovering',N'Closed',N'Rejected')),
    CONSTRAINT CK_fin_Advance_Amount   CHECK (Amount > 0)
);
GO

/*----------------------------------------------------------------- INVOICE */
IF OBJECT_ID('fin.Invoice','U') IS NULL
CREATE TABLE fin.Invoice (
    Bid               INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_fin_Invoice PRIMARY KEY,
    CompanyID         INT           NOT NULL,
    BranchID          INT           NULL,
    ClientID          INT           NOT NULL,
    UnitID            INT           NULL,
    Month             TINYINT       NOT NULL,
    Year              SMALLINT      NOT NULL,
    InvoiceNo         NVARCHAR(50)  NOT NULL,
    InvoiceDate       DATE          NOT NULL CONSTRAINT DF_fin_Invoice_InvoiceDate DEFAULT (CAST(SYSDATETIME() AS DATE)),
    DueDate           DATE          NULL,
    TaxableAmount     DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Invoice_Taxable DEFAULT (0),
    CgstAmt           DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Invoice_Cgst    DEFAULT (0),
    SgstAmt           DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Invoice_Sgst    DEFAULT (0),
    IgstAmt           DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Invoice_Igst    DEFAULT (0),
    GrandTotal        DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Invoice_Grand   DEFAULT (0),
    ReceivedAmount    DECIMAL(18,2) NOT NULL CONSTRAINT DF_fin_Invoice_Received DEFAULT (0),
    OutstandingAmount AS (GrandTotal - ReceivedAmount) PERSISTED,
    Status            NVARCHAR(20)  NOT NULL CONSTRAINT DF_fin_Invoice_Status DEFAULT (N'Draft'),
    PdfUrl            NVARCHAR(500) NULL,
    SentOn            DATETIME2(0)  NULL,
    Remark            NVARCHAR(500) NULL,
    IsCancel          BIT           NOT NULL CONSTRAINT DF_fin_Invoice_IsCancel   DEFAULT (0),
    InsertDate        DATETIME2(0)  NOT NULL CONSTRAINT DF_fin_Invoice_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID      INT           NULL,
    UpdateDate        DATETIME2(0)  NULL,
    UpdateUserID      INT           NULL,
    CONSTRAINT FK_fin_Invoice_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_fin_Invoice_Branch  FOREIGN KEY (BranchID)  REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_fin_Invoice_Client  FOREIGN KEY (ClientID)  REFERENCES crm.Client (ClientID),
    CONSTRAINT FK_fin_Invoice_Unit    FOREIGN KEY (UnitID)    REFERENCES crm.Unit (UnitID),
    CONSTRAINT CK_fin_Invoice_Month   CHECK (Month BETWEEN 1 AND 12),
    CONSTRAINT CK_fin_Invoice_Status  CHECK (Status IN (N'Draft',N'Sent',N'PartPaid',N'Paid',N'Overdue',N'Cancelled'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_fin_Invoice_Company_No' AND object_id=OBJECT_ID('fin.Invoice'))
    CREATE UNIQUE INDEX UX_fin_Invoice_Company_No ON fin.Invoice (CompanyID, InvoiceNo) WHERE IsCancel = 0;
GO

IF OBJECT_ID('fin.InvoiceLine','U') IS NULL
CREATE TABLE fin.InvoiceLine (
    LineID          INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_fin_InvoiceLine PRIMARY KEY,
    Bid             INT             NOT NULL,
    CompanyID       INT             NOT NULL,
    UnitID          INT             NULL,
    PostID          INT             NULL,
    DesignationName NVARCHAR(100)   NULL,
    ManDays         DECIMAL(10,2)   NOT NULL CONSTRAINT DF_fin_InvoiceLine_ManDays DEFAULT (0),
    RatePerManDay   DECIMAL(18,2)   NOT NULL CONSTRAINT DF_fin_InvoiceLine_Rate    DEFAULT (0),
    Amount          DECIMAL(18,2)   NOT NULL CONSTRAINT DF_fin_InvoiceLine_Amount  DEFAULT (0),
    Description     NVARCHAR(500)   NULL,
    HsnSac          NVARCHAR(10)    NULL,
    SequenceNo      INT             NOT NULL CONSTRAINT DF_fin_InvoiceLine_Seq DEFAULT (1),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_fin_InvoiceLine_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    CONSTRAINT FK_fin_InvoiceLine_Invoice FOREIGN KEY (Bid)       REFERENCES fin.Invoice (Bid),
    CONSTRAINT FK_fin_InvoiceLine_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_fin_InvoiceLine_Unit    FOREIGN KEY (UnitID)    REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_fin_InvoiceLine_Post    FOREIGN KEY (PostID)    REFERENCES crm.UnitPost (PostID)
);
GO

/*----------------------------------------------------------------- RECEIPT */
IF OBJECT_ID('fin.Receipt','U') IS NULL
CREATE TABLE fin.Receipt (
    ReceiptID       INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_fin_Receipt PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    ClientID        INT             NOT NULL,
    Bid             INT             NULL,
    Amount          DECIMAL(18,2)   NOT NULL,
    ReceivedOn      DATE            NOT NULL CONSTRAINT DF_fin_Receipt_ReceivedOn DEFAULT (CAST(SYSDATETIME() AS DATE)),
    Mode            NVARCHAR(30)    NULL,          -- NEFT / RTGS / Cheque / Cash / UPI
    RefNo           NVARCHAR(50)    NULL,
    Remark          NVARCHAR(500)   NULL,
    IsCancel        BIT             NOT NULL CONSTRAINT DF_fin_Receipt_IsCancel   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_fin_Receipt_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_fin_Receipt_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_fin_Receipt_Branch  FOREIGN KEY (BranchID)  REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_fin_Receipt_Client  FOREIGN KEY (ClientID)  REFERENCES crm.Client (ClientID),
    CONSTRAINT FK_fin_Receipt_Invoice FOREIGN KEY (Bid)       REFERENCES fin.Invoice (Bid),
    CONSTRAINT CK_fin_Receipt_Amount  CHECK (Amount > 0)
);
GO

PRINT '120_payroll_billing_tables.sql  ->  OK  (7 tables)';
GO
