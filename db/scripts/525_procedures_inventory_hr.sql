/*==============================================================================
  525_procedures_inventory_hr.sql
  Uniform stock and issue, plus HR lifecycle (resign / left / rejoin / training
  / requests / advances).
  Spec: docs/prd/01-database.md §7.2 ; split rationale DECISIONS.md #21
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*==============================================================================
  UNIFORM STOCK
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Uniform_StockIn
    @CompanyID INT,
    @UserID    INT,
    @BranchID  INT,
    @ItemID    INT,
    @Qty       DECIMAL(18,2),
    @Rate      DECIMAL(18,2) = 0,
    @RefNo     NVARCHAR(50)  = NULL,
    @Remark    NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Qty <= 0 THROW 51600, 'Quantity must be greater than zero.', 1;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO inv.StockTxn (CompanyID, BranchID, ItemID, TxnType, Qty, Rate, Amount,
                                  TxnDate, RefNo, Remark, InsertDate, InsertUserID)
        VALUES (@CompanyID, @BranchID, @ItemID, N'Purchase', @Qty, @Rate, @Qty * @Rate,
                CAST(SYSDATETIME() AS DATE), @RefNo, @Remark, SYSDATETIME(), @UserID);

        UPDATE inv.Stock WITH (UPDLOCK, HOLDLOCK)
        SET Qty = Qty + @Qty, UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
        WHERE CompanyID = @CompanyID AND ISNULL(BranchID, 0) = ISNULL(@BranchID, 0)
          AND ItemID = @ItemID AND IsCancel = 0;

        IF @@ROWCOUNT = 0
            INSERT INTO inv.Stock (CompanyID, BranchID, ItemID, Opstock, Qty, InsertDate, InsertUserID)
            VALUES (@CompanyID, @BranchID, @ItemID, @Qty, @Qty, SYSDATETIME(), @UserID);

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @ItemID, Message = N'Stock added';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Uniform_IssueToEmployee
    @CompanyID       INT,
    @UserID          INT,
    @EmpID           INT,
    @ItemID          INT,
    @Qty             DECIMAL(18,2),
    @Rate            DECIMAL(18,2) = NULL,
    @RecoverInSalary BIT           = 0,
    @Remark          NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Qty <= 0 THROW 51600, 'Quantity must be greater than zero.', 1;

    DECLARE @BranchID INT, @Available DECIMAL(18,2), @IssueID INT;

    SELECT @BranchID = BranchID FROM hr.Employee
    WHERE EmpID = @EmpID AND CompanyID = @CompanyID AND IsCancel = 0;

    IF @BranchID IS NULL AND NOT EXISTS (SELECT 1 FROM hr.Employee WHERE EmpID = @EmpID AND CompanyID = @CompanyID)
        THROW 51601, 'Employee not found.', 1;

    IF @Rate IS NULL SELECT @Rate = Rate FROM mst.UniformItem WHERE ItemID = @ItemID;

    BEGIN TRY
        BEGIN TRAN;

        SELECT @Available = Qty FROM inv.Stock WITH (UPDLOCK, HOLDLOCK)
        WHERE CompanyID = @CompanyID AND ISNULL(BranchID, 0) = ISNULL(@BranchID, 0)
          AND ItemID = @ItemID AND IsCancel = 0;

        IF ISNULL(@Available, 0) < @Qty
            THROW 51602, 'Not enough stock at this branch.', 1;

        UPDATE inv.Stock
        SET Qty = Qty - @Qty, UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
        WHERE CompanyID = @CompanyID AND ISNULL(BranchID, 0) = ISNULL(@BranchID, 0)
          AND ItemID = @ItemID AND IsCancel = 0;

        INSERT INTO inv.StockTxn (CompanyID, BranchID, ItemID, TxnType, Qty, Rate, Amount,
                                  EmpID, TxnDate, Remark, InsertDate, InsertUserID)
        VALUES (@CompanyID, @BranchID, @ItemID, N'Issue', -@Qty, @Rate, @Qty * @Rate,
                @EmpID, CAST(SYSDATETIME() AS DATE), @Remark, SYSDATETIME(), @UserID);

        INSERT INTO inv.EmployeeIssue (CompanyID, BranchID, EmpID, ItemID, IssuedQty, RecievedQty,
                                       IssueDate, Rate, RecoverInSalary, Remark, InsertDate, InsertUserID)
        VALUES (@CompanyID, @BranchID, @EmpID, @ItemID, @Qty, 0,
                CAST(SYSDATETIME() AS DATE), @Rate, @RecoverInSalary, @Remark, SYSDATETIME(), @UserID);

        SET @IssueID = SCOPE_IDENTITY();

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @IssueID, Message = N'Uniform issued';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Uniform_ReturnFromEmployee
    @CompanyID INT,
    @UserID    INT,
    @IssueID   INT,
    @Qty       DECIMAL(18,2),
    @Remark    NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @BranchID INT, @ItemID INT, @EmpID INT, @Issued DECIMAL(18,2),
            @Received DECIMAL(18,2), @Rate DECIMAL(18,2);

    SELECT @BranchID = BranchID, @ItemID = ItemID, @EmpID = EmpID,
           @Issued = IssuedQty, @Received = RecievedQty, @Rate = Rate
    FROM inv.EmployeeIssue
    WHERE IssueID = @IssueID AND CompanyID = @CompanyID AND IsCancel = 0;

    IF @ItemID IS NULL THROW 51603, 'Issue record not found.', 1;
    IF @Qty <= 0 THROW 51600, 'Quantity must be greater than zero.', 1;
    IF @Received + @Qty > @Issued THROW 51604, 'Return quantity exceeds the issued quantity.', 1;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE inv.EmployeeIssue
        SET RecievedQty = RecievedQty + @Qty,
            ReturnDate = CAST(SYSDATETIME() AS DATE),
            UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
        WHERE IssueID = @IssueID;

        UPDATE inv.Stock
        SET Qty = Qty + @Qty, UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
        WHERE CompanyID = @CompanyID AND ISNULL(BranchID, 0) = ISNULL(@BranchID, 0)
          AND ItemID = @ItemID AND IsCancel = 0;

        INSERT INTO inv.StockTxn (CompanyID, BranchID, ItemID, TxnType, Qty, Rate, Amount,
                                  EmpID, TxnDate, Remark, InsertDate, InsertUserID)
        VALUES (@CompanyID, @BranchID, @ItemID, N'Return', @Qty, @Rate, @Qty * @Rate,
                @EmpID, CAST(SYSDATETIME() AS DATE), @Remark, SYSDATETIME(), @UserID);

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @IssueID, Message = N'Uniform returned';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Uniform_GetStock
    @CompanyID INT,
    @UserID    INT,
    @BranchID  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.StockID, s.ItemID, i.ItemName, i.Rate, i.Uom, i.IsReturnable,
        s.BranchID, b.BranchName, s.Opstock, s.Qty, s.MinLevel,
        IsBelowMinimum = CASE WHEN s.Qty < s.MinLevel THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END,
        StockValue = s.Qty * i.Rate,
        IssuedOutstanding = ISNULL(o.OutQty, 0)
    FROM inv.Stock AS s
    INNER JOIN mst.UniformItem AS i ON i.ItemID = s.ItemID
    LEFT  JOIN org.Branch AS b ON b.BranchID = s.BranchID
    OUTER APPLY (SELECT OutQty = SUM(e.OutstandingQty)
                 FROM inv.EmployeeIssue AS e
                 WHERE e.CompanyID = s.CompanyID AND e.ItemID = s.ItemID
                   AND ISNULL(e.BranchID, 0) = ISNULL(s.BranchID, 0) AND e.IsCancel = 0) AS o
    WHERE s.CompanyID = @CompanyID AND s.IsCancel = 0
      AND (@BranchID IS NULL OR s.BranchID = @BranchID)
      AND (s.BranchID IS NULL
           OR EXISTS (SELECT 1 FROM dbo.fnUserAccessibleBranches(@CompanyID, @UserID) AS ab
                      WHERE ab.BranchID = s.BranchID))
    ORDER BY b.BranchName, i.ItemName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Uniform_GetLedger
    @CompanyID INT,
    @UserID    INT,
    @EmpID     INT = NULL,
    @BranchID  INT = NULL,
    @PageNo    INT = 1,
    @PageSize  INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;

    SELECT EmpID, EmpCode, EmpFullName, ItemID, ItemName,
           IssuedQty, RecievedQty, OutstandingQty, OutstandingValue,
           RecoveredAmount, LastIssueDate
    FROM dbo.vwUniformLedger
    WHERE CompanyID = @CompanyID
      AND (@EmpID    IS NULL OR EmpID = @EmpID)
      AND (@BranchID IS NULL OR BranchID = @BranchID)
    ORDER BY EmpFullName, ItemName
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM dbo.vwUniformLedger
    WHERE CompanyID = @CompanyID
      AND (@EmpID    IS NULL OR EmpID = @EmpID)
      AND (@BranchID IS NULL OR BranchID = @BranchID);
END;
GO

/*==============================================================================
  HR LIFECYCLE
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Hr_LifecycleEvent
    @CompanyID  INT,
    @UserID     INT,
    @EmpID      INT,
    @EventType  NVARCHAR(20),          -- Resign / Left / Rejoin
    @EventDate  DATE,
    @Timing     NVARCHAR(50)  = NULL,
    @Remark     NVARCHAR(500) = NULL,
    @DocUrl     NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EventType NOT IN (N'Resign', N'Left', N'Rejoin')
        THROW 51605, 'EventType must be Resign, Left or Rejoin.', 1;

    DECLARE @HistoryID INT, @FromUnitID INT;
    SELECT @FromUnitID = UnitID FROM hr.Employee WHERE EmpID = @EmpID AND CompanyID = @CompanyID;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO hr.EmployeeStatusHistory (CompanyID, EmpID, EventType, EventDate, Timing,
                                              FromUnitID, Remark, DocUrl, IsApproved,
                                              InsertDate, InsertUserID)
        VALUES (@CompanyID, @EmpID, @EventType, @EventDate, @Timing,
                @FromUnitID, @Remark, @DocUrl, 1, SYSDATETIME(), @UserID);

        SET @HistoryID = SCOPE_IDENTITY();

        IF @EventType IN (N'Resign', N'Left')
        BEGIN
            UPDATE hr.Employee
            SET EmpStatus  = CASE WHEN @EventType = N'Resign' THEN N'Resigned' ELSE N'Left' END,
                Dol        = @EventDate,
                DateofLeft = CASE WHEN @EventType = N'Left' THEN @EventDate ELSE DateofLeft END,
                LeftReason = ISNULL(@Remark, LeftReason),
                UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
            WHERE EmpID = @EmpID AND CompanyID = @CompanyID;

            UPDATE ops.Deployment
            SET Status = N'Ended', ToDate = @EventDate,
                UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
            WHERE CompanyID = @CompanyID AND EmpID = @EmpID AND Status = N'Active';
        END
        ELSE  -- Rejoin
            UPDATE hr.Employee
            SET EmpStatus = N'Active', Dol = NULL, DateofLeft = NULL, LeftReason = NULL,
                Doj = ISNULL(Doj, @EventDate),
                UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
            WHERE EmpID = @EmpID AND CompanyID = @CompanyID;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @HistoryID,
           Message = CONCAT(@EventType, N' recorded');
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Hr_LifecycleReport
    @CompanyID INT,
    @UserID    INT,
    @EventType NVARCHAR(20) = NULL,
    @FromDate  DATE = NULL,
    @ToDate    DATE = NULL,
    @BranchID  INT  = NULL,
    @PageNo    INT  = 1,
    @PageSize  INT  = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;
    IF @FromDate IS NULL SET @FromDate = DATEADD(DAY, -30, CAST(SYSDATETIME() AS DATE));
    IF @ToDate   IS NULL SET @ToDate   = CAST(SYSDATETIME() AS DATE);

    SELECT
        h.HistoryID, h.EventType, h.EventDate, h.Timing, h.Remark, h.DocUrl,
        h.EmpID, e.EmpCode, GuardName = e.EmpFullName, d.DesignationName,
        FromUnitID = h.FromUnitID, UnitName = fu.UnitName, ToUnitName = tu.UnitName,
        Dated = h.EventDate
    FROM hr.EmployeeStatusHistory AS h
    INNER JOIN hr.Employee AS e ON e.EmpID = h.EmpID
    LEFT  JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    LEFT  JOIN crm.Unit AS fu ON fu.UnitID = h.FromUnitID
    LEFT  JOIN crm.Unit AS tu ON tu.UnitID = h.ToUnitID
    WHERE h.CompanyID = @CompanyID AND h.IsCancel = 0
      AND h.EventDate BETWEEN @FromDate AND @ToDate
      AND (@EventType IS NULL OR h.EventType = @EventType)
      AND (@BranchID  IS NULL OR e.BranchID = @BranchID)
    ORDER BY h.EventDate DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM hr.EmployeeStatusHistory AS h
    INNER JOIN hr.Employee AS e ON e.EmpID = h.EmpID
    WHERE h.CompanyID = @CompanyID AND h.IsCancel = 0
      AND h.EventDate BETWEEN @FromDate AND @ToDate
      AND (@EventType IS NULL OR h.EventType = @EventType)
      AND (@BranchID  IS NULL OR e.BranchID = @BranchID);
END;
GO

/*==============================================================================
  TRAINING
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Training_Save
    @CompanyID    INT,
    @UserID       INT,
    @UnitID       INT           = NULL,
    @Dated        DATE,
    @Timing       NVARCHAR(50)  = NULL,
    @Topic        NVARCHAR(200) = NULL,
    @Remark       NVARCHAR(500) = NULL,
    @PhotoUrl     NVARCHAR(500) = NULL,
    @AttendeeIdsCsv NVARCHAR(MAX) = NULL,
    @TrainingID   INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @BranchID INT, @TrainerEmpID INT;
    SELECT @BranchID = BranchID FROM crm.Unit WHERE UnitID = @UnitID;
    SELECT @TrainerEmpID = EmpID FROM sec.Users WHERE UserID = @UserID;

    BEGIN TRY
        BEGIN TRAN;

        IF @TrainingID IS NULL
        BEGIN
            INSERT INTO hr.Training (CompanyID, BranchID, UnitID, TrainerEmpID, Dated, Timing,
                                     Topic, Remark, PhotoUrl, InsertDate, InsertUserID)
            VALUES (@CompanyID, @BranchID, @UnitID, @TrainerEmpID, @Dated, @Timing,
                    @Topic, @Remark, @PhotoUrl, SYSDATETIME(), @UserID);
            SET @TrainingID = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE hr.Training
            SET UnitID = @UnitID, Dated = @Dated, Timing = @Timing, Topic = @Topic,
                Remark = @Remark, PhotoUrl = @PhotoUrl,
                UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
            WHERE TrainingID = @TrainingID AND CompanyID = @CompanyID;

        IF @AttendeeIdsCsv IS NOT NULL
        BEGIN
            DELETE FROM hr.TrainingAttendee WHERE TrainingID = @TrainingID;

            INSERT INTO hr.TrainingAttendee (TrainingID, EmpID, IsPresent, InsertDate, InsertUserID)
            SELECT @TrainingID, ids.ID, 1, SYSDATETIME(), @UserID
            FROM dbo.fnSplitIds(@AttendeeIdsCsv) AS ids
            WHERE EXISTS (SELECT 1 FROM hr.Employee AS e WHERE e.EmpID = ids.ID AND e.CompanyID = @CompanyID);

            UPDATE hr.Training
            SET Nop = (SELECT COUNT(*) FROM hr.TrainingAttendee WHERE TrainingID = @TrainingID)
            WHERE TrainingID = @TrainingID;
        END

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @TrainingID, Message = N'Training saved';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Training_GetReport
    @CompanyID INT,
    @UserID    INT,
    @FromDate  DATE = NULL,
    @ToDate    DATE = NULL,
    @UnitID    INT  = NULL,
    @PageNo    INT  = 1,
    @PageSize  INT  = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;
    IF @FromDate IS NULL SET @FromDate = DATEADD(DAY, -90, CAST(SYSDATETIME() AS DATE));
    IF @ToDate   IS NULL SET @ToDate   = CAST(SYSDATETIME() AS DATE);

    SELECT t.TrainingID, t.Dated, t.Timing, t.Topic, t.Nop, t.Remark, t.PhotoUrl,
           t.UnitID, u.UnitName, TrainerName = e.EmpFullName
    FROM hr.Training AS t
    LEFT JOIN crm.Unit AS u ON u.UnitID = t.UnitID
    LEFT JOIN hr.Employee AS e ON e.EmpID = t.TrainerEmpID
    WHERE t.CompanyID = @CompanyID AND t.IsCancel = 0
      AND t.Dated BETWEEN @FromDate AND @ToDate
      AND (@UnitID IS NULL OR t.UnitID = @UnitID)
    ORDER BY t.Dated DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM hr.Training AS t
    WHERE t.CompanyID = @CompanyID AND t.IsCancel = 0
      AND t.Dated BETWEEN @FromDate AND @ToDate
      AND (@UnitID IS NULL OR t.UnitID = @UnitID);
END;
GO

/*==============================================================================
  REQUESTS AND ADVANCES
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Request_Insert
    @CompanyID   INT,
    @UserID      INT,
    @RequestType NVARCHAR(20),
    @FromDate    DATE          = NULL,
    @ToDate      DATE          = NULL,
    @Amount      DECIMAL(18,2) = NULL,
    @Reason      NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @EmpID INT, @Id INT;
    SELECT @EmpID = EmpID FROM sec.Users WHERE UserID = @UserID;

    IF @EmpID IS NULL THROW 51606, 'This login is not linked to an employee record.', 1;

    INSERT INTO hr.EmployeeRequest (CompanyID, EmpID, RequestType, FromDate, ToDate, Amount,
                                    Reason, Status, InsertDate, InsertUserID)
    VALUES (@CompanyID, @EmpID, @RequestType, @FromDate, @ToDate, @Amount,
            @Reason, N'Pending', SYSDATETIME(), @UserID);
    SET @Id = SCOPE_IDENTITY();

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @Id, Message = N'Request submitted';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Request_Approve
    @CompanyID INT,
    @UserID    INT,
    @RequestID INT,
    @Approve   BIT,
    @Remark    NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE hr.EmployeeRequest
    SET Status     = CASE WHEN @Approve = 1 THEN N'Approved' ELSE N'Rejected' END,
        IsApproved = @Approve,
        IsReject   = CASE WHEN @Approve = 1 THEN 0 ELSE 1 END,
        ApprovedBy = @UserID, ApprovedOn = SYSDATETIME(), Remark = @Remark,
        UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
    WHERE RequestID = @RequestID AND CompanyID = @CompanyID AND Status = N'Pending';

    SELECT Success = CAST(CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END AS BIT),
           Status = CASE WHEN @@ROWCOUNT > 0 THEN 200 ELSE 404 END,
           Id = @RequestID,
           Message = CASE WHEN @Approve = 1 THEN N'Approved' ELSE N'Rejected' END;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Advance_Insert
    @CompanyID         INT,
    @UserID            INT,
    @EmpID             INT,
    @Amount            DECIMAL(18,2),
    @InstallmentAmount DECIMAL(18,2) = NULL,
    @Reason            NVARCHAR(500) = NULL,
    @IssueDate         DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Amount <= 0 THROW 51607, 'Advance amount must be greater than zero.', 1;
    IF @IssueDate IS NULL SET @IssueDate = CAST(SYSDATETIME() AS DATE);

    DECLARE @AdvanceID INT, @BranchID INT, @Outstanding DECIMAL(18,2);

    SELECT @BranchID = BranchID FROM hr.Employee WHERE EmpID = @EmpID AND CompanyID = @CompanyID;

    SELECT @Outstanding = ISNULL(SUM(BalanceAmount), 0)
    FROM fin.Advance
    WHERE CompanyID = @CompanyID AND EmpID = @EmpID AND IsCancel = 0
      AND Status IN (N'Approved', N'Recovering');

    IF @Outstanding > 0
        THROW 51608, 'This employee already has an advance outstanding. Recover it before issuing another.', 1;

    INSERT INTO fin.Advance (CompanyID, BranchID, EmpID, Amount, IssueDate, Reason,
                             InstallmentAmount, BalanceAmount, Status, InsertDate, InsertUserID)
    VALUES (@CompanyID, @BranchID, @EmpID, @Amount, @IssueDate, @Reason,
            ISNULL(@InstallmentAmount, @Amount), @Amount, N'Pending', SYSDATETIME(), @UserID);

    SET @AdvanceID = SCOPE_IDENTITY();

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @AdvanceID,
           Message = N'Advance recorded, pending approval';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Advance_Approve
    @CompanyID INT,
    @UserID    INT,
    @AdvanceID INT,
    @Approve   BIT,
    @Remark    NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE fin.Advance
    SET Status     = CASE WHEN @Approve = 1 THEN N'Approved' ELSE N'Rejected' END,
        IsApproved = @Approve,
        IsReject   = CASE WHEN @Approve = 1 THEN 0 ELSE 1 END,
        ApprovedBy = @UserID, ApprovedOn = SYSDATETIME(),
        BalanceAmount = CASE WHEN @Approve = 1 THEN Amount ELSE 0 END,
        UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
    WHERE AdvanceID = @AdvanceID AND CompanyID = @CompanyID AND Status = N'Pending';

    SELECT Success = CAST(CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END AS BIT),
           Status = CASE WHEN @@ROWCOUNT > 0 THEN 200 ELSE 404 END,
           Id = @AdvanceID,
           Message = CASE WHEN @Approve = 1 THEN N'Advance approved' ELSE N'Advance rejected' END;
END;
GO

/*==============================================================================
  DOCUMENTS
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Document_Save
    @CompanyID        INT,
    @UserID           INT,
    @OwnerType        NVARCHAR(20),
    @OwnerID          INT,
    @BlobUrl          NVARCHAR(1000),
    @DocTypeID        INT            = NULL,
    @DocumentFilename NVARCHAR(300)  = NULL,
    @MimeType         NVARCHAR(100)  = NULL,
    @SizeBytes        BIGINT         = NULL,
    @IssueDate        DATE           = NULL,
    @ExpiryDate       DATE           = NULL,
    @Remark           NVARCHAR(500)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @DocumentID INT;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO doc.Document (CompanyID, OwnerType, OwnerID, DocTypeID, DocumentFilename,
                                  BlobUrl, MimeType, SizeBytes, IssueDate, ExpiryDate,
                                  Remark, InsertDate, InsertUserID)
        VALUES (@CompanyID, @OwnerType, @OwnerID, @DocTypeID, @DocumentFilename,
                @BlobUrl, @MimeType, @SizeBytes, @IssueDate, @ExpiryDate,
                @Remark, SYSDATETIME(), @UserID);

        SET @DocumentID = SCOPE_IDENTITY();

        /* expiry alerts at T-90, T-30 and T-7 */
        IF @ExpiryDate IS NOT NULL
            INSERT INTO doc.DocumentExpiryAlert (CompanyID, DocumentID, AlertOn, AlertLevel)
            SELECT @CompanyID, @DocumentID, DATEADD(DAY, -lvl.Days, @ExpiryDate), lvl.Days
            FROM (VALUES (90), (30), (7)) AS lvl(Days)
            WHERE DATEADD(DAY, -lvl.Days, @ExpiryDate) >= CAST(SYSDATETIME() AS DATE);

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @DocumentID, Message = N'Document saved';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Document_GetExpiring
    @CompanyID INT,
    @UserID    INT,
    @WithinDays INT = 30,
    @PageNo    INT = 1,
    @PageSize  INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;

    SELECT DocumentID, OwnerType, OwnerID, OwnerName, DocTypeID, DocTypeName,
           DocumentFilename, IssueDate, ExpiryDate, DaysToExpiry, ExpiryBucket, IsVerified
    FROM dbo.vwDocumentExpiry
    WHERE CompanyID = @CompanyID
      AND ExpiryDate < DATEADD(DAY, @WithinDays, CAST(SYSDATETIME() AS DATE))
    ORDER BY ExpiryDate
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM dbo.vwDocumentExpiry
    WHERE CompanyID = @CompanyID
      AND ExpiryDate < DATEADD(DAY, @WithinDays, CAST(SYSDATETIME() AS DATE));
END;
GO

PRINT '525_procedures_inventory_hr.sql  ->  OK  (15 procedures)';
GO
