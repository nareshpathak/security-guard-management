/*==============================================================================
  400_views.sql
  Read models. Spec: docs/prd/01-database.md §5

  IMPORTANT - views are NOT security boundaries
  ---------------------------------------------
  A view cannot take @UserID, so none of these apply per-user data scoping.
  Every view exposes CompanyID and the caller (a stored procedure) MUST both
  filter on @CompanyID and join to dbo.fnUserAccessibleUnits / fnUserAccessibleBranches.
  Never expose a view directly to the API.

  No SELECT * anywhere, per docs/prd/01-database.md §1.
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*==============================================================================
  1. vwEmployeeFull - the employee list/search backbone
==============================================================================*/
CREATE OR ALTER VIEW dbo.vwEmployeeFull
AS
SELECT
    e.EmpID,
    e.CompanyID,
    e.BranchID,
    b.BranchName,
    e.EmpCode,
    e.OldEmpCode,
    e.EmpFullName,
    e.FirstName,
    e.LastName,
    e.Gender,
    e.Dob,
    Age                 = dbo.fnAgeInYears(e.Dob, CAST(SYSDATETIME() AS DATE)),
    e.Bloodgroup,
    e.Mobile1,
    e.EmailId1,
    e.DesignationID,
    d.DesignationName,
    e.CategoryID,
    c.CategoryName,
    e.GradeID,
    e.ShiftID,
    s.ShiftName,
    e.UnitID,
    u.UnitName,
    e.Clientid,
    cl.ClientName,
    e.Doj,
    e.Dol,
    e.EmpStatus,
    e.Employeetype,
    e.BeltNo,
    e.IdCardNo,
    e.IdCardExpireDate,
    e.Photo,
    e.IsGunman,
    e.IsReliever,
    e.IsExService,
    e.IsPermanent,
    e.IsBlackListed,
    e.IsApproved,
    e.IsCancel,
    PoliceVerified      = ISNULL(v.IsPoliceVerification, CAST(0 AS BIT)),
    v.PVValidUpTo,
    m.MedicalCertificateValidUpto,
    g.Licenseexpire     AS GunLicenceExpiry,
    AdharCardNo         = st.AdharCardNo,
    PanCardNo           = st.PanCardNo,
    UANNo               = st.UANNo,
    ESICNo              = st.ESICNo,
    BankAcNo            = bk.BankAcNo,
    IFSCcode            = bk.IFSCcode,
    e.InsertDate
FROM hr.Employee AS e
LEFT JOIN org.Branch            AS b  ON b.BranchID      = e.BranchID
LEFT JOIN mst.Designation       AS d  ON d.DesignationID = e.DesignationID
LEFT JOIN mst.Category          AS c  ON c.CategoryID    = e.CategoryID
LEFT JOIN mst.Shift             AS s  ON s.ShiftID       = e.ShiftID
LEFT JOIN crm.Unit              AS u  ON u.UnitID        = e.UnitID
LEFT JOIN crm.Client            AS cl ON cl.ClientID     = e.Clientid
LEFT JOIN hr.EmployeeVerification AS v  ON v.EmpID  = e.EmpID
LEFT JOIN hr.EmployeeMedical      AS m  ON m.EmpID  = e.EmpID
LEFT JOIN hr.EmployeeGunLicence   AS g  ON g.EmpID  = e.EmpID
LEFT JOIN hr.EmployeeStatutory    AS st ON st.EmpID = e.EmpID
LEFT JOIN hr.EmployeeBank         AS bk ON bk.EmpID = e.EmpID AND bk.IsJoint = 0 AND bk.IsCancel = 0;
GO

/*==============================================================================
  2. vwActiveDeployment - who is posted where, right now
==============================================================================*/
CREATE OR ALTER VIEW dbo.vwActiveDeployment
AS
SELECT
    dp.DeploymentID,
    dp.CompanyID,
    dp.BranchID,
    dp.UnitID,
    u.UnitName,
    u.ClientID,
    cl.ClientName,
    dp.PostID,
    p.PostName,
    dp.EmpID,
    e.EmpCode,
    e.EmpFullName,
    e.Photo,
    e.Mobile1,
    dp.DesignationID,
    d.DesignationName,
    dp.ShiftID,
    s.ShiftName,
    s.StartTime,
    s.EndTime,
    dp.FromDate,
    dp.ToDate,
    dp.IsReliever,
    dp.RelieverForEmpID,
    dp.Status
FROM ops.Deployment AS dp
INNER JOIN hr.Employee   AS e  ON e.EmpID  = dp.EmpID
INNER JOIN crm.Unit      AS u  ON u.UnitID = dp.UnitID
LEFT  JOIN crm.Client    AS cl ON cl.ClientID = u.ClientID
LEFT  JOIN crm.UnitPost  AS p  ON p.PostID = dp.PostID
LEFT  JOIN mst.Designation AS d ON d.DesignationID = dp.DesignationID
LEFT  JOIN mst.Shift     AS s  ON s.ShiftID = dp.ShiftID
WHERE dp.Status = N'Active'
  AND dp.IsCancel = 0
  AND (dp.ToDate IS NULL OR dp.ToDate >= CAST(SYSDATETIME() AS DATE));
GO

/*==============================================================================
  3. vwDailyTurnout - required vs present per unit / date / shift
     Computed live from attendance, not from the ops.Turnout snapshot, so the
     turnout board is correct even before a supervisor files the register.
==============================================================================*/
CREATE OR ALTER VIEW dbo.vwDailyTurnout
AS
SELECT
    a.CompanyID,
    a.UnitID,
    u.UnitName,
    u.ClientID,
    u.BranchID,
    a.AttendanceDate,
    a.ShiftID,
    RequiredNos = ISNULL((SELECT SUM(p.RequiredStrength)
                          FROM crm.UnitPost AS p
                          WHERE p.UnitID = a.UnitID AND p.IsActive = 1 AND p.IsCancel = 0
                            AND (p.ShiftID = a.ShiftID OR a.ShiftID IS NULL)), 0),
    PresentNos  = SUM(CASE WHEN a.Status IN ('P ','DS') THEN 1 ELSE 0 END),
    HalfDayNos  = SUM(CASE WHEN a.Status = 'HD' THEN 1 ELSE 0 END),
    AbsentNos   = SUM(CASE WHEN a.Status = 'A ' THEN 1 ELSE 0 END),
    RelieverNos = SUM(CASE WHEN a.Status IN ('P ','DS') AND dp.IsReliever = 1 THEN 1 ELSE 0 END),
    PendingApprovalNos = SUM(CASE WHEN a.ApprovalStatus = 0 THEN 1 ELSE 0 END),
    LastPunchAt = MAX(a.InTime)
FROM ops.Attendance AS a
INNER JOIN crm.Unit AS u ON u.UnitID = a.UnitID
LEFT  JOIN ops.Deployment AS dp
       ON dp.EmpID = a.EmpID AND dp.UnitID = a.UnitID AND dp.Status = N'Active' AND dp.IsCancel = 0
WHERE a.IsCancel = 0
GROUP BY a.CompanyID, a.UnitID, u.UnitName, u.ClientID, u.BranchID, a.AttendanceDate, a.ShiftID;
GO

/*==============================================================================
  4. vwAttendanceRegister - one row per employee per date.
     NOT pivoted into a day-1..day-31 matrix: a view cannot have dynamic
     columns. The register SP / the web grid pivots this. See DECISIONS.md #16.
==============================================================================*/
CREATE OR ALTER VIEW dbo.vwAttendanceRegister
AS
SELECT
    a.AttendanceID,
    a.CompanyID,
    a.BranchID,
    a.UnitID,
    u.UnitName,
    u.ClientID,
    a.EmpID,
    e.EmpCode,
    e.EmpFullName,
    d.DesignationName,
    a.AttendanceDate,
    MonthYear   = CONVERT(CHAR(7), a.AttendanceDate, 126),
    DayNo       = DATEPART(DAY, a.AttendanceDate),
    a.ShiftID,
    s.ShiftName,
    a.InTime,
    a.OutTime,
    a.WorkedHours,
    a.OtHours,
    a.Status,
    a.ApprovalStatus,
    a.InDistanceMeters,
    a.OutDistanceMeters,
    a.InSelfieUrl,
    a.OutSelfieUrl,
    a.IsMockLocation,
    a.IsOffline,
    a.Source,
    OutsideGeofence = CASE WHEN a.InDistanceMeters > u.GeofenceRadiusMeters THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END
FROM ops.Attendance AS a
INNER JOIN hr.Employee AS e ON e.EmpID  = a.EmpID
INNER JOIN crm.Unit    AS u ON u.UnitID = a.UnitID
LEFT  JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
LEFT  JOIN mst.Shift   AS s ON s.ShiftID = a.ShiftID
WHERE a.IsCancel = 0;
GO

/*==============================================================================
  5. vwPendingApprovals - one queue for everything awaiting a decision
==============================================================================*/
CREATE OR ALTER VIEW dbo.vwPendingApprovals
AS
SELECT Kind = N'Attendance', RefID = CAST(a.AttendanceID AS BIGINT), a.CompanyID, a.BranchID, a.UnitID,
       Title = e.EmpFullName, Subtitle = CONVERT(CHAR(10), a.AttendanceDate, 120),
       Amount = CAST(NULL AS DECIMAL(18,2)), RaisedOn = a.InsertDate, RaisedByUserID = a.InsertUserID
FROM ops.Attendance AS a
INNER JOIN hr.Employee AS e ON e.EmpID = a.EmpID
WHERE a.ApprovalStatus = 0 AND a.IsCancel = 0

UNION ALL
SELECT N'Recruit', CAST(r.RecruitID AS BIGINT), r.CompanyID, r.BranchID, NULL,
       r.Name, r.Mobile, NULL, r.InsertDate, r.InsertUserID
FROM hr.Recruit AS r
WHERE r.Status IN (N'Screened', N'Verified') AND r.IsCancel = 0

UNION ALL
SELECT N'Advance', CAST(ad.AdvanceID AS BIGINT), ad.CompanyID, ad.BranchID, NULL,
       e.EmpFullName, ad.Reason, ad.Amount, ad.InsertDate, ad.InsertUserID
FROM fin.Advance AS ad
INNER JOIN hr.Employee AS e ON e.EmpID = ad.EmpID
WHERE ad.Status = N'Pending' AND ad.IsCancel = 0

UNION ALL
SELECT N'Request', CAST(rq.RequestID AS BIGINT), rq.CompanyID, NULL, NULL,
       e.EmpFullName, rq.RequestType, rq.Amount, rq.InsertDate, rq.InsertUserID
FROM hr.EmployeeRequest AS rq
INNER JOIN hr.Employee AS e ON e.EmpID = rq.EmpID
WHERE rq.Status = N'Pending' AND rq.IsCancel = 0

UNION ALL
SELECT N'IncDec', CAST(dc.ChangeID AS BIGINT), dc.CompanyID, dc.BranchID, dc.UnitID,
       u.UnitName, dc.ChangeType, CAST(dc.Nop AS DECIMAL(18,2)), dc.InsertDate, dc.InsertUserID
FROM ops.DeploymentChange AS dc
INNER JOIN crm.Unit AS u ON u.UnitID = dc.UnitID
WHERE dc.Status = N'Pending' AND dc.IsCancel = 0;
GO

/*==============================================================================
  6. vwQrPatrolSummary - expected vs scanned vs missed, per unit / round / day
==============================================================================*/
CREATE OR ALTER VIEW dbo.vwQrPatrolSummary
AS
SELECT
    r.CompanyID,
    r.UnitID,
    u.UnitName,
    u.ClientID,
    r.RoundID,
    r.RoundName,
    r.StartTime,
    r.EndTime,
    ScanDate      = CAST(sl.Scantime AS DATE),
    ExpectedCheckpoints = ISNULL((SELECT COUNT(*) FROM ops.PatrolRoundCheckpoint AS rc WHERE rc.RoundID = r.RoundID), 0),
    ScannedCheckpoints  = COUNT(DISTINCT sl.QrID),
    InRangeScans        = SUM(CASE WHEN sl.IsWithinRange = 1 THEN 1 ELSE 0 END),
    OutOfRangeScans     = SUM(CASE WHEN sl.IsWithinRange = 0 THEN 1 ELSE 0 END),
    ScansWithPhoto      = SUM(CASE WHEN sl.ImageUrl IS NOT NULL THEN 1 ELSE 0 END),
    FirstScanAt         = MIN(sl.Scantime),
    LastScanAt          = MAX(sl.Scantime)
FROM ops.PatrolRound AS r
INNER JOIN crm.Unit AS u ON u.UnitID = r.UnitID
LEFT  JOIN ops.QrScanLog AS sl ON sl.RoundID = r.RoundID
WHERE r.IsCancel = 0
GROUP BY r.CompanyID, r.UnitID, u.UnitName, u.ClientID, r.RoundID, r.RoundName,
         r.StartTime, r.EndTime, CAST(sl.Scantime AS DATE);
GO

/*==============================================================================
  7. vwOpenComplaints - with ageing buckets and an SLA breach flag
==============================================================================*/
CREATE OR ALTER VIEW dbo.vwOpenComplaints
AS
SELECT
    c.ComplaintID,
    c.CompanyID,
    c.BranchID,
    c.UnitID,
    u.UnitName,
    c.ClientID,
    cl.ClientName,
    c.ComplaintTypeID,
    ct.ComplaintTypeName,
    c.Description,
    c.Status,
    c.InsertDate,
    c.DueOn,
    c.AssignedToEmpID,
    AssignedToName = e.EmpFullName,
    AgeHours    = DATEDIFF(HOUR, c.InsertDate, SYSDATETIME()),
    AgeBucket   = CASE
                    WHEN DATEDIFF(HOUR, c.InsertDate, SYSDATETIME()) <= 24  THEN N'0-24h'
                    WHEN DATEDIFF(HOUR, c.InsertDate, SYSDATETIME()) <= 72  THEN N'1-3d'
                    WHEN DATEDIFF(HOUR, c.InsertDate, SYSDATETIME()) <= 168 THEN N'3-7d'
                    ELSE N'7d+'
                  END,
    IsSlaBreached = CASE WHEN c.DueOn IS NOT NULL AND c.DueOn < SYSDATETIME()
                         THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END
FROM ops.Complaint AS c
INNER JOIN crm.Unit          AS u  ON u.UnitID = c.UnitID
LEFT  JOIN crm.Client        AS cl ON cl.ClientID = c.ClientID
LEFT  JOIN mst.ComplaintType AS ct ON ct.ComplaintTypeID = c.ComplaintTypeID
LEFT  JOIN hr.Employee       AS e  ON e.EmpID = c.AssignedToEmpID
WHERE c.IsClosed = 0 AND c.IsCancel = 0;
GO

/*==============================================================================
  8. vwDocumentExpiry - what expires when, and whose it is
==============================================================================*/
CREATE OR ALTER VIEW dbo.vwDocumentExpiry
AS
SELECT
    d.DocumentID,
    d.CompanyID,
    d.OwnerType,
    d.OwnerID,
    OwnerName = CASE d.OwnerType
                  WHEN N'Employee' THEN (SELECT TOP (1) e.EmpFullName FROM hr.Employee AS e WHERE e.EmpID = d.OwnerID)
                  WHEN N'Unit'     THEN (SELECT TOP (1) u.UnitName    FROM crm.Unit     AS u WHERE u.UnitID = d.OwnerID)
                  WHEN N'Client'   THEN (SELECT TOP (1) c.ClientName  FROM crm.Client   AS c WHERE c.ClientID = d.OwnerID)
                  WHEN N'Company'  THEN (SELECT TOP (1) o.CompanyName FROM org.Company  AS o WHERE o.CompanyID = d.OwnerID)
                  ELSE NULL
                END,
    d.DocTypeID,
    dt.DocTypeName,
    d.DocumentFilename,
    d.IssueDate,
    d.ExpiryDate,
    DaysToExpiry = DATEDIFF(DAY, CAST(SYSDATETIME() AS DATE), d.ExpiryDate),
    ExpiryBucket = CASE
                     WHEN d.ExpiryDate <  CAST(SYSDATETIME() AS DATE) THEN N'Expired'
                     WHEN DATEDIFF(DAY, CAST(SYSDATETIME() AS DATE), d.ExpiryDate) <= 7  THEN N'<=7d'
                     WHEN DATEDIFF(DAY, CAST(SYSDATETIME() AS DATE), d.ExpiryDate) <= 30 THEN N'<=30d'
                     WHEN DATEDIFF(DAY, CAST(SYSDATETIME() AS DATE), d.ExpiryDate) <= 90 THEN N'<=90d'
                     ELSE N'>90d'
                   END,
    d.IsVerified
FROM doc.Document AS d
LEFT JOIN mst.DocumentType AS dt ON dt.DocTypeID = d.DocTypeID
WHERE d.ExpiryDate IS NOT NULL AND d.IsCancel = 0;
GO

/*==============================================================================
  9. vwSalesPipeline - visits to follow-ups to contracts, per executive
==============================================================================*/
CREATE OR ALTER VIEW dbo.vwSalesPipeline
AS
SELECT
    v.CompanyID,
    v.BranchID,
    v.EmpID,
    ExecutiveName = e.EmpFullName,
    v.VisitID,
    v.CompanyName,
    v.ContactPerson,
    v.ContactNo,
    v.Purpose,
    v.VisitDate,
    FollowUpCount     = ISNULL(f.FollowUpCount, 0),
    LastFollowupDate  = f.LastFollowupDate,
    NextFollowupDate  = f.NextFollowupDate,
    IsStopped         = ISNULL(f.IsStopped, CAST(0 AS BIT)),
    Stage = CASE
              WHEN ISNULL(f.IsStopped, 0) = 1                              THEN N'Dropped'
              WHEN f.NextFollowupDate IS NOT NULL                          THEN N'Following'
              WHEN ISNULL(f.FollowUpCount, 0) > 0                          THEN N'Contacted'
              ELSE N'Visited'
            END
FROM crm.SalesVisit AS v
LEFT JOIN hr.Employee AS e ON e.EmpID = v.EmpID
OUTER APPLY (
    SELECT FollowUpCount    = COUNT(*),
           LastFollowupDate = MAX(fu.FollowupDate),
           NextFollowupDate = MAX(CASE WHEN fu.StopFollow = 0 THEN fu.NextFollowupDate END),
           IsStopped        = CAST(MAX(CASE WHEN fu.StopFollow = 1 THEN 1 ELSE 0 END) AS BIT)
    FROM crm.FollowUp AS fu
    WHERE fu.SalesVisitID = v.VisitID AND fu.IsCancel = 0
) AS f
WHERE v.IsCancel = 0;
GO

/*==============================================================================
  10. vwUniformLedger - issued vs returned vs outstanding, per employee
==============================================================================*/
CREATE OR ALTER VIEW dbo.vwUniformLedger
AS
SELECT
    i.CompanyID,
    i.BranchID,
    i.EmpID,
    e.EmpCode,
    e.EmpFullName,
    i.ItemID,
    it.ItemName,
    IssuedQty       = SUM(i.IssuedQty),
    RecievedQty     = SUM(i.RecievedQty),
    OutstandingQty  = SUM(i.OutstandingQty),
    OutstandingValue = SUM(i.OutstandingQty * i.Rate),
    RecoveredAmount = SUM(i.RecoveredAmount),
    LastIssueDate   = MAX(i.IssueDate)
FROM inv.EmployeeIssue AS i
INNER JOIN hr.Employee     AS e  ON e.EmpID  = i.EmpID
INNER JOIN mst.UniformItem AS it ON it.ItemID = i.ItemID
WHERE i.IsCancel = 0
GROUP BY i.CompanyID, i.BranchID, i.EmpID, e.EmpCode, e.EmpFullName, i.ItemID, it.ItemName;
GO

/*==============================================================================
  11. vwInvoiceAgeing - client outstanding in 0-30 / 31-60 / 61-90 / 90+ buckets
==============================================================================*/
CREATE OR ALTER VIEW dbo.vwInvoiceAgeing
AS
SELECT
    inv.Bid,
    inv.CompanyID,
    inv.BranchID,
    inv.ClientID,
    cl.ClientName,
    inv.UnitID,
    inv.InvoiceNo,
    inv.InvoiceDate,
    inv.DueDate,
    inv.GrandTotal,
    inv.ReceivedAmount,
    inv.OutstandingAmount,
    inv.Status,
    DaysOverdue = CASE WHEN inv.DueDate IS NULL THEN 0
                       ELSE CASE WHEN DATEDIFF(DAY, inv.DueDate, CAST(SYSDATETIME() AS DATE)) > 0
                                 THEN DATEDIFF(DAY, inv.DueDate, CAST(SYSDATETIME() AS DATE)) ELSE 0 END
                  END,
    AgeBucket = CASE
                  WHEN inv.DueDate IS NULL THEN N'Not due'
                  WHEN DATEDIFF(DAY, inv.DueDate, CAST(SYSDATETIME() AS DATE)) <= 0  THEN N'Current'
                  WHEN DATEDIFF(DAY, inv.DueDate, CAST(SYSDATETIME() AS DATE)) <= 30 THEN N'0-30'
                  WHEN DATEDIFF(DAY, inv.DueDate, CAST(SYSDATETIME() AS DATE)) <= 60 THEN N'31-60'
                  WHEN DATEDIFF(DAY, inv.DueDate, CAST(SYSDATETIME() AS DATE)) <= 90 THEN N'61-90'
                  ELSE N'90+'
                END
FROM fin.Invoice AS inv
INNER JOIN crm.Client AS cl ON cl.ClientID = inv.ClientID
WHERE inv.IsCancel = 0 AND inv.Status <> N'Cancelled';
GO

/*==============================================================================
  12. vwDashboardCounts - one row per company; powers getcount / Reportcountmodel
==============================================================================*/
CREATE OR ALTER VIEW dbo.vwDashboardCounts
AS
SELECT
    co.CompanyID,
    ActiveEmployees   = (SELECT COUNT(*) FROM hr.Employee e
                         WHERE e.CompanyID = co.CompanyID AND e.EmpStatus = N'Active' AND e.IsCancel = 0),
    ActiveUnits       = (SELECT COUNT(*) FROM crm.Unit u
                         WHERE u.CompanyID = co.CompanyID AND u.IsActive = 1 AND u.IsCancel = 0),
    ActiveClients     = (SELECT COUNT(*) FROM crm.Client c
                         WHERE c.CompanyID = co.CompanyID AND c.IsActive = 1 AND c.IsCancel = 0),
    PresentToday      = (SELECT COUNT(*) FROM ops.Attendance a
                         WHERE a.CompanyID = co.CompanyID AND a.AttendanceDate = CAST(SYSDATETIME() AS DATE)
                           AND a.Status IN ('P ','DS') AND a.IsCancel = 0),
    AbsentToday       = (SELECT COUNT(*) FROM ops.Attendance a
                         WHERE a.CompanyID = co.CompanyID AND a.AttendanceDate = CAST(SYSDATETIME() AS DATE)
                           AND a.Status = 'A ' AND a.IsCancel = 0),
    PendingAttendance = (SELECT COUNT(*) FROM ops.Attendance a
                         WHERE a.CompanyID = co.CompanyID AND a.ApprovalStatus = 0 AND a.IsCancel = 0),
    Recruitcount      = (SELECT COUNT(*) FROM hr.Recruit r
                         WHERE r.CompanyID = co.CompanyID AND r.Status NOT IN (N'Converted', N'Rejected') AND r.IsCancel = 0),
    Fieldcount        = (SELECT COUNT(*) FROM ops.FieldReport fr
                         WHERE fr.CompanyID = co.CompanyID AND CAST(fr.Createdate AS DATE) = CAST(SYSDATETIME() AS DATE)
                           AND fr.IsCancel = 0),
    Turnoutcount      = (SELECT COUNT(*) FROM ops.Turnout t
                         WHERE t.CompanyID = co.CompanyID AND t.TurnoutDate = CAST(SYSDATETIME() AS DATE) AND t.IsCancel = 0),
    OpenComplaints    = (SELECT COUNT(*) FROM ops.Complaint c
                         WHERE c.CompanyID = co.CompanyID AND c.IsClosed = 0 AND c.IsCancel = 0),
    SlaBreached       = (SELECT COUNT(*) FROM ops.Complaint c
                         WHERE c.CompanyID = co.CompanyID AND c.IsClosed = 0 AND c.IsCancel = 0
                           AND c.DueOn IS NOT NULL AND c.DueOn < SYSDATETIME()),
    OpenIncidents     = (SELECT COUNT(*) FROM ops.Incident i
                         WHERE i.CompanyID = co.CompanyID AND i.IsClosed = 0 AND i.IsCancel = 0),
    OverdueTasks      = (SELECT COUNT(*) FROM ops.Task t
                         WHERE t.CompanyID = co.CompanyID AND t.Isclosed = 0 AND t.IsCancel = 0
                           AND t.EndDate IS NOT NULL AND t.EndDate < CAST(SYSDATETIME() AS DATE)),
    DocsExpiring30    = (SELECT COUNT(*) FROM doc.Document d
                         WHERE d.CompanyID = co.CompanyID AND d.IsCancel = 0 AND d.ExpiryDate IS NOT NULL
                           AND d.ExpiryDate >= CAST(SYSDATETIME() AS DATE)
                           AND d.ExpiryDate <  DATEADD(DAY, 30, CAST(SYSDATETIME() AS DATE))),
    FollowUpsDue      = (SELECT COUNT(*) FROM crm.FollowUp f
                         WHERE f.CompanyID = co.CompanyID AND f.StopFollow = 0 AND f.IsCancel = 0
                           AND f.NextFollowupDate IS NOT NULL
                           AND f.NextFollowupDate <= CAST(SYSDATETIME() AS DATE)),
    OutstandingAmount = ISNULL((SELECT SUM(i.OutstandingAmount) FROM fin.Invoice i
                         WHERE i.CompanyID = co.CompanyID AND i.IsCancel = 0
                           AND i.Status <> N'Cancelled'), 0)
FROM org.Company AS co
WHERE co.IsCancel = 0;
GO

PRINT '400_views.sql  ->  OK  (12 views)';
GO
