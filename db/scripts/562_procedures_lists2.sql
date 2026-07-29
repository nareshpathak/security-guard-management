/*==============================================================================
  562_procedures_lists2.sql
  Two more list procedures the earlier scripts never wrote.

  ops.FieldReport and hr.EmployeeRequest could be created and approved but not
  browsed, which left the field-report screen and the requests screen with
  nothing to call.
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*==============================================================================
  usp_FieldReport_GetList
  A supervisor's site visits, newest first, with how many per-guard remarks
  each one carries.
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_FieldReport_GetList
    @CompanyID INT,
    @UserID    INT,
    @UnitID    INT           = NULL,
    @BranchID  INT           = NULL,
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
        f.ReportID, f.UnitID, u.UnitName, c.ClientName,
        f.BranchID, b.BranchName,
        f.SupervisorEmpID, SupervisorName = e.EmpFullName,
        f.Createdate, f.ContactPerson, f.Remark,
        f.Latitude, f.Longitude, f.PhotoUrl,
        GuardRemarkCount = ISNULL(d.Cnt, 0)
    FROM ops.FieldReport AS f
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = f.UnitID
    LEFT  JOIN crm.Unit    AS u ON u.UnitID   = f.UnitID
    LEFT  JOIN crm.Client  AS c ON c.ClientID = u.ClientID
    LEFT  JOIN org.Branch  AS b ON b.BranchID = f.BranchID
    LEFT  JOIN hr.Employee AS e ON e.EmpID    = f.SupervisorEmpID
    OUTER APPLY (SELECT Cnt = COUNT(*) FROM ops.FieldReportDetail AS fd
                 WHERE fd.ReportID = f.ReportID) AS d
    WHERE f.CompanyID = @CompanyID
      AND f.IsCancel  = 0
      AND (@UnitID   IS NULL OR f.UnitID   = @UnitID)
      AND (@BranchID IS NULL OR f.BranchID = @BranchID)
      AND (@From     IS NULL OR CAST(f.Createdate AS DATE) >= @From)
      AND (@To       IS NULL OR CAST(f.Createdate AS DATE) <= @To)
      AND (@Search   IS NULL OR f.ContactPerson LIKE N'%' + @Search + N'%'
                             OR f.Remark        LIKE N'%' + @Search + N'%'
                             OR u.UnitName      LIKE N'%' + @Search + N'%')
    ORDER BY f.Createdate DESC, f.ReportID DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM ops.FieldReport AS f
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = f.UnitID
    LEFT  JOIN crm.Unit AS u ON u.UnitID = f.UnitID
    WHERE f.CompanyID = @CompanyID
      AND f.IsCancel  = 0
      AND (@UnitID   IS NULL OR f.UnitID   = @UnitID)
      AND (@BranchID IS NULL OR f.BranchID = @BranchID)
      AND (@From     IS NULL OR CAST(f.Createdate AS DATE) >= @From)
      AND (@To       IS NULL OR CAST(f.Createdate AS DATE) <= @To)
      AND (@Search   IS NULL OR f.ContactPerson LIKE N'%' + @Search + N'%'
                             OR f.Remark        LIKE N'%' + @Search + N'%'
                             OR u.UnitName      LIKE N'%' + @Search + N'%');
END;
GO

/*==============================================================================
  usp_Request_GetList
  Leave, advance, transfer and uniform requests.

  @OnlyMine exists so a guard can see his own without the approve permission -
  the API passes it whenever the caller lacks M16.Request.Approve.
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Request_GetList
    @CompanyID   INT,
    @UserID      INT,
    @EmpID       INT           = NULL,
    @RequestType NVARCHAR(30)  = NULL,
    @Status      NVARCHAR(20)  = NULL,
    @Search      NVARCHAR(200) = NULL,
    @From        DATE          = NULL,
    @To          DATE          = NULL,
    @PageNo      INT           = 1,
    @PageSize    INT           = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo   IS NULL OR @PageNo   < 1 SET @PageNo   = 1;

    SELECT
        r.RequestID, r.EmpID, e.EmpCode, e.EmpFullName, MobileNo = e.Mobile1,
        d.DesignationName, u.UnitID, u.UnitName,
        r.RequestType, r.FromDate, r.ToDate, r.Amount, r.Reason,
        r.Status, r.IsApproved, r.IsReject,
        r.ApprovedOn, ApprovedByName = ap.UserName, r.Remark,
        r.InsertDate,
        /* How many days the request covers, so a leave queue reads at a glance. */
        DayCount = CASE WHEN r.FromDate IS NULL OR r.ToDate IS NULL
                        THEN NULL ELSE DATEDIFF(DAY, r.FromDate, r.ToDate) + 1 END
    FROM hr.EmployeeRequest AS r
    INNER JOIN hr.Employee AS e ON e.EmpID = r.EmpID
    LEFT  JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    LEFT  JOIN crm.Unit AS u  ON u.UnitID  = e.UnitID
    LEFT  JOIN sec.Users AS ap ON ap.UserID = r.ApprovedBy
    WHERE r.CompanyID = @CompanyID
      AND r.IsCancel  = 0
      /* A fresh joiner with no unit yet must still appear. */
      AND (e.UnitID IS NULL
           OR EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au
                      WHERE au.UnitID = e.UnitID))
      AND (@EmpID       IS NULL OR r.EmpID       = @EmpID)
      AND (@RequestType IS NULL OR r.RequestType = @RequestType)
      AND (@Status      IS NULL OR r.Status      = @Status)
      AND (@From        IS NULL OR r.FromDate   >= @From)
      AND (@To          IS NULL OR r.FromDate   <= @To)
      AND (@Search      IS NULL OR e.EmpFullName LIKE N'%' + @Search + N'%'
                                OR e.EmpCode     LIKE N'%' + @Search + N'%'
                                OR r.Reason      LIKE N'%' + @Search + N'%')
    ORDER BY CASE WHEN r.Status = N'Pending' THEN 0 ELSE 1 END,  -- decisions first
             r.InsertDate DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM hr.EmployeeRequest AS r
    INNER JOIN hr.Employee AS e ON e.EmpID = r.EmpID
    WHERE r.CompanyID = @CompanyID
      AND r.IsCancel  = 0
      AND (e.UnitID IS NULL
           OR EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au
                      WHERE au.UnitID = e.UnitID))
      AND (@EmpID       IS NULL OR r.EmpID       = @EmpID)
      AND (@RequestType IS NULL OR r.RequestType = @RequestType)
      AND (@Status      IS NULL OR r.Status      = @Status)
      AND (@From        IS NULL OR r.FromDate   >= @From)
      AND (@To          IS NULL OR r.FromDate   <= @To)
      AND (@Search      IS NULL OR e.EmpFullName LIKE N'%' + @Search + N'%'
                                OR e.EmpCode     LIKE N'%' + @Search + N'%'
                                OR r.Reason      LIKE N'%' + @Search + N'%');
END;
GO

PRINT '562_procedures_lists2.sql  ->  OK';
GO
