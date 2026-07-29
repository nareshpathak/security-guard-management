/*==============================================================================
  110_inventory_tables.sql
  Uniform and stock (schema: inv)
  Spec: docs/prd/01-database.md §2.7
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*-------------------------------------------------------------------- STOCK */
IF OBJECT_ID('inv.Stock','U') IS NULL
CREATE TABLE inv.Stock (
    StockID         INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_inv_Stock PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    ItemID          INT             NOT NULL,
    Opstock         DECIMAL(18,2)   NOT NULL CONSTRAINT DF_inv_Stock_Opstock  DEFAULT (0),
    Qty             DECIMAL(18,2)   NOT NULL CONSTRAINT DF_inv_Stock_Qty      DEFAULT (0),   -- on hand
    MinLevel        DECIMAL(18,2)   NOT NULL CONSTRAINT DF_inv_Stock_MinLevel DEFAULT (0),
    IsCancel        BIT             NOT NULL CONSTRAINT DF_inv_Stock_IsCancel   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_inv_Stock_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_inv_Stock_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_inv_Stock_Branch  FOREIGN KEY (BranchID)  REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_inv_Stock_Item    FOREIGN KEY (ItemID)    REFERENCES mst.UniformItem (ItemID)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_inv_Stock_Company_Branch_Item' AND object_id=OBJECT_ID('inv.Stock'))
    CREATE UNIQUE INDEX UX_inv_Stock_Company_Branch_Item
        ON inv.Stock (CompanyID, BranchID, ItemID) WHERE IsCancel = 0;
GO

/*--------------------------------------------------------- STOCK MOVEMENTS  */
IF OBJECT_ID('inv.StockTxn','U') IS NULL
CREATE TABLE inv.StockTxn (
    TxnID           BIGINT          IDENTITY(1,1) NOT NULL CONSTRAINT PK_inv_StockTxn PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    ItemID          INT             NOT NULL,
    TxnType         NVARCHAR(20)    NOT NULL,      -- Purchase / Issue / Return / Adjust / Damage
    Qty             DECIMAL(18,2)   NOT NULL,      -- signed: positive adds, negative removes
    Rate            DECIMAL(18,2)   NOT NULL CONSTRAINT DF_inv_StockTxn_Rate   DEFAULT (0),
    Amount          DECIMAL(18,2)   NOT NULL CONSTRAINT DF_inv_StockTxn_Amount DEFAULT (0),
    EmpID           INT             NULL,
    TxnDate         DATE            NOT NULL CONSTRAINT DF_inv_StockTxn_TxnDate DEFAULT (CAST(SYSDATETIME() AS DATE)),
    RefNo           NVARCHAR(50)    NULL,
    Remark          NVARCHAR(500)   NULL,
    IsCancel        BIT             NOT NULL CONSTRAINT DF_inv_StockTxn_IsCancel   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_inv_StockTxn_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_inv_StockTxn_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_inv_StockTxn_Branch   FOREIGN KEY (BranchID)  REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_inv_StockTxn_Item     FOREIGN KEY (ItemID)    REFERENCES mst.UniformItem (ItemID),
    CONSTRAINT FK_inv_StockTxn_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT CK_inv_StockTxn_Type CHECK (TxnType IN (N'Purchase',N'Issue',N'Return',N'Adjust',N'Damage'))
);
GO

/*------------------------------------------------- ISSUE / RETURN PER GUARD */
IF OBJECT_ID('inv.EmployeeIssue','U') IS NULL
CREATE TABLE inv.EmployeeIssue (
    IssueID          INT            IDENTITY(1,1) NOT NULL CONSTRAINT PK_inv_EmployeeIssue PRIMARY KEY,
    CompanyID        INT            NOT NULL,
    BranchID         INT            NULL,
    EmpID            INT            NOT NULL,
    ItemID           INT            NOT NULL,
    IssuedQty        DECIMAL(18,2)  NOT NULL CONSTRAINT DF_inv_EmployeeIssue_IssuedQty   DEFAULT (0),
    RecievedQty      DECIMAL(18,2)  NOT NULL CONSTRAINT DF_inv_EmployeeIssue_RecievedQty DEFAULT (0),
    OutstandingQty   AS (IssuedQty - RecievedQty) PERSISTED,
    IssueDate        DATE           NOT NULL CONSTRAINT DF_inv_EmployeeIssue_IssueDate DEFAULT (CAST(SYSDATETIME() AS DATE)),
    ReturnDate       DATE           NULL,
    Rate             DECIMAL(18,2)  NOT NULL CONSTRAINT DF_inv_EmployeeIssue_Rate DEFAULT (0),
    RecoverInSalary  BIT            NOT NULL CONSTRAINT DF_inv_EmployeeIssue_Recover DEFAULT (0),
    RecoveredAmount  DECIMAL(18,2)  NOT NULL CONSTRAINT DF_inv_EmployeeIssue_Recovered DEFAULT (0),
    Remark           NVARCHAR(500)  NULL,
    IsCancel         BIT            NOT NULL CONSTRAINT DF_inv_EmployeeIssue_IsCancel   DEFAULT (0),
    InsertDate       DATETIME2(0)   NOT NULL CONSTRAINT DF_inv_EmployeeIssue_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID     INT            NULL,
    UpdateDate       DATETIME2(0)   NULL,
    UpdateUserID     INT            NULL,
    CONSTRAINT FK_inv_EmployeeIssue_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_inv_EmployeeIssue_Branch   FOREIGN KEY (BranchID)  REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_inv_EmployeeIssue_Employee FOREIGN KEY (EmpID)     REFERENCES hr.Employee (EmpID),
    CONSTRAINT FK_inv_EmployeeIssue_Item     FOREIGN KEY (ItemID)    REFERENCES mst.UniformItem (ItemID),
    CONSTRAINT CK_inv_EmployeeIssue_Qty CHECK (RecievedQty <= IssuedQty)
);
GO

PRINT '110_inventory_tables.sql  ->  OK  (3 tables)';
GO
