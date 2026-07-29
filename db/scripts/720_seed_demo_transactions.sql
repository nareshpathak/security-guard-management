/*==============================================================================
  720_seed_demo_transactions.sql
  Ninety days of operational history for the demo tenant.
  Spec: docs/prd/01-database.md §8.3

  Deterministic: every value derives from EmpID / date arithmetic, never from
  RAND() or NEWID(), so screenshots and tests are reproducible.

  Idempotent and RESUMABLE. Every section guards on its own table, not on a
  single script-wide flag. This matters: RETURN exits only the current batch,
  so the old top-level guard let later batches run anyway - and when one of
  them failed, every re-run skipped straight past the hole it left behind.
  Run this script again and it fills in whatever is still empty.
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
IF @Diti IS NULL
BEGIN
    PRINT '720: demo tenant not present, nothing to do.';
    RETURN;
END
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @From  DATE = DATEADD(DAY, -89, @Today);

/*==============================================================================
  ATTENDANCE - 90 days for every active deployment
  95% present, 3% absent, 2% half day; weekly off on Sunday for a rotating third
==============================================================================*/
IF EXISTS (SELECT 1 FROM ops.Attendance WHERE CompanyID = @Diti)
    PRINT '  attendance already seeded, skipping.';
ELSE
BEGIN
;WITH d AS (SELECT [Date] FROM dbo.fnDateRange(@From, @Today)),
dep AS (
    SELECT dp.EmpID, dp.UnitID, dp.PostID, dp.ShiftID, dp.BranchID,
           u.Latitude, u.Longitude, u.GeofenceRadiusMeters,
           s.StartTime, s.EndTime, s.IsNight, s.FullDayHours
    FROM ops.Deployment AS dp
    INNER JOIN crm.Unit  AS u ON u.UnitID = dp.UnitID
    INNER JOIN mst.Shift AS s ON s.ShiftID = dp.ShiftID
    WHERE dp.CompanyID = @Diti AND dp.Status = N'Active' AND dp.IsCancel = 0
),
grid AS (
    SELECT dep.*, d.[Date] AS AttendanceDate,
           Seed = (dep.EmpID * 31 + DATEPART(DAYOFYEAR, d.[Date]) * 17) % 100
    FROM dep CROSS JOIN d
),
marked AS (
    SELECT g.*,
        Status = CASE
                    WHEN DATEPART(WEEKDAY, g.AttendanceDate) = 1 AND (g.EmpID % 3) = (DATEPART(WEEK, g.AttendanceDate) % 3)
                         THEN 'WO'
                    WHEN g.Seed < 3  THEN 'A '
                    WHEN g.Seed < 5  THEN 'HD'
                    ELSE 'P '
                 END
    FROM grid AS g
)
INSERT INTO ops.Attendance
    (CompanyID, BranchID, UnitID, PostID, EmpID, ShiftID, AttendanceDate,
     InTime, OutTime, InLatitude, InLongitude, OutLatitude, OutLongitude,
     InDistanceMeters, OutDistanceMeters, InSelfieUrl, OutSelfieUrl,
     Status, WorkedHours, OtHours, Source, ApprovalStatus, ApprovedOn,
     ClientPunchAt, IsOffline, DeviceID, AppVersion, InsertDate)
SELECT
    @Diti, m.BranchID, m.UnitID, m.PostID, m.EmpID, m.ShiftID, m.AttendanceDate,
    /* in / out times, night shift ends the next day */
    CASE WHEN m.Status IN ('A ','WO') THEN NULL ELSE
        DATEADD(MINUTE, (m.Seed % 11) - 5,
            DATEADD(MINUTE, DATEDIFF(MINUTE, CAST('00:00' AS TIME), m.StartTime),
                    CAST(m.AttendanceDate AS DATETIME2(0)))) END,
    CASE WHEN m.Status IN ('A ','WO') THEN NULL ELSE
        DATEADD(MINUTE, (m.Seed % 13) - 6,
            DATEADD(MINUTE, DATEDIFF(MINUTE, CAST('00:00' AS TIME), m.EndTime),
                    CAST(DATEADD(DAY, CASE WHEN m.IsNight = 1 THEN 1 ELSE 0 END, m.AttendanceDate) AS DATETIME2(0)))) END,
    /* coordinates jittered inside the geofence, except a deliberate 4% outside */
    CASE WHEN m.Status IN ('A ','WO') THEN NULL
         ELSE m.Latitude  + CASE WHEN m.Seed % 25 = 0 THEN 0.0060 ELSE (m.Seed % 9 - 4) * 0.00008 END END,
    CASE WHEN m.Status IN ('A ','WO') THEN NULL
         ELSE m.Longitude + CASE WHEN m.Seed % 25 = 0 THEN 0.0060 ELSE (m.Seed % 7 - 3) * 0.00008 END END,
    CASE WHEN m.Status IN ('A ','WO') THEN NULL ELSE m.Latitude  + (m.Seed % 5 - 2) * 0.00008 END,
    CASE WHEN m.Status IN ('A ','WO') THEN NULL ELSE m.Longitude + (m.Seed % 5 - 2) * 0.00008 END,
    CASE WHEN m.Status IN ('A ','WO') THEN NULL
         WHEN m.Seed % 25 = 0 THEN 720 ELSE (m.Seed % 9) * 6 END,
    CASE WHEN m.Status IN ('A ','WO') THEN NULL ELSE (m.Seed % 7) * 6 END,
    CASE WHEN m.Status IN ('A ','WO') THEN NULL
         ELSE CONCAT(N'https://cdn.diti365.example/selfies/', m.EmpID, N'-',
                     FORMAT(m.AttendanceDate, 'yyyyMMdd'), N'-in.jpg') END,
    CASE WHEN m.Status IN ('A ','WO') THEN NULL
         ELSE CONCAT(N'https://cdn.diti365.example/selfies/', m.EmpID, N'-',
                     FORMAT(m.AttendanceDate, 'yyyyMMdd'), N'-out.jpg') END,
    m.Status,
    CASE m.Status WHEN 'P ' THEN m.FullDayHours + (m.Seed % 3)
                  WHEN 'HD' THEN m.FullDayHours / 2 ELSE NULL END,
    CASE WHEN m.Status = 'P ' AND m.Seed % 17 = 0 THEN 2.0 ELSE 0 END,
    1,
    /* the last three days are still awaiting approval */
    CASE WHEN m.AttendanceDate > DATEADD(DAY, -3, @Today) THEN 0 ELSE 1 END,
    CASE WHEN m.AttendanceDate > DATEADD(DAY, -3, @Today) THEN NULL
         ELSE DATEADD(HOUR, 14, CAST(m.AttendanceDate AS DATETIME2(0))) END,
    CASE WHEN m.Status IN ('A ','WO') THEN NULL
         ELSE DATEADD(MINUTE, DATEDIFF(MINUTE, CAST('00:00' AS TIME), m.StartTime),
                      CAST(m.AttendanceDate AS DATETIME2(0))) END,
    CASE WHEN m.Seed % 31 = 0 THEN 1 ELSE 0 END,
    CONCAT(N'DEV-', m.EmpID), N'5.0.0',
    DATEADD(HOUR, 9, CAST(m.AttendanceDate AS DATETIME2(0)))
FROM marked AS m;

PRINT CONCAT('  attendance rows  = ', @@ROWCOUNT);
END
GO

/*==============================================================================
  TURNOUT SNAPSHOTS
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

IF EXISTS (SELECT 1 FROM ops.Turnout WHERE CompanyID = @Diti)
    PRINT '  turnout already seeded, skipping.';
ELSE
BEGIN
INSERT INTO ops.Turnout (CompanyID, BranchID, UnitID, TurnoutDate, ShiftID,
                         RequiredNos, PresentNos, AbsentNos, RelieverNos, InsertDate)
SELECT a.CompanyID, MAX(a.BranchID), a.UnitID, a.AttendanceDate, a.ShiftID,
       ISNULL(MAX(p.Req), 0),
       SUM(CASE WHEN a.Status IN ('P ','DS') THEN 1 ELSE 0 END),
       SUM(CASE WHEN a.Status = 'A ' THEN 1 ELSE 0 END),
       0,
       DATEADD(HOUR, 10, CAST(a.AttendanceDate AS DATETIME2(0)))
FROM ops.Attendance AS a
OUTER APPLY (SELECT Req = SUM(RequiredStrength) FROM crm.UnitPost AS up
             WHERE up.UnitID = a.UnitID AND up.ShiftID = a.ShiftID AND up.IsActive = 1) AS p
WHERE a.CompanyID = @Diti AND a.AttendanceDate >= DATEADD(DAY, -30, @Today)
GROUP BY a.CompanyID, a.UnitID, a.AttendanceDate, a.ShiftID;

PRINT CONCAT('  turnout rows     = ', @@ROWCOUNT);
END
GO

/*==============================================================================
  QR PATROL SCANS - 6% of checkpoints deliberately missed
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

IF EXISTS (SELECT 1 FROM ops.QrScanLog WHERE CompanyID = @Diti)
    PRINT '  patrol scans already seeded, skipping.';
ELSE
BEGIN
;WITH d AS (SELECT [Date] FROM dbo.fnDateRange(DATEADD(DAY, -29, @Today), @Today)),
cp AS (
    SELECT rc.RoundID, rc.QrID, rc.SequenceNo, r.UnitID, r.StartTime,
           q.Latitude, q.Longitude, q.MaxDistanceMeters, q.RequirePhoto
    FROM ops.PatrolRoundCheckpoint AS rc
    INNER JOIN ops.PatrolRound  AS r ON r.RoundID = rc.RoundID
    INNER JOIN ops.QrCheckpoint AS q ON q.QrID = rc.QrID
    WHERE r.CompanyID = @Diti
),
/*  Prefer the night guard, since patrol rounds are a night activity, but fall
    back to any active guard on the unit. Requiring IsNight = 1 outright left
    every round on a day-only unit with no scans at all.  */
guard AS (
    SELECT dp.UnitID,
           EmpID = MIN(dp.EmpID),
           Rnk   = ROW_NUMBER() OVER (PARTITION BY dp.UnitID ORDER BY s.IsNight DESC)
    FROM ops.Deployment AS dp
    INNER JOIN mst.Shift AS s ON s.ShiftID = dp.ShiftID
    WHERE dp.CompanyID = @Diti AND dp.Status = N'Active' AND dp.IsCancel = 0
    GROUP BY dp.UnitID, s.IsNight
),
sched AS (
    SELECT cp.*, d.[Date] AS ScanDate, g.EmpID,
           Seed = (cp.QrID * 41 + DATEPART(DAYOFYEAR, d.[Date]) * 23) % 100
    FROM cp
    CROSS JOIN d
    INNER JOIN guard AS g ON g.UnitID = cp.UnitID AND g.Rnk = 1
)
INSERT INTO ops.QrScanLog (CompanyID, QrID, UnitID, EmpID, UserID, RoundID, RoundNo, Scantime,
                           Latitude, Longitude, DistanceMeters, IsWithinRange, ImageUrl,
                           IsOffline, DeviceID, AppVersion, InsertDate)
SELECT
    @Diti, p.QrID, p.UnitID, p.EmpID,
    (SELECT TOP (1) UserID FROM sec.Users WHERE EmpID = p.EmpID),
    p.RoundID, p.SequenceNo,
    DATEADD(MINUTE, DATEDIFF(MINUTE, CAST('00:00' AS TIME), p.StartTime) + (p.SequenceNo * 12) + (p.Seed % 9),
            CAST(p.ScanDate AS DATETIME2(0))),
    p.Latitude  + (p.Seed % 5 - 2) * 0.00005,
    p.Longitude + (p.Seed % 5 - 2) * 0.00005,
    CASE WHEN p.Seed % 20 = 0 THEN 130 ELSE (p.Seed % 6) * 5 END,
    CASE WHEN p.Seed % 20 = 0 THEN 0 ELSE 1 END,
    CASE WHEN p.RequirePhoto = 1
         THEN CONCAT(N'https://cdn.diti365.example/patrol/', p.QrID, N'-',
                     FORMAT(p.ScanDate, 'yyyyMMdd'), N'.jpg') ELSE NULL END,
    0, CONCAT(N'DEV-', p.EmpID), N'5.0.0',
    DATEADD(MINUTE, DATEDIFF(MINUTE, CAST('00:00' AS TIME), p.StartTime), CAST(p.ScanDate AS DATETIME2(0)))
FROM sched AS p
WHERE p.Seed % 17 <> 0;   -- ~6% of expected scans never happen

PRINT CONCAT('  qr scans         = ', @@ROWCOUNT);
END
GO

/*==============================================================================
  LOCATION PINGS for the supervisors
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

IF EXISTS (SELECT 1 FROM ops.LocationLog WHERE CompanyID = @Diti)
    PRINT '  location pings already seeded, skipping.';
ELSE
BEGIN
;WITH sup AS (
    SELECT TOP (5) u.UserID, u.EmpID, e.UnitID, un.Latitude, un.Longitude
    FROM sec.Users AS u
    INNER JOIN sec.Role AS r ON r.RoleID = u.RoleID AND r.RoleCode = N'SUPERVISOR'
    INNER JOIN hr.Employee AS e ON e.EmpID = u.EmpID
    LEFT  JOIN crm.Unit AS un ON un.UnitID = e.UnitID
    WHERE u.CompanyID = @Diti
),
d AS (SELECT [Date] FROM dbo.fnDateRange(DATEADD(DAY, -6, @Today), @Today)),
mins AS (SELECT TOP (60) m = (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1) * 8 FROM sys.all_objects)
INSERT INTO ops.LocationLog (CompanyID, UserID, EmpID, UnitID, Latitude, Longitude,
                             Accuracy, Speed, BatteryLevel, LoggedAt, Source, DeviceID)
SELECT @Diti, s.UserID, s.EmpID, s.UnitID,
       ISNULL(s.Latitude, 28.6000000)  + SIN(mins.m / 9.0) * 0.0060,
       ISNULL(s.Longitude, 77.2000000) + COS(mins.m / 9.0) * 0.0060,
       12.0 + (mins.m % 9), (mins.m % 27),
       CAST(100 - (mins.m / 8) AS TINYINT),
       DATEADD(MINUTE, 480 + mins.m, CAST(d.[Date] AS DATETIME2(0))),
       CASE WHEN mins.m % 3 = 0 THEN 'BG' ELSE 'FG' END,
       CONCAT(N'DEV-', s.EmpID)
FROM sup AS s CROSS JOIN d CROSS JOIN mins;

PRINT CONCAT('  location pings   = ', @@ROWCOUNT);
END
GO

/*==============================================================================
  TASKS, INCIDENTS, FIELD REPORTS, COMPLAINTS, GATE PASSES
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @Admin INT = (SELECT UserID FROM sec.Users WHERE UserName = N'diti.admin');
DECLARE @Ops   INT = (SELECT UserID FROM sec.Users WHERE UserName = N'diti.ops');

IF EXISTS (SELECT 1 FROM ops.Task WHERE CompanyID = @Diti)
    PRINT '  tasks already seeded, skipping.';
ELSE
BEGIN
;WITH n AS (SELECT TOP (120) i = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM sys.all_objects),
assignee AS (SELECT UserID, rn = ROW_NUMBER() OVER (ORDER BY UserID)
             FROM sec.Users WHERE CompanyID = @Diti AND UserName LIKE N'diti.%')
INSERT INTO ops.Task (CompanyID, BranchID, UnitID, Heading, Description, Assignedby, Assignedto,
                      StartDate, EndDate, DueDays, PriorityID, TaskStatusID, Isclosed,
                      ClosedOn, Important, InsertDate, InsertUserID)
SELECT @Diti, NULL,
       (SELECT TOP (1) UnitID FROM crm.Unit WHERE CompanyID = @Diti ORDER BY (n.i * UnitID) % 13),
       CONCAT(N'Task #', n.i, N' - ',
              CASE n.i % 6 WHEN 0 THEN N'Verify guard grooming at site'
                           WHEN 1 THEN N'Collect signed muster from client'
                           WHEN 2 THEN N'Replace damaged uniform'
                           WHEN 3 THEN N'Follow up police verification'
                           WHEN 4 THEN N'Check fire extinguisher expiry'
                           ELSE N'Submit weekly site report' END),
       N'Auto-generated demo task.',
       @Admin, a.UserID,
       DATEADD(DAY, -(n.i % 60), @Today),
       DATEADD(DAY, -(n.i % 60) + 5, @Today),
       5,
       ((n.i % 4) + 1),
       ts.TaskStatusID,
       ts.IsTerminal,
       CASE WHEN ts.IsTerminal = 1 THEN DATEADD(DAY, -(n.i % 60) + 4, CAST(@Today AS DATETIME2(0))) ELSE NULL END,
       CASE WHEN n.i % 11 = 0 THEN 1 ELSE 0 END,
       DATEADD(DAY, -(n.i % 60), CAST(@Today AS DATETIME2(0))), @Admin
FROM n
INNER JOIN assignee AS a ON a.rn = (n.i % (SELECT COUNT(*) FROM assignee)) + 1
INNER JOIN mst.TaskStatus AS ts ON ts.SortOrder = (n.i % 6) + 1;

INSERT INTO ops.TaskStatusHistory (CompanyID, TaskID, FromStatusID, ToStatusID, ChangedBy, ChangedOn, Remark)
SELECT t.CompanyID, t.TaskID, NULL, t.TaskStatusID, t.Assignedby, t.InsertDate, N'Task created'
FROM ops.Task AS t WHERE t.CompanyID = @Diti;
END
GO

DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @Ops INT = (SELECT UserID FROM sec.Users WHERE UserName = N'diti.ops');

IF EXISTS (SELECT 1 FROM ops.Incident WHERE CompanyID = @Diti)
    PRINT '  incidents already seeded, skipping.';
ELSE
BEGIN
;WITH n AS (SELECT TOP (35) i = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM sys.all_objects),
u AS (SELECT UnitID, BranchID, rn = ROW_NUMBER() OVER (ORDER BY UnitID) FROM crm.Unit WHERE CompanyID = @Diti),
t AS (SELECT IncidentTypeID, Severity, rn = ROW_NUMBER() OVER (ORDER BY IncidentTypeID)
      FROM mst.IncidentType WHERE CompanyID IS NULL)
INSERT INTO ops.Incident (CompanyID, BranchID, UnitID, IncidentTypeID, IncidentDate, IncidentTime,
                          Severity, Remark, ActionTaken, ReportedBy, IsClosed, ClosedOn, InsertDate, InsertUserID)
SELECT @Diti, u.BranchID, u.UnitID, t.IncidentTypeID,
       DATEADD(DAY, -(n.i * 2), @Today),
       CAST(DATEADD(MINUTE, (n.i * 37) % 1440, CAST('00:00' AS TIME)) AS TIME(0)),
       t.Severity,
       CONCAT(N'Demo incident #', n.i, N' recorded by the supervisor on site.'),
       CASE WHEN n.i % 3 <> 0 THEN N'Reported to client and additional guard posted.' ELSE NULL END,
       @Ops,
       CASE WHEN n.i % 3 <> 0 THEN 1 ELSE 0 END,
       CASE WHEN n.i % 3 <> 0 THEN DATEADD(DAY, -(n.i * 2) + 1, CAST(@Today AS DATETIME2(0))) ELSE NULL END,
       DATEADD(DAY, -(n.i * 2), CAST(@Today AS DATETIME2(0))), @Ops
FROM n
INNER JOIN u ON u.rn = (n.i % 12) + 1
INNER JOIN t ON t.rn = (n.i % 10) + 1;
END
GO

DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

IF EXISTS (SELECT 1 FROM ops.Complaint WHERE CompanyID = @Diti)
    PRINT '  complaints already seeded, skipping.';
ELSE
BEGIN
;WITH n AS (SELECT TOP (45) i = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM sys.all_objects),
u AS (SELECT UnitID, ClientID, BranchID, rn = ROW_NUMBER() OVER (ORDER BY UnitID) FROM crm.Unit WHERE CompanyID = @Diti),
ct AS (SELECT ComplaintTypeID, ComplaintTypeName, DefaultSlaHours,
              rn = ROW_NUMBER() OVER (ORDER BY ComplaintTypeID)
       FROM mst.ComplaintType WHERE CompanyID IS NULL),
cu AS (SELECT UserID, ClientID FROM sec.Users WHERE CompanyID = @Diti AND ClientID IS NOT NULL)
INSERT INTO ops.Complaint (CompanyID, BranchID, UnitID, ClientID, RaisedByUserID, ComplaintTypeID,
                           Complainttype, Description, DueOn, Status, IsClosed, ClosedOn,
                           ClosureRemark, InsertDate, InsertUserID)
SELECT @Diti, u.BranchID, u.UnitID, u.ClientID,
       (SELECT TOP (1) UserID FROM cu WHERE cu.ClientID = u.ClientID),
       ct.ComplaintTypeID, ct.ComplaintTypeName,
       CONCAT(N'Demo complaint #', n.i, N': ', ct.ComplaintTypeName, N' observed at the site.'),
       DATEADD(HOUR, ct.DefaultSlaHours, DATEADD(DAY, -(n.i), CAST(@Today AS DATETIME2(0)))),
       CASE WHEN n.i % 9 = 0 THEN N'Open' WHEN n.i <= 25 THEN N'Closed' ELSE N'InProgress' END,
       CASE WHEN n.i <= 25 AND n.i % 9 <> 0 THEN 1 ELSE 0 END,
       CASE WHEN n.i <= 25 AND n.i % 9 <> 0 THEN DATEADD(DAY, -(n.i) + 1, CAST(@Today AS DATETIME2(0))) ELSE NULL END,
       CASE WHEN n.i <= 25 AND n.i % 9 <> 0 THEN N'Guard counselled, client informed.' ELSE NULL END,
       DATEADD(DAY, -(n.i), CAST(@Today AS DATETIME2(0))), NULL
FROM n
INNER JOIN u  ON u.rn  = (n.i % 12) + 1
INNER JOIN ct ON ct.rn = (n.i % 9) + 1;

INSERT INTO ops.ComplaintHistory (CompanyID, ComplaintID, Status, Remark, ChangedOn)
SELECT c.CompanyID, c.ComplaintID, N'Open', N'Complaint raised', c.InsertDate
FROM ops.Complaint AS c WHERE c.CompanyID = @Diti;
END
GO

DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @Gate INT = (SELECT UserID FROM sec.Users WHERE UserName = N'diti.gate1');

IF EXISTS (SELECT 1 FROM ops.GatePass WHERE CompanyID = @Diti)
    PRINT '  gate passes already seeded, skipping.';
ELSE
BEGIN
;WITH n AS (SELECT TOP (300) i = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM sys.all_objects),
u AS (SELECT UnitID, BranchID, rn = ROW_NUMBER() OVER (ORDER BY UnitID) FROM crm.Unit WHERE CompanyID = @Diti)
INSERT INTO ops.GatePass (CompanyID, BranchID, UnitID, Dated, Name, MobileNo, Purpose,
                          WhomToMeet, VehicleNo, InTime, OutTime, InsertDate, InsertUserID)
SELECT @Diti, u.BranchID, u.UnitID, DATEADD(DAY, -(n.i % 30), @Today),
       CONCAT(N'Visitor ', n.i),
       N'99' + RIGHT(N'00000000' + CAST(10000000 + n.i * 313 AS NVARCHAR(10)), 8),
       CASE n.i % 5 WHEN 0 THEN N'Vendor delivery' WHEN 1 THEN N'Client meeting'
                    WHEN 2 THEN N'Maintenance' WHEN 3 THEN N'Interview' ELSE N'Personal visit' END,
       N'Facility Manager',
       CASE WHEN n.i % 3 = 0 THEN CONCAT(N'DL', 1 + (n.i % 9), N'C', 1000 + n.i) ELSE NULL END,
       DATEADD(MINUTE, 540 + (n.i * 7) % 480, CAST(DATEADD(DAY, -(n.i % 30), @Today) AS DATETIME2(0))),
       CASE WHEN n.i % 12 = 0 THEN NULL
            ELSE DATEADD(MINUTE, 540 + (n.i * 7) % 480 + 45 + (n.i % 90),
                         CAST(DATEADD(DAY, -(n.i % 30), @Today) AS DATETIME2(0))) END,
       DATEADD(DAY, -(n.i % 30), CAST(@Today AS DATETIME2(0))), @Gate
FROM n
INNER JOIN u ON u.rn = (n.i % 12) + 1;
END
GO

/*==============================================================================
  SALES
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @SalesUser INT = (SELECT UserID FROM sec.Users WHERE UserName = N'diti.sales1');
DECLARE @SalesEmp INT = (SELECT TOP (1) EmpID FROM hr.Employee WHERE CompanyID = @Diti ORDER BY EmpID);

IF EXISTS (SELECT 1 FROM crm.SalesVisit WHERE CompanyID = @Diti)
    PRINT '  sales visits already seeded, skipping.';
ELSE
BEGIN
;WITH n AS (SELECT TOP (90) i = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM sys.all_objects)
INSERT INTO crm.SalesVisit (CompanyID, EmpID, CompanyName, ContactPerson, ContactNo, Location,
                            Latitude, Longitude, Purpose, Remark, VisitDate, InsertDate, InsertUserID)
SELECT @Diti, @SalesEmp,
       CONCAT(CASE n.i % 6 WHEN 0 THEN N'Skyline ' WHEN 1 THEN N'Prime ' WHEN 2 THEN N'Vertex '
                           WHEN 3 THEN N'Zenith ' WHEN 4 THEN N'Crown ' ELSE N'Summit ' END,
              CASE n.i % 4 WHEN 0 THEN N'Industries' WHEN 1 THEN N'Hospitality'
                           WHEN 2 THEN N'Logistics' ELSE N'Realty' END,
              N' - ', n.i),
       CONCAT(N'Mr. Contact ', n.i),
       N'97' + RIGHT(N'00000000' + CAST(20000000 + n.i * 179 AS NVARCHAR(10)), 8),
       CASE n.i % 3 WHEN 0 THEN N'Noida' WHEN 1 THEN N'Gurugram' ELSE N'New Delhi' END,
       28.5000000 + (n.i % 20) * 0.0080, 77.1000000 + (n.i % 25) * 0.0080,
       N'Introductory meeting for manned guarding requirement',
       N'Demo sales visit.',
       DATEADD(DAY, -(n.i), @Today),
       DATEADD(DAY, -(n.i), CAST(@Today AS DATETIME2(0))), @SalesUser
FROM n;

INSERT INTO crm.FollowUp (CompanyID, SalesVisitID, EmpID, CompanyName, ContactPerson, ContactNo,
                          Purpose, FollowupDate, NextFollowupDate, Remark, StopFollow,
                          InsertDate, InsertUserID)
SELECT v.CompanyID, v.VisitID, v.EmpID, v.CompanyName, v.ContactPerson, v.ContactNo,
       N'Quotation discussion',
       DATEADD(DAY, 3, v.VisitDate),
       CASE WHEN v.VisitID % 7 = 0 THEN NULL ELSE DATEADD(DAY, 10, v.VisitDate) END,
       CASE WHEN v.VisitID % 7 = 0 THEN N'Client went with an existing vendor.' ELSE N'Awaiting their budget approval.' END,
       CASE WHEN v.VisitID % 7 = 0 THEN 1 ELSE 0 END,
       DATEADD(DAY, 3, CAST(v.VisitDate AS DATETIME2(0))), v.InsertUserID
FROM crm.SalesVisit AS v
WHERE v.CompanyID = @Diti AND v.VisitID % 2 = 0;
END
GO

/*==============================================================================
  UNIFORM ISSUES
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

IF EXISTS (SELECT 1 FROM inv.EmployeeIssue WHERE CompanyID = @Diti)
    PRINT '  uniform issues already seeded, skipping.';
ELSE
BEGIN
INSERT INTO inv.EmployeeIssue (CompanyID, BranchID, EmpID, ItemID, IssuedQty, RecievedQty,
                               IssueDate, Rate, RecoverInSalary, InsertDate)
SELECT e.CompanyID, e.BranchID, e.EmpID, i.ItemID, 2, 0,
       DATEADD(DAY, -50, @Today), i.Rate, 0, DATEADD(DAY, -50, CAST(@Today AS DATETIME2(0)))
FROM hr.Employee AS e
CROSS JOIN mst.UniformItem AS i
WHERE e.CompanyID = @Diti AND i.CompanyID IS NULL
  AND i.ItemName IN (N'Shirt', N'Trouser', N'Shoes')
  AND e.EmpID % 3 = 0;

UPDATE s
SET s.Qty = s.Qty - x.Issued
FROM inv.Stock AS s
INNER JOIN (SELECT BranchID, ItemID, Issued = SUM(IssuedQty)
            FROM inv.EmployeeIssue WHERE CompanyID = @Diti
            GROUP BY BranchID, ItemID) AS x
        ON x.BranchID = s.BranchID AND x.ItemID = s.ItemID
WHERE s.CompanyID = @Diti;
END
GO

/*==============================================================================
  HR LIFECYCLE AND TRAINING
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

IF EXISTS (SELECT 1 FROM hr.EmployeeStatusHistory WHERE CompanyID = @Diti)
    PRINT '  hr history already seeded, skipping.';
ELSE
BEGIN
INSERT INTO hr.EmployeeStatusHistory (CompanyID, EmpID, EventType, EventDate, Remark, IsApproved, InsertDate)
SELECT e.CompanyID, e.EmpID, N'Join', e.Doj, N'Initial joining', 1, CAST(e.Doj AS DATETIME2(0))
FROM hr.Employee AS e WHERE e.CompanyID = @Diti;

INSERT INTO hr.Training (CompanyID, BranchID, UnitID, Dated, Timing, Nop, Topic, Remark, InsertDate)
SELECT TOP (10) u.CompanyID, u.BranchID, u.UnitID,
       DATEADD(DAY, -(u.UnitID * 7), @Today), N'10:00 - 12:00', 8,
       CASE u.UnitID % 4 WHEN 0 THEN N'Fire safety drill'
                         WHEN 1 THEN N'Access control procedure'
                         WHEN 2 THEN N'Emergency evacuation'
                         ELSE N'Customer handling and grooming' END,
       N'Demo training session.', DATEADD(DAY, -(u.UnitID * 7), CAST(@Today AS DATETIME2(0)))
FROM crm.Unit AS u WHERE u.CompanyID = @Diti;
END
GO

/*==============================================================================
  DOCUMENTS  (12 expiring within 30 days, to light up the dashboard)
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

IF EXISTS (SELECT 1 FROM doc.Document WHERE CompanyID = @Diti)
    PRINT '  documents already seeded, skipping.';
ELSE
BEGIN
INSERT INTO doc.Document (CompanyID, OwnerType, OwnerID, DocTypeID, DocumentFilename, BlobUrl,
                          MimeType, IssueDate, ExpiryDate, IsVerified, InsertDate)
SELECT e.CompanyID, N'Employee', e.EmpID, dt.DocTypeID,
       CONCAT(dt.DocTypeName, N'-', e.EmpCode, N'.pdf'),
       CONCAT(N'https://cdn.diti365.example/docs/', e.EmpCode, N'/', dt.DocTypeID, N'.pdf'),
       N'application/pdf',
       DATEADD(DAY, -200, @Today),
       CASE WHEN dt.HasExpiry = 0 THEN NULL
            WHEN e.EmpID % 4 = 0 THEN DATEADD(DAY, 10 + (e.EmpID % 18), @Today)   -- expiring soon
            ELSE DATEADD(YEAR, 2, @Today) END,
       1, DATEADD(DAY, -200, CAST(@Today AS DATETIME2(0)))
FROM hr.Employee AS e
CROSS JOIN mst.DocumentType AS dt
WHERE e.CompanyID = @Diti AND dt.CompanyID IS NULL AND dt.OwnerType = N'Employee'
  AND dt.DocTypeName IN (N'Photograph', N'Aadhaar Card', N'Police Verification', N'Medical Certificate');
END
GO

/*==============================================================================
  PAYROLL  - previous month locked, current month draft
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Acct INT = (SELECT UserID FROM sec.Users WHERE UserName = N'diti.accounts');
DECLARE @PrevMonth CHAR(7) = CONVERT(CHAR(7), DATEADD(MONTH, -1, SYSDATETIME()), 126);
DECLARE @ThisMonth CHAR(7) = CONVERT(CHAR(7), SYSDATETIME(), 126);
DECLARE @RunID INT;

IF EXISTS (SELECT 1 FROM fin.SalaryRun WHERE CompanyID = @Diti)
    PRINT '  payroll runs already seeded, skipping.';
ELSE
BEGIN
EXEC dbo.usp_Payroll_Generate @CompanyID = @Diti, @UserID = @Acct,
                              @MonthYear = @PrevMonth, @RunID = @RunID OUTPUT;
IF @RunID IS NOT NULL
    EXEC dbo.usp_Payroll_Lock @CompanyID = @Diti, @UserID = @Acct, @RunID = @RunID;

SET @RunID = NULL;
EXEC dbo.usp_Payroll_Generate @CompanyID = @Diti, @UserID = @Acct,
                              @MonthYear = @ThisMonth, @RunID = @RunID OUTPUT;
END
GO

/*==============================================================================
  INVOICES  - one per client for the previous month
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Acct INT = (SELECT UserID FROM sec.Users WHERE UserName = N'diti.accounts');
DECLARE @M TINYINT  = MONTH(DATEADD(MONTH, -1, SYSDATETIME()));
DECLARE @Y SMALLINT = YEAR(DATEADD(MONTH, -1, SYSDATETIME()));
DECLARE @ClientID INT, @Bid INT, @Seq INT = 0;

IF EXISTS (SELECT 1 FROM fin.Invoice WHERE CompanyID = @Diti)
    PRINT '  invoices already seeded, skipping.';
ELSE
BEGIN
DECLARE cl CURSOR LOCAL FAST_FORWARD FOR
    SELECT ClientID FROM crm.Client AS c
    WHERE c.CompanyID = @Diti AND c.IsCancel = 0
      AND NOT EXISTS (SELECT 1 FROM fin.Invoice AS i
                      WHERE i.ClientID = c.ClientID AND i.Month = @M AND i.Year = @Y AND i.IsCancel = 0)
    ORDER BY c.ClientID;
OPEN cl;
FETCH NEXT FROM cl INTO @ClientID;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Seq = @Seq + 1;
    SET @Bid = NULL;
    BEGIN TRY
        EXEC dbo.usp_Invoice_Generate @CompanyID = @Diti, @UserID = @Acct,
                                      @ClientID = @ClientID, @Month = @M, @Year = @Y, @Bid = @Bid OUTPUT;

        IF @Bid IS NOT NULL
        BEGIN
            /* 2 paid, 1 part-paid, 1 overdue, rest sent */
            IF @Seq <= 2
                EXEC dbo.usp_Receipt_Insert @CompanyID = @Diti, @UserID = @Acct, @ClientID = @ClientID,
                     @Amount = 1, @Bid = @Bid, @Mode = N'NEFT', @RefNo = N'SEED';
            UPDATE fin.Invoice
            SET Status = CASE WHEN @Seq <= 2 THEN N'Paid'
                              WHEN @Seq = 3 THEN N'PartPaid'
                              WHEN @Seq = 4 THEN N'Overdue'
                              ELSE N'Sent' END,
                ReceivedAmount = CASE WHEN @Seq <= 2 THEN GrandTotal
                                      WHEN @Seq = 3 THEN ROUND(GrandTotal * 0.4, 2) ELSE 0 END,
                DueDate = CASE WHEN @Seq = 4 THEN DATEADD(DAY, -20, CAST(SYSDATETIME() AS DATE)) ELSE DueDate END,
                SentOn  = SYSDATETIME()
            WHERE Bid = @Bid;
        END
    END TRY
    BEGIN CATCH
        PRINT CONCAT('  invoice skipped for client ', @ClientID, ': ', ERROR_MESSAGE());
    END CATCH
    FETCH NEXT FROM cl INTO @ClientID;
END
CLOSE cl; DEALLOCATE cl;
END
GO

/*==============================================================================
  SUMMARY REFRESH
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @M CHAR(7);
DECLARE @i INT = 0;
WHILE @i < 4
BEGIN
    SET @M = CONVERT(CHAR(7), DATEADD(MONTH, -@i, SYSDATETIME()), 126);
    EXEC dbo.usp_Attendance_RefreshSummary @CompanyID = @Diti, @MonthYear = @M;
    SET @i = @i + 1;
END
GO

PRINT '720_seed_demo_transactions.sql  ->  OK';
GO
SELECT [What] = v.n, [Rows] = v.c FROM (VALUES
    ('attendance',   (SELECT COUNT(*) FROM ops.Attendance)),
    ('turnout',      (SELECT COUNT(*) FROM ops.Turnout)),
    ('qr scans',     (SELECT COUNT(*) FROM ops.QrScanLog)),
    ('loc pings',    (SELECT COUNT(*) FROM ops.LocationLog)),
    ('tasks',        (SELECT COUNT(*) FROM ops.Task)),
    ('incidents',    (SELECT COUNT(*) FROM ops.Incident)),
    ('complaints',   (SELECT COUNT(*) FROM ops.Complaint)),
    ('gate passes',  (SELECT COUNT(*) FROM ops.GatePass)),
    ('sales visits', (SELECT COUNT(*) FROM crm.SalesVisit)),
    ('documents',    (SELECT COUNT(*) FROM doc.Document)),
    ('salary runs',  (SELECT COUNT(*) FROM fin.SalaryRun)),
    ('salary rows',  (SELECT COUNT(*) FROM fin.Salary)),
    ('invoices',     (SELECT COUNT(*) FROM fin.Invoice))
) AS v(n, c);
GO
