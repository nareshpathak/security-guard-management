/*==============================================================================
  145_counter_tables.sql
  Sequential code generation counters.

  Employee codes and invoice numbers must be gapless and unique per tenant.
  MAX(x)+1 is not safe under concurrency, so a counter row is taken under
  sp_getapplock by usp_Code_NextEmpCode / usp_Code_NextInvoiceNo (300_functions.sql).

  See DECISIONS.md #14 for why these are procedures and not functions.
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('mst.CodeCounter','U') IS NULL
CREATE TABLE mst.CodeCounter (
    CounterID       INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_mst_CodeCounter PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    CounterType     NVARCHAR(30)    NOT NULL,      -- EMPCODE / INVOICE
    Scope           NVARCHAR(20)    NOT NULL CONSTRAINT DF_mst_CodeCounter_Scope DEFAULT (N'-'),  -- financial year for invoices, '-' otherwise
    Prefix          NVARCHAR(20)    NULL,
    PadLength       TINYINT         NOT NULL CONSTRAINT DF_mst_CodeCounter_PadLength DEFAULT (5),
    LastNumber      INT             NOT NULL CONSTRAINT DF_mst_CodeCounter_LastNumber DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_mst_CodeCounter_InsertDate DEFAULT (SYSDATETIME()),
    UpdateDate      DATETIME2(0)    NULL,
    CONSTRAINT FK_mst_CodeCounter_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_mst_CodeCounter_Branch  FOREIGN KEY (BranchID)  REFERENCES org.Branch (BranchID),
    CONSTRAINT CK_mst_CodeCounter_Type CHECK (CounterType IN (N'EMPCODE',N'INVOICE'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_mst_CodeCounter' AND object_id=OBJECT_ID('mst.CodeCounter'))
    CREATE UNIQUE INDEX UX_mst_CodeCounter
        ON mst.CodeCounter (CompanyID, CounterType, Scope, BranchID);
GO

PRINT '145_counter_tables.sql  ->  OK  (1 table)';
GO
