/*==============================================================================
  561_procedures_lists.sql
  Three list procedures the earlier scripts never wrote.

  crm.Client, fin.Advance and fin.Receipt all had Save/Insert/Approve
  procedures but no way to read a page of them, so the web app had no client
  list, no advances screen and no receipts screen. Every other list in the
  system goes through a *_GetList procedure; these three now match.

  Contract: result set 1 is the page, result set 2 is a single TotalRows
  column. That is what IDbExecutor.QueryPagedAsync expects.
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*==============================================================================
  usp_Client_GetList
  One row per client with the numbers the list screen shows without a drill-in:
  how many units, how much is deployed there, what is unpaid, how many
  complaints are open.
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Client_GetList
    @CompanyID INT,
    @UserID    INT,
    @BranchID  INT           = NULL,
    @Search    NVARCHAR(200) = NULL,
    @Status    NVARCHAR(20)  = NULL,   -- Active / Inactive / Expired
    @PageNo    INT           = 1,
    @PageSize  INT           = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo   IS NULL OR @PageNo   < 1 SET @PageNo   = 1;

    /*  A client is visible when at least one of its units is visible to this
        user. Branch admins and supervisors therefore see only their own
        clients, without a second permission model to keep in step.  */
    ;WITH visible AS (
        SELECT DISTINCT u.ClientID
        FROM crm.Unit AS u
        INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = u.UnitID
        WHERE u.CompanyID = @CompanyID AND u.IsCancel = 0
    ),
    matched AS (
        SELECT c.ClientID
        FROM crm.Client AS c
        WHERE c.CompanyID = @CompanyID
          AND c.IsCancel  = 0
          AND (c.ClientID IN (SELECT ClientID FROM visible)
               /* A client created but not yet given a unit would otherwise be
                  invisible to everyone, including the person who just added it. */
               OR NOT EXISTS (SELECT 1 FROM crm.Unit AS u2
                              WHERE u2.ClientID = c.ClientID AND u2.IsCancel = 0))
          AND (@BranchID IS NULL OR c.BranchID = @BranchID)
          AND (@Search   IS NULL OR c.ClientName    LIKE N'%' + @Search + N'%'
                                 OR c.ClientCode    LIKE N'%' + @Search + N'%'
                                 OR c.ContactPerson LIKE N'%' + @Search + N'%'
                                 OR c.GSTIN         LIKE N'%' + @Search + N'%')
          AND (@Status IS NULL
               OR (@Status = N'Active'   AND c.IsActive = 1 AND c.IsExpired = 0)
               OR (@Status = N'Inactive' AND c.IsActive = 0)
               OR (@Status = N'Expired'  AND c.IsExpired = 1))
    )
    SELECT
        c.ClientID, c.ClientName, c.ClientCode, c.CompanyAddress,
        c.ContactPerson, c.ContactNo, c.Email, c.GSTIN, c.PAN,
        c.BranchID, b.BranchName, c.StateID, s.StateName, c.CityID, ct.CityName,
        c.IsActive, c.IsExpired, c.IsApproved, c.InsertDate,
        UnitCount       = ISNULL(un.Cnt, 0),
        DeployedNos     = ISNULL(dp.Cnt, 0),
        OpenComplaints  = ISNULL(cp.Cnt, 0),
        OutstandingAmt  = ISNULL(iv.Outstanding, 0),
        OverdueInvoices = ISNULL(iv.Overdue, 0),
        LastInvoiceOn   = iv.LastInvoiceOn
    FROM crm.Client AS c
    INNER JOIN matched AS m ON m.ClientID = c.ClientID
    LEFT  JOIN org.Branch AS b  ON b.BranchID = c.BranchID
    LEFT  JOIN mst.State  AS s  ON s.StateID  = c.StateID
    LEFT  JOIN mst.City   AS ct ON ct.CityID  = c.CityID
    OUTER APPLY (SELECT Cnt = COUNT(*) FROM crm.Unit AS u
                 WHERE u.ClientID = c.ClientID AND u.IsCancel = 0) AS un
    OUTER APPLY (SELECT Cnt = COUNT(*)
                 FROM ops.Deployment AS d
                 INNER JOIN crm.Unit AS u2 ON u2.UnitID = d.UnitID
                 WHERE u2.ClientID = c.ClientID AND d.Status = N'Active' AND d.IsCancel = 0) AS dp
    OUTER APPLY (SELECT Cnt = COUNT(*)
                 FROM ops.Complaint AS cm
                 WHERE cm.ClientID = c.ClientID AND cm.IsClosed = 0 AND cm.IsCancel = 0) AS cp
    OUTER APPLY (SELECT Outstanding   = SUM(i.GrandTotal - i.ReceivedAmount),
                        Overdue       = SUM(CASE WHEN i.Status = N'Overdue' THEN 1 ELSE 0 END),
                        LastInvoiceOn = MAX(i.InvoiceDate)
                 FROM fin.Invoice AS i
                 WHERE i.ClientID = c.ClientID AND i.IsCancel = 0) AS iv
    ORDER BY c.ClientName
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    ;WITH visible AS (
        SELECT DISTINCT u.ClientID
        FROM crm.Unit AS u
        INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = u.UnitID
        WHERE u.CompanyID = @CompanyID AND u.IsCancel = 0
    )
    SELECT TotalRows = COUNT(*)
    FROM crm.Client AS c
    WHERE c.CompanyID = @CompanyID
      AND c.IsCancel  = 0
      AND (c.ClientID IN (SELECT ClientID FROM visible)
           OR NOT EXISTS (SELECT 1 FROM crm.Unit AS u2
                          WHERE u2.ClientID = c.ClientID AND u2.IsCancel = 0))
      AND (@BranchID IS NULL OR c.BranchID = @BranchID)
      AND (@Search   IS NULL OR c.ClientName    LIKE N'%' + @Search + N'%'
                             OR c.ClientCode    LIKE N'%' + @Search + N'%'
                             OR c.ContactPerson LIKE N'%' + @Search + N'%'
                             OR c.GSTIN         LIKE N'%' + @Search + N'%')
      AND (@Status IS NULL
           OR (@Status = N'Active'   AND c.IsActive = 1 AND c.IsExpired = 0)
           OR (@Status = N'Inactive' AND c.IsActive = 0)
           OR (@Status = N'Expired'  AND c.IsExpired = 1));
END;
GO

/*==============================================================================
  usp_Advance_GetList
  Salary advances with what has actually been recovered so far, which is the
  only number an accounts user cares about.
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Advance_GetList
    @CompanyID INT,
    @UserID    INT,
    @EmpID     INT           = NULL,
    @BranchID  INT           = NULL,
    @Status    NVARCHAR(20)  = NULL,
    @Search    NVARCHAR(200) = NULL,
    @From      DATE          = NULL,
    @To        DATE          = NULL,
    @PageNo    INT           = 1,
    @PageSize  INT           = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo   IS NULL OR @PageNo   < 1 SET @PageNo   = 1;

    SELECT
        a.AdvanceID, a.EmpID, e.EmpCode, e.EmpFullName, MobileNo = e.Mobile1,
        d.DesignationName, u.UnitID, u.UnitName,
        a.BranchID, b.BranchName,
        a.Amount, a.InstallmentAmount, a.BalanceAmount,
        RecoveredAmount = a.Amount - a.BalanceAmount,
        RecoveredPct    = CASE WHEN a.Amount > 0
                               THEN CAST(ROUND(((a.Amount - a.BalanceAmount) * 100.0) / a.Amount, 1) AS DECIMAL(5,1))
                               ELSE 0 END,
        a.IssueDate, a.Reason, a.Status, a.IsApproved, a.IsReject,
        a.ApprovedOn, ApprovedByName = ap.UserName,
        a.InsertDate
    FROM fin.Advance AS a
    INNER JOIN hr.Employee AS e ON e.EmpID = a.EmpID
    LEFT  JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    LEFT  JOIN crm.Unit  AS u  ON u.UnitID   = e.UnitID
    LEFT  JOIN org.Branch AS b ON b.BranchID = a.BranchID
    LEFT  JOIN sec.Users AS ap ON ap.UserID  = a.ApprovedBy
    WHERE a.CompanyID = @CompanyID
      AND a.IsCancel  = 0
      /* An employee with no unit yet (fresh joiner) must still be listed, so
         the accessibility check allows a NULL unit rather than dropping them. */
      AND (e.UnitID IS NULL
           OR EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au
                      WHERE au.UnitID = e.UnitID))
      AND (@EmpID    IS NULL OR a.EmpID    = @EmpID)
      AND (@BranchID IS NULL OR a.BranchID = @BranchID)
      AND (@Status   IS NULL OR a.Status   = @Status)
      AND (@From     IS NULL OR a.IssueDate >= @From)
      AND (@To       IS NULL OR a.IssueDate <= @To)
      AND (@Search   IS NULL OR e.EmpFullName LIKE N'%' + @Search + N'%'
                             OR e.EmpCode     LIKE N'%' + @Search + N'%')
    ORDER BY a.IssueDate DESC, a.AdvanceID DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM fin.Advance AS a
    INNER JOIN hr.Employee AS e ON e.EmpID = a.EmpID
    WHERE a.CompanyID = @CompanyID
      AND a.IsCancel  = 0
      AND (e.UnitID IS NULL
           OR EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au
                      WHERE au.UnitID = e.UnitID))
      AND (@EmpID    IS NULL OR a.EmpID    = @EmpID)
      AND (@BranchID IS NULL OR a.BranchID = @BranchID)
      AND (@Status   IS NULL OR a.Status   = @Status)
      AND (@From     IS NULL OR a.IssueDate >= @From)
      AND (@To       IS NULL OR a.IssueDate <= @To)
      AND (@Search   IS NULL OR e.EmpFullName LIKE N'%' + @Search + N'%'
                             OR e.EmpCode     LIKE N'%' + @Search + N'%');
END;
GO

/*==============================================================================
  usp_Receipt_GetList
  Collections against invoices. Used by the receipts screen and by the ageing
  report's drill-down.
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Receipt_GetList
    @CompanyID INT,
    @UserID    INT,
    @ClientID  INT           = NULL,
    @Bid       INT           = NULL,
    @BranchID  INT           = NULL,
    @Mode      NVARCHAR(30)  = NULL,
    @Search    NVARCHAR(200) = NULL,
    @From      DATE          = NULL,
    @To        DATE          = NULL,
    @PageNo    INT           = 1,
    @PageSize  INT           = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo   IS NULL OR @PageNo   < 1 SET @PageNo   = 1;

    SELECT
        r.ReceiptID, r.ClientID, c.ClientName, c.ClientCode,
        r.Bid, i.InvoiceNo, i.InvoiceDate, i.GrandTotal AS InvoiceAmount,
        InvoiceBalance = CASE WHEN i.Bid IS NULL THEN NULL
                              ELSE i.GrandTotal - i.ReceivedAmount END,
        r.Amount, r.ReceivedOn, r.Mode, r.RefNo, r.Remark,
        r.BranchID, b.BranchName,
        r.InsertDate, EnteredByName = eu.UserName
    FROM fin.Receipt AS r
    INNER JOIN crm.Client AS c ON c.ClientID = r.ClientID
    LEFT  JOIN fin.Invoice AS i ON i.Bid = r.Bid
    LEFT  JOIN org.Branch  AS b ON b.BranchID = r.BranchID
    LEFT  JOIN sec.Users   AS eu ON eu.UserID = r.InsertUserID
    WHERE r.CompanyID = @CompanyID
      AND r.IsCancel  = 0
      AND (@ClientID IS NULL OR r.ClientID = @ClientID)
      AND (@Bid      IS NULL OR r.Bid      = @Bid)
      AND (@BranchID IS NULL OR r.BranchID = @BranchID)
      AND (@Mode     IS NULL OR r.Mode     = @Mode)
      AND (@From     IS NULL OR r.ReceivedOn >= @From)
      AND (@To       IS NULL OR r.ReceivedOn <= @To)
      AND (@Search   IS NULL OR c.ClientName LIKE N'%' + @Search + N'%'
                             OR r.RefNo      LIKE N'%' + @Search + N'%'
                             OR i.InvoiceNo  LIKE N'%' + @Search + N'%')
    ORDER BY r.ReceivedOn DESC, r.ReceiptID DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM fin.Receipt AS r
    INNER JOIN crm.Client AS c ON c.ClientID = r.ClientID
    LEFT  JOIN fin.Invoice AS i ON i.Bid = r.Bid
    WHERE r.CompanyID = @CompanyID
      AND r.IsCancel  = 0
      AND (@ClientID IS NULL OR r.ClientID = @ClientID)
      AND (@Bid      IS NULL OR r.Bid      = @Bid)
      AND (@BranchID IS NULL OR r.BranchID = @BranchID)
      AND (@Mode     IS NULL OR r.Mode     = @Mode)
      AND (@From     IS NULL OR r.ReceivedOn >= @From)
      AND (@To       IS NULL OR r.ReceivedOn <= @To)
      AND (@Search   IS NULL OR c.ClientName LIKE N'%' + @Search + N'%'
                             OR r.RefNo      LIKE N'%' + @Search + N'%'
                             OR i.InvoiceNo  LIKE N'%' + @Search + N'%');
END;
GO

PRINT '561_procedures_lists.sql  ->  OK';
GO
