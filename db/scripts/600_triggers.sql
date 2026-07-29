/*==============================================================================
  600_triggers.sql
  Audit trail and integrity guards.
  Spec: docs/prd/01-database.md §6

  DEVIATIONS FROM THE SPEC (see DECISIONS.md #23 and #24)
  -------------------------------------------------------
  * The spec proposed an INSTEAD OF trigger on ops.Attendance to compute
    distance and status. That is done in the stored procedures instead, because
    an INSTEAD OF trigger on a high-volume IDENTITY table complicates
    SCOPE_IDENTITY and OUTPUT, and the computation belongs with the validation.
    What remains here is an AFTER trigger that VALIDATES rather than computes -
    it catches any write that bypassed the procedures.
  * All triggers handle multi-row DML. None returns a result set.
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*==============================================================================
  AUDIT
==============================================================================*/
CREATE OR ALTER TRIGGER hr.TR_Employee_Audit
ON hr.Employee
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    INSERT INTO aud.AuditLog (CompanyID, UserID, TableName, RecordID, [Action], OldValues, NewValues, ChangedAt)
    SELECT
        ISNULL(i.CompanyID, d.CompanyID),
        ISNULL(i.UpdateUserID, i.InsertUserID),
        N'hr.Employee',
        CAST(ISNULL(i.EmpID, d.EmpID) AS NVARCHAR(50)),
        CASE WHEN i.EmpID IS NULL THEN 'D' WHEN d.EmpID IS NULL THEN 'I' ELSE 'U' END,
        CASE WHEN d.EmpID IS NULL THEN NULL ELSE
            (SELECT d.EmpCode, d.FirstName, d.LastName, d.Mobile1, d.DesignationID, d.UnitID,
                    d.EmpStatus, d.Doj, d.Dol, d.IsBlackListed, d.BeltNo
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CASE WHEN i.EmpID IS NULL THEN NULL ELSE
            (SELECT i.EmpCode, i.FirstName, i.LastName, i.Mobile1, i.DesignationID, i.UnitID,
                    i.EmpStatus, i.Doj, i.Dol, i.IsBlackListed, i.BeltNo
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        SYSDATETIME()
    FROM inserted AS i
    FULL OUTER JOIN deleted AS d ON d.EmpID = i.EmpID;
END;
GO

CREATE OR ALTER TRIGGER ops.TR_Attendance_Audit
ON ops.Attendance
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    INSERT INTO aud.AuditLog (CompanyID, UserID, TableName, RecordID, [Action], OldValues, NewValues, ChangedAt)
    SELECT
        ISNULL(i.CompanyID, d.CompanyID),
        ISNULL(i.UpdateUserID, i.ApprovedBy),
        N'ops.Attendance',
        CAST(ISNULL(i.AttendanceID, d.AttendanceID) AS NVARCHAR(50)),
        CASE WHEN i.AttendanceID IS NULL THEN 'D' ELSE 'U' END,
        (SELECT d.EmpID, d.AttendanceDate, d.InTime, d.OutTime, d.Status,
                d.WorkedHours, d.OtHours, d.ApprovalStatus
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
        CASE WHEN i.AttendanceID IS NULL THEN NULL ELSE
            (SELECT i.EmpID, i.AttendanceDate, i.InTime, i.OutTime, i.Status,
                    i.WorkedHours, i.OtHours, i.ApprovalStatus
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        SYSDATETIME()
    FROM deleted AS d
    LEFT JOIN inserted AS i ON i.AttendanceID = d.AttendanceID
    -- only log a real change, not a no-op update
    WHERE i.AttendanceID IS NULL
       OR ISNULL(i.Status, '') <> ISNULL(d.Status, '')
       OR ISNULL(i.ApprovalStatus, 255) <> ISNULL(d.ApprovalStatus, 255)
       OR ISNULL(i.InTime, '1900-01-01') <> ISNULL(d.InTime, '1900-01-01')
       OR ISNULL(i.OutTime, '1900-01-01') <> ISNULL(d.OutTime, '1900-01-01');
END;
GO

CREATE OR ALTER TRIGGER fin.TR_Salary_Audit
ON fin.Salary
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    INSERT INTO aud.AuditLog (CompanyID, UserID, TableName, RecordID, [Action], OldValues, NewValues, ChangedAt)
    SELECT
        ISNULL(i.CompanyID, d.CompanyID),
        ISNULL(i.UpdateUserID, i.InsertUserID),
        N'fin.Salary',
        CAST(ISNULL(i.WcsSalaryID, d.WcsSalaryID) AS NVARCHAR(50)),
        CASE WHEN i.WcsSalaryID IS NULL THEN 'D' WHEN d.WcsSalaryID IS NULL THEN 'I' ELSE 'U' END,
        CASE WHEN d.WcsSalaryID IS NULL THEN NULL ELSE
            (SELECT d.EmpID, d.MonthYear, d.PayableDays, d.TotalEarnings, d.DeductionAmt, d.NetPayble
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CASE WHEN i.WcsSalaryID IS NULL THEN NULL ELSE
            (SELECT i.EmpID, i.MonthYear, i.PayableDays, i.TotalEarnings, i.DeductionAmt, i.NetPayble, i.EditReason
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        SYSDATETIME()
    FROM inserted AS i
    FULL OUTER JOIN deleted AS d ON d.WcsSalaryID = i.WcsSalaryID;
END;
GO

CREATE OR ALTER TRIGGER sec.TR_Users_Audit
ON sec.Users
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    INSERT INTO aud.AuditLog (CompanyID, UserID, TableName, RecordID, [Action], OldValues, NewValues, ChangedAt)
    SELECT
        ISNULL(i.CompanyID, d.CompanyID),
        ISNULL(i.UpdateUserID, i.InsertUserID),
        N'sec.Users',
        CAST(ISNULL(i.UserID, d.UserID) AS NVARCHAR(50)),
        CASE WHEN i.UserID IS NULL THEN 'D' WHEN d.UserID IS NULL THEN 'I' ELSE 'U' END,
        CASE WHEN d.UserID IS NULL THEN NULL ELSE
            (SELECT d.UserName, d.MobileNo, d.RoleID, d.BranchID, d.IsActive, d.IsLocked, d.DeviceID
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CASE WHEN i.UserID IS NULL THEN NULL ELSE
            (SELECT i.UserName, i.MobileNo, i.RoleID, i.BranchID, i.IsActive, i.IsLocked, i.DeviceID
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        SYSDATETIME()
    FROM inserted AS i
    FULL OUTER JOIN deleted AS d ON d.UserID = i.UserID
    -- password-hash-only updates are not interesting, and must never be logged
    WHERE i.UserID IS NULL OR d.UserID IS NULL
       OR ISNULL(i.RoleID, 0)   <> ISNULL(d.RoleID, 0)
       OR ISNULL(i.BranchID, 0) <> ISNULL(d.BranchID, 0)
       OR ISNULL(i.IsActive, 0) <> ISNULL(d.IsActive, 0)
       OR ISNULL(i.IsLocked, 0) <> ISNULL(d.IsLocked, 0)
       OR ISNULL(i.MobileNo, N'') <> ISNULL(d.MobileNo, N'');
END;
GO

CREATE OR ALTER TRIGGER ops.TR_Deployment_Audit
ON ops.Deployment
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    INSERT INTO aud.AuditLog (CompanyID, UserID, TableName, RecordID, [Action], OldValues, NewValues, ChangedAt)
    SELECT
        ISNULL(i.CompanyID, d.CompanyID),
        ISNULL(i.UpdateUserID, i.InsertUserID),
        N'ops.Deployment',
        CAST(ISNULL(i.DeploymentID, d.DeploymentID) AS NVARCHAR(50)),
        CASE WHEN i.DeploymentID IS NULL THEN 'D' WHEN d.DeploymentID IS NULL THEN 'I' ELSE 'U' END,
        CASE WHEN d.DeploymentID IS NULL THEN NULL ELSE
            (SELECT d.EmpID, d.UnitID, d.PostID, d.ShiftID, d.FromDate, d.ToDate, d.Status
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CASE WHEN i.DeploymentID IS NULL THEN NULL ELSE
            (SELECT i.EmpID, i.UnitID, i.PostID, i.ShiftID, i.FromDate, i.ToDate, i.Status
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        SYSDATETIME()
    FROM inserted AS i
    FULL OUTER JOIN deleted AS d ON d.DeploymentID = i.DeploymentID;
END;
GO

CREATE OR ALTER TRIGGER fin.TR_Invoice_Audit
ON fin.Invoice
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    INSERT INTO aud.AuditLog (CompanyID, UserID, TableName, RecordID, [Action], OldValues, NewValues, ChangedAt)
    SELECT
        ISNULL(i.CompanyID, d.CompanyID),
        ISNULL(i.UpdateUserID, i.InsertUserID),
        N'fin.Invoice',
        CAST(ISNULL(i.Bid, d.Bid) AS NVARCHAR(50)),
        CASE WHEN i.Bid IS NULL THEN 'D' WHEN d.Bid IS NULL THEN 'I' ELSE 'U' END,
        CASE WHEN d.Bid IS NULL THEN NULL ELSE
            (SELECT d.InvoiceNo, d.ClientID, d.GrandTotal, d.ReceivedAmount, d.Status
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        CASE WHEN i.Bid IS NULL THEN NULL ELSE
            (SELECT i.InvoiceNo, i.ClientID, i.GrandTotal, i.ReceivedAmount, i.Status
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
        SYSDATETIME()
    FROM inserted AS i
    FULL OUTER JOIN deleted AS d ON d.Bid = i.Bid;
END;
GO

/*==============================================================================
  INTEGRITY GUARDS
==============================================================================*/

/*  Licence enforcement: a tenant cannot exceed the seats it pays for.  */
CREATE OR ALTER TRIGGER sec.TR_Users_UserCount
ON sec.Users
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Affected TABLE (CompanyID INT PRIMARY KEY);
    INSERT INTO @Affected (CompanyID)
    SELECT DISTINCT CompanyID FROM (
        SELECT CompanyID FROM inserted WHERE CompanyID IS NOT NULL
        UNION
        SELECT CompanyID FROM deleted  WHERE CompanyID IS NOT NULL
    ) AS x;

    UPDATE c
    SET c.UserCount = (SELECT COUNT(*) FROM sec.Users AS u
                       WHERE u.CompanyID = c.CompanyID AND u.IsCancel = 0 AND u.IsActive = 1)
    FROM org.Company AS c
    INNER JOIN @Affected AS a ON a.CompanyID = c.CompanyID;

    IF EXISTS (SELECT 1 FROM org.Company AS c
               INNER JOIN @Affected AS a ON a.CompanyID = c.CompanyID
               WHERE c.UserCount > c.MaxUsers)
    BEGIN
        THROW 51001, 'This would exceed the licensed user limit for the company.', 1;
    END
END;
GO

/*  A locked or paid payroll month is immutable.  */
CREATE OR ALTER TRIGGER fin.TR_Salary_LockGuard
ON fin.Salary
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM deleted AS d
        INNER JOIN fin.SalaryRun AS r ON r.RunID = d.RunID
        WHERE r.Status IN (N'Locked', N'Paid')
    )
    BEGIN
        THROW 51002, 'This payroll run is locked. Salary rows cannot be changed or deleted.', 1;
    END
END;
GO

/*  Validation, not computation: catches any attendance write that bypassed the
    procedures and therefore carries no server-computed distance.  */
CREATE OR ALTER TRIGGER ops.TR_Attendance_Validate
ON ops.Attendance
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        INNER JOIN crm.Unit AS u ON u.UnitID = i.UnitID
        WHERE i.InLatitude IS NOT NULL
          AND u.Latitude IS NOT NULL
          AND i.InDistanceMeters IS NULL
    )
    BEGIN
        THROW 51003, 'Attendance written without a server-computed distance. Use usp_Attendance_InsertPunchIn.', 1;
    END

    IF EXISTS (SELECT 1 FROM inserted WHERE IsMockLocation = 1)
    BEGIN
        THROW 51004, 'Attendance cannot be recorded from a mocked location.', 1;
    END
END;
GO

/*  QR scans: derive IsWithinRange server-side even if a scan arrives by some
    other path, and never let the client decide it.  */
CREATE OR ALTER TRIGGER ops.TR_QrScanLog_Range
ON ops.QrScanLog
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE s
    SET s.DistanceMeters = dbo.fnDistanceMeters(s.Latitude, s.Longitude, q.Latitude, q.Longitude),
        s.IsWithinRange  = CASE
                              WHEN q.Latitude IS NULL OR s.Latitude IS NULL THEN 1
                              WHEN dbo.fnDistanceMeters(s.Latitude, s.Longitude, q.Latitude, q.Longitude)
                                   <= q.MaxDistanceMeters THEN 1
                              ELSE 0
                           END
    FROM ops.QrScanLog AS s
    INNER JOIN inserted AS i ON i.ScanID = s.ScanID
    INNER JOIN ops.QrCheckpoint AS q ON q.QrID = s.QrID
    WHERE i.DistanceMeters IS NULL;
END;
GO

/*  Document expiry alerts at T-90 / T-30 / T-7.  */
CREATE OR ALTER TRIGGER doc.TR_Document_ExpiryAlert
ON doc.Document
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(ExpiryDate) AND NOT EXISTS (SELECT 1 FROM deleted) 
        AND NOT EXISTS (SELECT 1 FROM inserted WHERE ExpiryDate IS NOT NULL) RETURN;

    /* remove alerts for a changed expiry date, then re-seed */
    DELETE a
    FROM doc.DocumentExpiryAlert AS a
    INNER JOIN inserted AS i ON i.DocumentID = a.DocumentID
    WHERE a.IsSent = 0;

    INSERT INTO doc.DocumentExpiryAlert (CompanyID, DocumentID, AlertOn, AlertLevel)
    SELECT i.CompanyID, i.DocumentID, DATEADD(DAY, -lvl.Days, i.ExpiryDate), lvl.Days
    FROM inserted AS i
    CROSS JOIN (VALUES (90), (30), (7)) AS lvl(Days)
    WHERE i.ExpiryDate IS NOT NULL
      AND i.IsCancel = 0
      AND DATEADD(DAY, -lvl.Days, i.ExpiryDate) >= CAST(SYSDATETIME() AS DATE)
      AND NOT EXISTS (SELECT 1 FROM doc.DocumentExpiryAlert AS e
                      WHERE e.DocumentID = i.DocumentID AND e.AlertLevel = lvl.Days);
END;
GO

/*  Keep crm.Unit.SupervisorEmpID honest: the supervisor must belong to the
    same company as the unit.  */
CREATE OR ALTER TRIGGER crm.TR_Unit_SupervisorCheck
ON crm.Unit
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        INNER JOIN hr.Employee AS e ON e.EmpID = i.SupervisorEmpID
        WHERE e.CompanyID <> i.CompanyID
    )
    BEGIN
        THROW 51005, 'The supervisor must belong to the same company as the unit.', 1;
    END
END;
GO

PRINT '600_triggers.sql  ->  OK  (12 triggers)';
GO
