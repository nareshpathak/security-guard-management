/*==============================================================================
  550_procedures_report.sql
  Cross-module reports and the role dashboards.
  Spec: docs/prd/01-database.md §7.5

  Every report takes the same parameter shape so the web report shell can drive
  them all with one component:
      @CompanyID, @UserID, @FromDate, @ToDate, @BranchID, @UnitID, @EmpID,
      @PageNo, @PageSize
  and returns: result set 1 = rows, result set 2 = (TotalRows).
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*==============================================================================
  TEMPORARY EVENT REPORT  (legacy eventRpt)
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Report_Event
    @CompanyID INT, @UserID INT,
    @FromDate DATE = NULL, @ToDate DATE = NULL,
    @BranchID INT = NULL, @UnitID INT = NULL,
    @PageNo INT = 1, @PageSize INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;
    IF @FromDate IS NULL SET @FromDate = DATEADD(DAY, -90, CAST(SYSDATETIME() AS DATE));
    IF @ToDate   IS NULL SET @ToDate   = CAST(SYSDATETIME() AS DATE);

    SELECT e.EventID, e.StartDate, e.EndDate, e.StartTime, e.EndTime, e.NOP,
           e.TypeOfService, e.RatePerGuard, e.Remark, e.IsApproved,
           e.UnitID, UnitName = u.UnitName, ClientName = cl.ClientName
    FROM ops.TemporaryEvent AS e
    LEFT JOIN crm.Unit   AS u  ON u.UnitID = e.UnitID
    LEFT JOIN crm.Client AS cl ON cl.ClientID = ISNULL(e.ClientID, u.ClientID)
    WHERE e.CompanyID = @CompanyID AND e.IsCancel = 0
      AND e.StartDate BETWEEN @FromDate AND @ToDate
      AND (@BranchID IS NULL OR e.BranchID = @BranchID)
      AND (@UnitID   IS NULL OR e.UnitID   = @UnitID)
      AND (e.UnitID IS NULL OR EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au
                                       WHERE au.UnitID = e.UnitID))
    ORDER BY e.StartDate DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*) FROM ops.TemporaryEvent AS e
    WHERE e.CompanyID = @CompanyID AND e.IsCancel = 0
      AND e.StartDate BETWEEN @FromDate AND @ToDate
      AND (@BranchID IS NULL OR e.BranchID = @BranchID)
      AND (@UnitID   IS NULL OR e.UnitID   = @UnitID);
END;
GO

/*==============================================================================
  INCREASE / DECREASE REPORT  (legacy incdecRpt)
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Report_IncDec
    @CompanyID INT, @UserID INT,
    @FromDate DATE = NULL, @ToDate DATE = NULL,
    @BranchID INT = NULL, @UnitID INT = NULL,
    @PageNo INT = 1, @PageSize INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;
    IF @FromDate IS NULL SET @FromDate = DATEADD(DAY, -90, CAST(SYSDATETIME() AS DATE));
    IF @ToDate   IS NULL SET @ToDate   = CAST(SYSDATETIME() AS DATE);

    SELECT dc.ChangeID, dc.Dated, dc.Timing, dc.ChangeType AS Status, dc.Nop,
           dc.Remark, dc.Status AS ApprovalStatus, dc.ApprovedOn,
           dc.UnitID, UnitName = u.UnitName, ClientName = cl.ClientName,
           DesignationName = d.DesignationName, ShiftName = s.ShiftName
    FROM ops.DeploymentChange AS dc
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = dc.UnitID
    INNER JOIN crm.Unit   AS u  ON u.UnitID = dc.UnitID
    LEFT  JOIN crm.Client AS cl ON cl.ClientID = u.ClientID
    LEFT  JOIN mst.Designation AS d ON d.DesignationID = dc.DesignationID
    LEFT  JOIN mst.Shift  AS s  ON s.ShiftID = dc.ShiftID
    WHERE dc.CompanyID = @CompanyID AND dc.IsCancel = 0
      AND dc.Dated BETWEEN @FromDate AND @ToDate
      AND (@BranchID IS NULL OR dc.BranchID = @BranchID)
      AND (@UnitID   IS NULL OR dc.UnitID   = @UnitID)
    ORDER BY dc.Dated DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*) FROM ops.DeploymentChange AS dc
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = dc.UnitID
    WHERE dc.CompanyID = @CompanyID AND dc.IsCancel = 0
      AND dc.Dated BETWEEN @FromDate AND @ToDate
      AND (@BranchID IS NULL OR dc.BranchID = @BranchID)
      AND (@UnitID   IS NULL OR dc.UnitID   = @UnitID);
END;
GO

/*==============================================================================
  MOVEMENT REPORT  (legacy movementRpt)
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Report_Movement
    @CompanyID INT, @UserID INT,
    @FromDate DATE = NULL, @ToDate DATE = NULL,
    @BranchID INT = NULL, @UnitID INT = NULL, @EmpID INT = NULL,
    @PageNo INT = 1, @PageSize INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;
    IF @FromDate IS NULL SET @FromDate = DATEADD(DAY, -30, CAST(SYSDATETIME() AS DATE));
    IF @ToDate   IS NULL SET @ToDate   = CAST(SYSDATETIME() AS DATE);

    SELECT m.MovementID, m.MovementDate, m.MovementTime, m.PostName, m.InstructionBy, m.Remark,
           m.EmpID, GuardName = e.EmpFullName, e.EmpCode, DesignationName = d.DesignationName,
           FromUnit = fu.UnitName, ToUnit = tu.UnitName, UnitName = ISNULL(tu.UnitName, fu.UnitName)
    FROM ops.Movement AS m
    INNER JOIN hr.Employee AS e ON e.EmpID = m.EmpID
    LEFT  JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    LEFT  JOIN crm.Unit AS fu ON fu.UnitID = m.FromUnitID
    LEFT  JOIN crm.Unit AS tu ON tu.UnitID = m.ToUnitID
    WHERE m.CompanyID = @CompanyID AND m.IsCancel = 0
      AND m.MovementDate BETWEEN @FromDate AND @ToDate
      AND (@BranchID IS NULL OR m.BranchID = @BranchID)
      AND (@EmpID    IS NULL OR m.EmpID    = @EmpID)
      AND (@UnitID   IS NULL OR m.FromUnitID = @UnitID OR m.ToUnitID = @UnitID)
    ORDER BY m.MovementDate DESC, m.MovementTime DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*) FROM ops.Movement AS m
    WHERE m.CompanyID = @CompanyID AND m.IsCancel = 0
      AND m.MovementDate BETWEEN @FromDate AND @ToDate
      AND (@BranchID IS NULL OR m.BranchID = @BranchID)
      AND (@EmpID    IS NULL OR m.EmpID    = @EmpID)
      AND (@UnitID   IS NULL OR m.FromUnitID = @UnitID OR m.ToUnitID = @UnitID);
END;
GO

/*==============================================================================
  CONTRACT REPORT  (legacy newcontractRpt and contractterminationRpt)
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Report_Contract
    @CompanyID INT, @UserID INT,
    @ContractType NVARCHAR(20) = NULL,
    @FromDate DATE = NULL, @ToDate DATE = NULL,
    @BranchID INT = NULL, @UnitID INT = NULL, @ClientID INT = NULL,
    @PageNo INT = 1, @PageSize INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;
    IF @FromDate IS NULL SET @FromDate = DATEADD(DAY, -180, CAST(SYSDATETIME() AS DATE));
    IF @ToDate   IS NULL SET @ToDate   = CAST(SYSDATETIME() AS DATE);

    SELECT c.ContractID, c.ContractType, c.Dated, c.Nop, c.Timing, c.Remark,
           c.EffectiveFrom, c.EffectiveTo, c.Status,
           c.UnitID, UnitName = u.UnitName, c.ClientID, ClientName = cl.ClientName
    FROM crm.Contract AS c
    LEFT JOIN crm.Unit   AS u  ON u.UnitID = c.UnitID
    LEFT JOIN crm.Client AS cl ON cl.ClientID = ISNULL(c.ClientID, u.ClientID)
    WHERE c.CompanyID = @CompanyID AND c.IsCancel = 0
      AND c.Dated BETWEEN @FromDate AND @ToDate
      AND (@ContractType IS NULL OR c.ContractType = @ContractType)
      AND (@BranchID IS NULL OR c.BranchID = @BranchID)
      AND (@UnitID   IS NULL OR c.UnitID   = @UnitID)
      AND (@ClientID IS NULL OR c.ClientID = @ClientID)
      AND (c.UnitID IS NULL OR EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au
                                       WHERE au.UnitID = c.UnitID))
    ORDER BY c.Dated DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*) FROM crm.Contract AS c
    WHERE c.CompanyID = @CompanyID AND c.IsCancel = 0
      AND c.Dated BETWEEN @FromDate AND @ToDate
      AND (@ContractType IS NULL OR c.ContractType = @ContractType)
      AND (@BranchID IS NULL OR c.BranchID = @BranchID)
      AND (@UnitID   IS NULL OR c.UnitID   = @UnitID)
      AND (@ClientID IS NULL OR c.ClientID = @ClientID);
END;
GO

/*==============================================================================
  RECRUITMENT REPORT
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Report_Recruitment
    @CompanyID INT, @UserID INT,
    @FromDate DATE = NULL, @ToDate DATE = NULL, @BranchID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FromDate IS NULL SET @FromDate = DATEADD(DAY, -90, CAST(SYSDATETIME() AS DATE));
    IF @ToDate   IS NULL SET @ToDate   = CAST(SYSDATETIME() AS DATE);

    /* funnel */
    SELECT Status, Cnt = COUNT(*)
    FROM hr.Recruit
    WHERE CompanyID = @CompanyID AND IsCancel = 0
      AND Dated BETWEEN @FromDate AND @ToDate
      AND (@BranchID IS NULL OR BranchID = @BranchID)
    GROUP BY Status;

    /* by source */
    SELECT SourceBy = ISNULL(SourceBy, N'Unknown'),
           Total     = COUNT(*),
           Converted = SUM(CASE WHEN Status = N'Converted' THEN 1 ELSE 0 END),
           Rejected  = SUM(CASE WHEN Status = N'Rejected'  THEN 1 ELSE 0 END)
    FROM hr.Recruit
    WHERE CompanyID = @CompanyID AND IsCancel = 0
      AND Dated BETWEEN @FromDate AND @ToDate
      AND (@BranchID IS NULL OR BranchID = @BranchID)
    GROUP BY SourceBy
    ORDER BY Total DESC;

    /* new joins in the period */
    SELECT e.EmpID, e.EmpCode, e.EmpFullName, e.Doj, e.Mobile1,
           DesignationName = d.DesignationName, UnitName = u.UnitName, BranchName = b.BranchName
    FROM hr.Employee AS e
    LEFT JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    LEFT JOIN crm.Unit   AS u ON u.UnitID = e.UnitID
    LEFT JOIN org.Branch AS b ON b.BranchID = e.BranchID
    WHERE e.CompanyID = @CompanyID AND e.IsCancel = 0
      AND e.Doj BETWEEN @FromDate AND @ToDate
      AND (@BranchID IS NULL OR e.BranchID = @BranchID)
    ORDER BY e.Doj DESC;
END;
GO

/*==============================================================================
  ROLE DASHBOARDS  (one call, many widget result sets)
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Dashboard_Get
    @CompanyID INT,
    @UserID    INT,
    @RoleCode  NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
    IF @RoleCode IS NULL
        SELECT @RoleCode = r.RoleCode FROM sec.Users AS u
        INNER JOIN sec.Role AS r ON r.RoleID = u.RoleID WHERE u.UserID = @UserID;

    /* 1 headline counters, scoped to what this user may see */
    SELECT
        RoleCode          = @RoleCode,
        ActiveEmployees   = (SELECT COUNT(*) FROM hr.Employee AS e
                             WHERE e.CompanyID = @CompanyID AND e.EmpStatus = N'Active' AND e.IsCancel = 0
                               AND (e.UnitID IS NULL OR EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au WHERE au.UnitID = e.UnitID))),
        ActiveUnits       = (SELECT COUNT(*) FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID)),
        PresentToday      = (SELECT COUNT(*) FROM ops.Attendance AS a
                             INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = a.UnitID
                             WHERE a.CompanyID = @CompanyID AND a.AttendanceDate = @Today
                               AND a.Status IN ('P ','DS') AND a.IsCancel = 0),
        AbsentToday       = (SELECT COUNT(*) FROM ops.Attendance AS a
                             INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = a.UnitID
                             WHERE a.CompanyID = @CompanyID AND a.AttendanceDate = @Today
                               AND a.Status = 'A ' AND a.IsCancel = 0),
        PendingApprovals  = (SELECT COUNT(*) FROM ops.Attendance AS a
                             INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = a.UnitID
                             WHERE a.CompanyID = @CompanyID AND a.ApprovalStatus = 0 AND a.IsCancel = 0),
        OpenComplaints    = (SELECT COUNT(*) FROM ops.Complaint AS c
                             INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = c.UnitID
                             WHERE c.CompanyID = @CompanyID AND c.IsClosed = 0 AND c.IsCancel = 0),
        SlaBreached       = (SELECT COUNT(*) FROM ops.Complaint AS c
                             INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = c.UnitID
                             WHERE c.CompanyID = @CompanyID AND c.IsClosed = 0 AND c.IsCancel = 0
                               AND c.DueOn IS NOT NULL AND c.DueOn < SYSDATETIME()),
        DocsExpiring30    = (SELECT COUNT(*) FROM doc.Document AS d
                             WHERE d.CompanyID = @CompanyID AND d.IsCancel = 0 AND d.ExpiryDate IS NOT NULL
                               AND d.ExpiryDate >= @Today AND d.ExpiryDate < DATEADD(DAY, 30, @Today)),
        MyOpenTasks       = (SELECT COUNT(*) FROM ops.Task AS t
                             WHERE t.CompanyID = @CompanyID AND t.Assignedto = @UserID
                               AND t.Isclosed = 0 AND t.IsCancel = 0),
        MyOverdueTasks    = (SELECT COUNT(*) FROM ops.Task AS t
                             WHERE t.CompanyID = @CompanyID AND t.Assignedto = @UserID
                               AND t.Isclosed = 0 AND t.IsCancel = 0 AND t.EndDate < @Today),
        RecruitsInPipeline = (SELECT COUNT(*) FROM hr.Recruit
                             WHERE CompanyID = @CompanyID AND IsCancel = 0
                               AND Status NOT IN (N'Converted', N'Rejected')),
        OutstandingAmount = ISNULL((SELECT SUM(i.OutstandingAmount) FROM fin.Invoice AS i
                             WHERE i.CompanyID = @CompanyID AND i.IsCancel = 0 AND i.Status <> N'Cancelled'), 0);

    /* 2 units short of strength today */
    SELECT TOP (20) UnitID, UnitName, ClientName, RequiredNos, PresentNos, VacantNos, FillPercent
    FROM (
        SELECT u.UnitID, u.UnitName, cl.ClientName,
               RequiredNos = ISNULL(rq.RequiredStrength, 0),
               PresentNos  = ISNULL(at.Present, 0),
               VacantNos   = CASE WHEN ISNULL(rq.RequiredStrength, 0) - ISNULL(at.Present, 0) > 0
                                  THEN ISNULL(rq.RequiredStrength, 0) - ISNULL(at.Present, 0) ELSE 0 END,
               FillPercent = CASE WHEN ISNULL(rq.RequiredStrength, 0) = 0 THEN 100
                                  ELSE CAST(ISNULL(at.Present, 0) * 100.0 / rq.RequiredStrength AS DECIMAL(5,1)) END
        FROM crm.Unit AS u
        INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = u.UnitID
        LEFT  JOIN crm.Client AS cl ON cl.ClientID = u.ClientID
        OUTER APPLY dbo.fnUnitRequiredStrength(@CompanyID, u.UnitID, @Today, NULL) AS rq
        OUTER APPLY (SELECT Present = SUM(CASE WHEN a.Status IN ('P ','DS') THEN 1 ELSE 0 END)
                     FROM ops.Attendance AS a
                     WHERE a.UnitID = u.UnitID AND a.AttendanceDate = @Today AND a.IsCancel = 0) AS at
        WHERE u.CompanyID = @CompanyID AND u.IsActive = 1 AND u.IsCancel = 0
    ) AS x
    WHERE x.VacantNos > 0
    ORDER BY x.VacantNos DESC;

    /* 3 attendance trend, last 30 days */
    SELECT d.[Date] AS AttendanceDate,
           Present = ISNULL(SUM(CASE WHEN a.Status IN ('P ','DS') THEN 1 ELSE 0 END), 0),
           Absent  = ISNULL(SUM(CASE WHEN a.Status = 'A ' THEN 1 ELSE 0 END), 0)
    FROM dbo.fnDateRange(DATEADD(DAY, -29, @Today), @Today) AS d
    LEFT JOIN ops.Attendance AS a
           ON a.AttendanceDate = d.[Date] AND a.CompanyID = @CompanyID AND a.IsCancel = 0
          AND EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au WHERE au.UnitID = a.UnitID)
    GROUP BY d.[Date]
    ORDER BY d.[Date];

    /* 4 recent incidents */
    SELECT TOP (10) i.IncidentID, i.IncidentDate, i.IncidentTime, t.IncidentTypeName,
           i.Severity, u.UnitName, i.FullName, i.IsClosed
    FROM ops.Incident AS i
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = i.UnitID
    INNER JOIN crm.Unit AS u ON u.UnitID = i.UnitID
    LEFT  JOIN mst.IncidentType AS t ON t.IncidentTypeID = i.IncidentTypeID
    WHERE i.CompanyID = @CompanyID AND i.IsCancel = 0
    ORDER BY i.IncidentDate DESC, i.IncidentTime DESC;

    /* 5 unified approval queue.
       The view must be aliased: an unqualified UnitID inside the EXISTS would bind
       to the function's own UnitID column, turning the predicate into au.UnitID =
       au.UnitID - always true - and leaking other units' approvals. */
    SELECT TOP (20) pa.Kind, pa.RefID, pa.Title, pa.Subtitle, pa.Amount, pa.RaisedOn
    FROM dbo.vwPendingApprovals AS pa
    WHERE pa.CompanyID = @CompanyID
      AND (pa.UnitID IS NULL
           OR EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au
                      WHERE au.UnitID = pa.UnitID))
    ORDER BY pa.RaisedOn;

    /* 6 patrol compliance today */
    SELECT Expected = ISNULL(SUM(ExpectedCheckpoints), 0),
           Scanned  = ISNULL(SUM(ScannedCheckpoints), 0),
           Missed   = ISNULL(SUM(MissedCheckpoints), 0)
    FROM (
        SELECT ExpectedCheckpoints = ISNULL(e.Cnt, 0),
               ScannedCheckpoints  = ISNULL(s.Scanned, 0),
               MissedCheckpoints   = CASE WHEN ISNULL(e.Cnt, 0) - ISNULL(s.Scanned, 0) > 0
                                          THEN ISNULL(e.Cnt, 0) - ISNULL(s.Scanned, 0) ELSE 0 END
        FROM ops.PatrolRound AS r
        INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = r.UnitID
        OUTER APPLY (SELECT Cnt = COUNT(*) FROM ops.PatrolRoundCheckpoint AS rc WHERE rc.RoundID = r.RoundID) AS e
        OUTER APPLY (SELECT Scanned = COUNT(DISTINCT sl.QrID) FROM ops.QrScanLog AS sl
                     WHERE sl.RoundID = r.RoundID AND CAST(sl.Scantime AS DATE) = @Today) AS s
        WHERE r.CompanyID = @CompanyID AND r.IsActive = 1 AND r.IsCancel = 0
    ) AS p;

    /* 7 payroll status for the current month */
    SELECT r.RunID, r.MonthYear, r.Status, r.EmployeeCount, r.TotalNetPayable, r.GeneratedOn, r.LockedOn
    FROM fin.SalaryRun AS r
    WHERE r.CompanyID = @CompanyID AND r.IsCancel = 0
      AND r.MonthYear = CONVERT(CHAR(7), @Today, 126);
END;
GO

/*==============================================================================
  SUPER ADMIN PLATFORM DASHBOARD
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Dashboard_Platform
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

    SELECT
        TotalTenants    = (SELECT COUNT(*) FROM org.Company WHERE IsCancel = 0),
        ActiveTenants   = (SELECT COUNT(*) FROM org.Company WHERE IsCancel = 0 AND IsActive = 1 AND IsExpired = 0),
        ExpiringIn30    = (SELECT COUNT(*) FROM org.Company WHERE IsCancel = 0 AND IsActive = 1
                           AND ExpiryDate IS NOT NULL AND ExpiryDate BETWEEN @Today AND DATEADD(DAY, 30, @Today)),
        OverUserLimit   = (SELECT COUNT(*) FROM org.Company WHERE IsCancel = 0 AND UserCount > MaxUsers),
        TotalEmployees  = (SELECT COUNT(*) FROM hr.Employee WHERE IsCancel = 0 AND EmpStatus = N'Active'),
        LoginsToday     = (SELECT COUNT(*) FROM sec.LoginLog WHERE IsSuccess = 1 AND CAST(LoginAt AS DATE) = @Today),
        FailedLoginsToday = (SELECT COUNT(*) FROM sec.LoginLog WHERE IsSuccess = 0 AND CAST(LoginAt AS DATE) = @Today),
        PunchesToday    = (SELECT COUNT(*) FROM ops.Attendance WHERE AttendanceDate = @Today AND IsCancel = 0);

    SELECT TOP (25) c.CompanyID, c.CompanyName, c.CompanyCode, c.UserCount, c.MaxUsers,
           c.LoginCount, c.ExpiryDate, c.IsExpired, c.IsActive,
           EmployeeCount = (SELECT COUNT(*) FROM hr.Employee AS e
                            WHERE e.CompanyID = c.CompanyID AND e.IsCancel = 0 AND e.EmpStatus = N'Active'),
           LoginsToday   = (SELECT COUNT(*) FROM sec.LoginLog AS l
                            WHERE l.CompanyID = c.CompanyID AND l.IsSuccess = 1 AND CAST(l.LoginAt AS DATE) = @Today)
    FROM org.Company AS c
    WHERE c.IsCancel = 0
    ORDER BY c.UserCount DESC;

    SELECT LogDate = CAST(l.LoginAt AS DATE), Logins = COUNT(*)
    FROM sec.LoginLog AS l
    WHERE l.IsSuccess = 1 AND l.LoginAt >= DATEADD(DAY, -30, SYSDATETIME())
    GROUP BY CAST(l.LoginAt AS DATE)
    ORDER BY LogDate;
END;
GO

/*==============================================================================
  CLIENT PORTAL DASHBOARD - deliberately narrow. A client sees proof of service,
  never employee personal data, salaries or other clients.
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Dashboard_Client
    @CompanyID INT,
    @UserID    INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE), @ClientID INT;
    SELECT @ClientID = ClientID FROM sec.Users WHERE UserID = @UserID;

    IF @ClientID IS NULL THROW 51950, 'This login is not linked to a client.', 1;

    SELECT
        MyUnits        = (SELECT COUNT(*) FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID)),
        GuardsOnDuty   = (SELECT COUNT(*) FROM ops.Attendance AS a
                          INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = a.UnitID
                          WHERE a.CompanyID = @CompanyID AND a.AttendanceDate = @Today
                            AND a.Status IN ('P ','DS') AND a.IsCancel = 0),
        OpenComplaints = (SELECT COUNT(*) FROM ops.Complaint AS c
                          WHERE c.CompanyID = @CompanyID AND c.ClientID = @ClientID
                            AND c.IsClosed = 0 AND c.IsCancel = 0),
        OutstandingAmount = ISNULL((SELECT SUM(OutstandingAmount) FROM fin.Invoice
                          WHERE CompanyID = @CompanyID AND ClientID = @ClientID
                            AND IsCancel = 0 AND Status <> N'Cancelled'), 0);

    /* guards on duty - name, photo, designation and status only */
    SELECT e.EmpFullName, e.Photo, d.DesignationName, u.UnitName,
           s.ShiftName, a.InTime, a.OutTime, a.Status
    FROM ops.Attendance AS a
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = a.UnitID
    INNER JOIN hr.Employee AS e ON e.EmpID = a.EmpID
    INNER JOIN crm.Unit    AS u ON u.UnitID = a.UnitID
    LEFT  JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    LEFT  JOIN mst.Shift   AS s ON s.ShiftID = a.ShiftID
    WHERE a.CompanyID = @CompanyID AND a.AttendanceDate = @Today AND a.IsCancel = 0
    ORDER BY u.UnitName, e.EmpFullName;

    /* patrol proof for the last 7 days */
    SELECT ScanDate = CAST(sl.Scantime AS DATE), u.UnitName,
           Scans = COUNT(*), WithPhoto = SUM(CASE WHEN sl.ImageUrl IS NOT NULL THEN 1 ELSE 0 END),
           InRange = SUM(CASE WHEN sl.IsWithinRange = 1 THEN 1 ELSE 0 END)
    FROM ops.QrScanLog AS sl
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = sl.UnitID
    INNER JOIN crm.Unit AS u ON u.UnitID = sl.UnitID
    WHERE sl.CompanyID = @CompanyID AND sl.Scantime >= DATEADD(DAY, -7, SYSDATETIME())
    GROUP BY CAST(sl.Scantime AS DATE), u.UnitName
    ORDER BY ScanDate DESC;

    SELECT TOP (10) Bid, InvoiceNo, InvoiceDate, DueDate, GrandTotal,
           ReceivedAmount, OutstandingAmount, Status, PdfUrl
    FROM fin.Invoice
    WHERE CompanyID = @CompanyID AND ClientID = @ClientID AND IsCancel = 0
    ORDER BY InvoiceDate DESC;
END;
GO

PRINT '550_procedures_report.sql  ->  OK  (8 procedures)';
GO
