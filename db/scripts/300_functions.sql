/*==============================================================================
  300_functions.sql
  Scalar and table-valued functions. Spec: docs/prd/01-database.md §4

  DESIGN NOTE - scalar UDF inlining
  ---------------------------------
  SQL Server 2019+ can inline a scalar UDF into the calling query (Froid), which
  removes the row-by-row penalty that makes scalar UDFs notorious. To stay
  eligible every scalar function below is:
      * a single RETURN expression (no multi-statement body, no variables)
      * WITH SCHEMABINDING
      * free of side effects and of time-dependent built-ins in the expression
  Do not "tidy" these into multi-statement bodies. It will silently cost you
  orders of magnitude on the attendance and payroll queries.

  The two code generators (employee code, invoice number) are STORED PROCEDURES,
  not functions: they must take sp_getapplock and write to mst.CodeCounter, and
  a function may do neither. See DECISIONS.md #14.
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*==============================================================================
  0. DROP FIRST - in reverse dependency order.

  CREATE OR ALTER cannot alter a WITH SCHEMABINDING object that another
  schemabound object references (Msg 3729). fnIsWithinGeofence binds to
  fnDistanceMeters, and fnUserAccessibleUnits binds to fnUserAccessibleBranches,
  so the whole set is dropped and recreated on every run. This is what makes the
  script idempotent.

  Dropping a function that a non-schemabound VIEW references is allowed; the
  views are rebuilt immediately afterwards by 400_views.sql.
==============================================================================*/
DROP PROCEDURE IF EXISTS dbo.usp_Code_NextInvoiceNo;
DROP PROCEDURE IF EXISTS dbo.usp_Code_NextEmpCode;
GO
DROP FUNCTION IF EXISTS dbo.fnUnitRequiredStrength;
GO
DROP FUNCTION IF EXISTS dbo.fnUserAccessibleUnits;      -- binds to fnUserAccessibleBranches
GO
DROP FUNCTION IF EXISTS dbo.fnUserAccessibleBranches;
GO
DROP FUNCTION IF EXISTS dbo.fnDateRange;
GO
DROP FUNCTION IF EXISTS dbo.fnSplitIds;
GO
DROP FUNCTION IF EXISTS dbo.fnPayableDays;
GO
DROP FUNCTION IF EXISTS dbo.fnLwfAmount;
GO
DROP FUNCTION IF EXISTS dbo.fnPtAmount;
GO
DROP FUNCTION IF EXISTS dbo.fnEsicAmount;
GO
DROP FUNCTION IF EXISTS dbo.fnPfAmount;
GO
DROP FUNCTION IF EXISTS dbo.fnAgeInYears;
GO
DROP FUNCTION IF EXISTS dbo.fnAttendanceStatus;
GO
DROP FUNCTION IF EXISTS dbo.fnCalcWorkedHours;
GO
DROP FUNCTION IF EXISTS dbo.fnIsWithinGeofence;         -- binds to fnDistanceMeters
GO
DROP FUNCTION IF EXISTS dbo.fnDistanceMeters;
GO

/*==============================================================================
  1. fnDistanceMeters - Haversine great-circle distance in metres
==============================================================================*/
CREATE OR ALTER FUNCTION dbo.fnDistanceMeters
(
    @Lat1 DECIMAL(10,7), @Lon1 DECIMAL(10,7),
    @Lat2 DECIMAL(10,7), @Lon2 DECIMAL(10,7)
)
RETURNS INT
WITH SCHEMABINDING
AS
BEGIN
    RETURN CASE
        WHEN @Lat1 IS NULL OR @Lon1 IS NULL OR @Lat2 IS NULL OR @Lon2 IS NULL THEN NULL
        ELSE CAST(ROUND(
                 6371000.0 * 2 * ASIN(SQRT(
                     POWER(SIN(RADIANS(CAST(@Lat2 - @Lat1 AS FLOAT)) / 2), 2)
                   + COS(RADIANS(CAST(@Lat1 AS FLOAT))) * COS(RADIANS(CAST(@Lat2 AS FLOAT)))
                   * POWER(SIN(RADIANS(CAST(@Lon2 - @Lon1 AS FLOAT)) / 2), 2)
                 )), 0) AS INT)
    END;
END;
GO

/*==============================================================================
  2. fnIsWithinGeofence - is a coordinate inside a unit's geofence
==============================================================================*/
CREATE OR ALTER FUNCTION dbo.fnIsWithinGeofence
(
    @Lat DECIMAL(10,7), @Lon DECIMAL(10,7), @UnitID INT
)
RETURNS BIT
WITH SCHEMABINDING
AS
BEGIN
    RETURN (
        SELECT CASE
                 WHEN u.Latitude IS NULL OR u.Longitude IS NULL THEN CAST(1 AS BIT)  -- unit not geofenced: allow
                 WHEN @Lat IS NULL OR @Lon IS NULL              THEN CAST(0 AS BIT)
                 WHEN dbo.fnDistanceMeters(@Lat, @Lon, u.Latitude, u.Longitude) <= u.GeofenceRadiusMeters
                                                                THEN CAST(1 AS BIT)
                 ELSE CAST(0 AS BIT)
               END
        FROM crm.Unit AS u
        WHERE u.UnitID = @UnitID
    );
END;
GO

/*==============================================================================
  3. fnCalcWorkedHours - shift aware, handles a night shift crossing midnight
==============================================================================*/
CREATE OR ALTER FUNCTION dbo.fnCalcWorkedHours
(
    @InTime DATETIME2(0), @OutTime DATETIME2(0), @ShiftID INT
)
RETURNS DECIMAL(5,2)
WITH SCHEMABINDING
AS
BEGIN
    RETURN CASE
        WHEN @InTime IS NULL OR @OutTime IS NULL THEN NULL
        WHEN @OutTime >= @InTime
            THEN CAST(DATEDIFF(MINUTE, @InTime, @OutTime) / 60.0 AS DECIMAL(5,2))
        -- out before in: the punch-out belongs to the next calendar day
        ELSE CAST(DATEDIFF(MINUTE, @InTime, DATEADD(DAY, 1, @OutTime)) / 60.0 AS DECIMAL(5,2))
    END;
END;
GO

/*==============================================================================
  4. fnAttendanceStatus - P / HD / A from worked hours and the shift's thresholds
==============================================================================*/
CREATE OR ALTER FUNCTION dbo.fnAttendanceStatus
(
    @WorkedHours DECIMAL(5,2), @ShiftID INT
)
RETURNS CHAR(2)
WITH SCHEMABINDING
AS
BEGIN
    RETURN (
        SELECT CASE
                 WHEN @WorkedHours IS NULL                                   THEN 'A '
                 WHEN @WorkedHours >= ISNULL(s.FullDayHours, 8.00)           THEN 'P '
                 WHEN @WorkedHours >= ISNULL(s.HalfDayHours, 4.00)           THEN 'HD'
                 ELSE 'A '
               END
        FROM (SELECT TOP (1) FullDayHours, HalfDayHours
              FROM mst.Shift WHERE ShiftID = @ShiftID) AS s
    );
END;
GO

/*==============================================================================
  5. fnAgeInYears
==============================================================================*/
CREATE OR ALTER FUNCTION dbo.fnAgeInYears (@Dob DATE, @AsOn DATE)
RETURNS INT
WITH SCHEMABINDING
AS
BEGIN
    RETURN CASE
        WHEN @Dob IS NULL OR @AsOn IS NULL THEN NULL
        ELSE DATEDIFF(YEAR, @Dob, @AsOn)
             - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, @Dob, @AsOn), @Dob) > @AsOn THEN 1 ELSE 0 END
    END;
END;
GO

/*==============================================================================
  6. fnPfAmount - employee PF, applying the wage ceiling from mst.StatutoryRate
==============================================================================*/
CREATE OR ALTER FUNCTION dbo.fnPfAmount (@Basic DECIMAL(18,2), @EffectiveDate DATE)
RETURNS DECIMAL(18,2)
WITH SCHEMABINDING
AS
BEGIN
    RETURN (
        SELECT CASE
                 WHEN @Basic IS NULL OR @Basic <= 0 THEN 0
                 ELSE ROUND(
                        CASE WHEN r.CeilingAmount IS NOT NULL AND @Basic > r.CeilingAmount
                             THEN r.CeilingAmount ELSE @Basic END
                        * r.[Percent] / 100.0, 0)
               END
        FROM (SELECT TOP (1) [Percent], CeilingAmount
              FROM mst.StatutoryRate
              WHERE RateCode = N'PF_EMP' AND IsCancel = 0 AND EffectiveFrom <= @EffectiveDate
              ORDER BY EffectiveFrom DESC) AS r
    );
END;
GO

/*==============================================================================
  7. fnEsicAmount - employee ESIC; zero above the wage ceiling
==============================================================================*/
CREATE OR ALTER FUNCTION dbo.fnEsicAmount (@Gross DECIMAL(18,2), @EffectiveDate DATE)
RETURNS DECIMAL(18,2)
WITH SCHEMABINDING
AS
BEGIN
    RETURN (
        SELECT CASE
                 WHEN @Gross IS NULL OR @Gross <= 0 THEN 0
                 -- ESIC is not deducted at all once gross exceeds the ceiling
                 WHEN r.CeilingAmount IS NOT NULL AND @Gross > r.CeilingAmount THEN 0
                 ELSE CEILING(@Gross * r.[Percent] / 100.0)
               END
        FROM (SELECT TOP (1) [Percent], CeilingAmount
              FROM mst.StatutoryRate
              WHERE RateCode = N'ESIC_EMP' AND IsCancel = 0 AND EffectiveFrom <= @EffectiveDate
              ORDER BY EffectiveFrom DESC) AS r
    );
END;
GO

/*==============================================================================
  8. fnPtAmount - professional tax from the state slab
==============================================================================*/
CREATE OR ALTER FUNCTION dbo.fnPtAmount (@Gross DECIMAL(18,2), @StateID INT, @OnDate DATE)
RETURNS DECIMAL(18,2)
WITH SCHEMABINDING
AS
BEGIN
    RETURN ISNULL((
        SELECT TOP (1) s.Amount
        FROM mst.PtSlab AS s
        WHERE s.StateID = @StateID
          AND s.IsCancel = 0
          AND s.EffectiveFrom <= @OnDate
          AND @Gross >= s.FromAmount
          AND (s.ToAmount IS NULL OR @Gross <= s.ToAmount)
          AND (s.MonthNo IS NULL OR s.MonthNo = MONTH(@OnDate))
        ORDER BY s.EffectiveFrom DESC, s.FromAmount DESC
    ), 0);
END;
GO

/*==============================================================================
  9. fnLwfAmount - labour welfare fund, only in the state's deduction months
==============================================================================*/
CREATE OR ALTER FUNCTION dbo.fnLwfAmount (@StateID INT, @Gross DECIMAL(18,2), @OnDate DATE)
RETURNS DECIMAL(18,2)
WITH SCHEMABINDING
AS
BEGIN
    RETURN ISNULL((
        SELECT TOP (1)
               CASE WHEN s.DeductionMonths IS NULL
                     OR ',' + s.DeductionMonths + ',' LIKE '%,' + CAST(MONTH(@OnDate) AS VARCHAR(2)) + ',%'
                    THEN s.EmployeeAmount ELSE 0 END
        FROM mst.LwfSlab AS s
        WHERE s.StateID = @StateID
          AND s.IsCancel = 0
          AND s.EffectiveFrom <= @OnDate
          AND @Gross >= s.FromAmount
          AND (s.ToAmount IS NULL OR @Gross <= s.ToAmount)
        ORDER BY s.EffectiveFrom DESC, s.FromAmount DESC
    ), 0);
END;
GO

/*==============================================================================
  10. fnPayableDays - present + half days + paid week-offs + paid holidays + leave
==============================================================================*/
CREATE OR ALTER FUNCTION dbo.fnPayableDays (@CompanyID INT, @EmpID INT, @MonthYear CHAR(7))
RETURNS DECIMAL(5,1)
WITH SCHEMABINDING
AS
BEGIN
    RETURN ISNULL((
        SELECT SUM(CASE a.Status
                     WHEN 'P ' THEN 1.0
                     WHEN 'DS' THEN 2.0
                     WHEN 'HD' THEN 0.5
                     WHEN 'WO' THEN 1.0
                     WHEN 'HO' THEN 1.0
                     WHEN 'LV' THEN 1.0
                     ELSE 0.0
                   END)
        FROM ops.Attendance AS a
        WHERE a.CompanyID = @CompanyID
          AND a.EmpID     = @EmpID
          AND a.IsCancel  = 0
          AND a.ApprovalStatus = 1
          AND CONVERT(CHAR(7), a.AttendanceDate, 126) = @MonthYear
    ), 0);
END;
GO

/*==============================================================================
  11. fnSplitIds - CSV of integers to a table
      The app posts comma-joined ids in many places; this is the only sanctioned
      way to consume them. Inline TVF so it inlines into the calling plan.
==============================================================================*/
CREATE OR ALTER FUNCTION dbo.fnSplitIds (@Csv NVARCHAR(MAX))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(value)) AS INT) AS ID
    FROM STRING_SPLIT(ISNULL(@Csv, N''), ',')
    WHERE TRY_CAST(LTRIM(RTRIM(value)) AS INT) IS NOT NULL
);
GO

/*==============================================================================
  12. fnDateRange - calendar spine, used by the attendance register
==============================================================================*/
CREATE OR ALTER FUNCTION dbo.fnDateRange (@FromDate DATE, @ToDate DATE)
RETURNS TABLE
AS
RETURN
(
    WITH n(i) AS (
        SELECT TOP (CASE WHEN @ToDate >= @FromDate THEN DATEDIFF(DAY, @FromDate, @ToDate) + 1 ELSE 0 END)
               ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1
        FROM sys.all_objects a CROSS JOIN sys.all_objects b
    )
    SELECT DATEADD(DAY, i, @FromDate) AS [Date] FROM n
);
GO

/*==============================================================================
  13. fnUserAccessibleBranches - SECURITY CRITICAL
      Every list and report procedure must join to this. It is the single place
      where branch-level data scoping is decided.
==============================================================================*/
CREATE OR ALTER FUNCTION dbo.fnUserAccessibleBranches (@CompanyID INT, @UserID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    -- COMPANY_ADMIN and platform roles: every branch of the tenant
    SELECT b.BranchID
    FROM org.Branch AS b
    INNER JOIN sec.Users AS u ON u.UserID = @UserID
    INNER JOIN sec.Role  AS r ON r.RoleID = u.RoleID
    WHERE b.CompanyID = @CompanyID
      AND b.IsCancel = 0
      AND r.RoleCode IN (N'SUPER_ADMIN', N'COMPANY_ADMIN')

    UNION

    -- everyone else: the branches explicitly granted, plus their home branch
    SELECT ub.BranchID
    FROM sec.UserBranch AS ub
    INNER JOIN org.Branch AS b ON b.BranchID = ub.BranchID AND b.CompanyID = @CompanyID AND b.IsCancel = 0
    WHERE ub.UserID = @UserID

    UNION

    SELECT u.BranchID
    FROM sec.Users AS u
    INNER JOIN org.Branch AS b ON b.BranchID = u.BranchID AND b.CompanyID = @CompanyID AND b.IsCancel = 0
    WHERE u.UserID = @UserID AND u.BranchID IS NOT NULL
);
GO

/*==============================================================================
  14. fnUserAccessibleUnits - SECURITY CRITICAL
==============================================================================*/
CREATE OR ALTER FUNCTION dbo.fnUserAccessibleUnits (@CompanyID INT, @UserID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    -- admins: every unit in the tenant
    SELECT un.UnitID
    FROM crm.Unit AS un
    INNER JOIN sec.Users AS u ON u.UserID = @UserID
    INNER JOIN sec.Role  AS r ON r.RoleID = u.RoleID
    WHERE un.CompanyID = @CompanyID AND un.IsCancel = 0
      AND r.RoleCode IN (N'SUPER_ADMIN', N'COMPANY_ADMIN')

    UNION

    -- branch-scoped roles: units of the branches they can see
    SELECT un.UnitID
    FROM crm.Unit AS un
    INNER JOIN dbo.fnUserAccessibleBranches(@CompanyID, @UserID) AS ab ON ab.BranchID = un.BranchID
    INNER JOIN sec.Users AS u ON u.UserID = @UserID
    INNER JOIN sec.Role  AS r ON r.RoleID = u.RoleID
    WHERE un.CompanyID = @CompanyID AND un.IsCancel = 0
      AND r.RoleCode IN (N'BRANCH_ADMIN', N'OPERATIONS', N'HR', N'ACCOUNTS')

    UNION

    -- client logins: only their own units
    SELECT un.UnitID
    FROM crm.Unit AS un
    INNER JOIN sec.Users AS u ON u.UserID = @UserID AND u.ClientID = un.ClientID
    WHERE un.CompanyID = @CompanyID AND un.IsCancel = 0

    UNION

    -- supervisors: units where they are the named supervisor
    SELECT un.UnitID
    FROM crm.Unit AS un
    INNER JOIN sec.Users AS u ON u.UserID = @UserID AND u.EmpID = un.SupervisorEmpID
    WHERE un.CompanyID = @CompanyID AND un.IsCancel = 0

    UNION

    -- field staff: the unit they are currently deployed to
    SELECT d.UnitID
    FROM ops.Deployment AS d
    INNER JOIN sec.Users AS u ON u.UserID = @UserID AND u.EmpID = d.EmpID
    WHERE d.CompanyID = @CompanyID AND d.Status = N'Active' AND d.IsCancel = 0
);
GO

/*==============================================================================
  15. fnUnitRequiredStrength - contracted strength for a unit on a date,
      adjusted by approved increase/decrease changes and temporary events
==============================================================================*/
CREATE OR ALTER FUNCTION dbo.fnUnitRequiredStrength (@CompanyID INT, @UnitID INT, @OnDate DATE, @ShiftID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT
        BaseStrength   = ISNULL(b.BaseStrength, 0),
        ChangeStrength = ISNULL(c.ChangeStrength, 0),
        EventStrength  = ISNULL(e.EventStrength, 0),
        RequiredStrength = ISNULL(b.BaseStrength, 0) + ISNULL(c.ChangeStrength, 0) + ISNULL(e.EventStrength, 0)
    FROM (SELECT BaseStrength = SUM(p.RequiredStrength)
          FROM crm.UnitPost AS p
          WHERE p.CompanyID = @CompanyID AND p.UnitID = @UnitID AND p.IsActive = 1 AND p.IsCancel = 0
            AND (@ShiftID IS NULL OR p.ShiftID = @ShiftID)
            AND (p.EffectiveFrom IS NULL OR p.EffectiveFrom <= @OnDate)
            AND (p.EffectiveTo   IS NULL OR p.EffectiveTo   >= @OnDate)) AS b
    CROSS JOIN
         (SELECT ChangeStrength = SUM(CASE WHEN dc.ChangeType = N'Increase' THEN dc.Nop ELSE -dc.Nop END)
          FROM ops.DeploymentChange AS dc
          WHERE dc.CompanyID = @CompanyID AND dc.UnitID = @UnitID
            AND dc.Status = N'Applied' AND dc.IsCancel = 0 AND dc.Dated <= @OnDate
            AND (@ShiftID IS NULL OR dc.ShiftID = @ShiftID)) AS c
    CROSS JOIN
         (SELECT EventStrength = SUM(te.NOP)
          FROM ops.TemporaryEvent AS te
          WHERE te.CompanyID = @CompanyID AND te.UnitID = @UnitID
            AND te.IsApproved = 1 AND te.IsCancel = 0
            AND te.StartDate <= @OnDate AND (te.EndDate IS NULL OR te.EndDate >= @OnDate)) AS e
);
GO

/*==============================================================================
  CODE GENERATORS - procedures, not functions.
  A function cannot take sp_getapplock and cannot write to a table, so gapless
  concurrent-safe numbering has to live in a procedure. See DECISIONS.md #14.
==============================================================================*/

CREATE OR ALTER PROCEDURE dbo.usp_Code_NextEmpCode
    @CompanyID  INT,
    @BranchID   INT           = NULL,
    @EmpCode    NVARCHAR(30)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @lock NVARCHAR(200) = CONCAT(N'empcode:', @CompanyID, N':', ISNULL(@BranchID, 0));
    DECLARE @rc INT;

    BEGIN TRY
        BEGIN TRAN;

        EXEC @rc = sp_getapplock @Resource = @lock, @LockMode = 'Exclusive',
                                 @LockOwner = 'Transaction', @LockTimeout = 5000;
        IF @rc < 0 THROW 51010, 'Could not acquire the employee-code lock. Try again.', 1;

        IF NOT EXISTS (SELECT 1 FROM mst.CodeCounter
                       WHERE CompanyID = @CompanyID AND CounterType = N'EMPCODE'
                         AND Scope = N'-' AND ISNULL(BranchID, 0) = ISNULL(@BranchID, 0))
        BEGIN
            INSERT INTO mst.CodeCounter (CompanyID, BranchID, CounterType, Scope, Prefix, PadLength, LastNumber)
            SELECT @CompanyID, @BranchID, N'EMPCODE', N'-',
                   ISNULL((SELECT TOP (1) LEFT(c.CompanyCode, 3) FROM org.Company c WHERE c.CompanyID = @CompanyID), N'EMP'),
                   5, 0;
        END

        UPDATE mst.CodeCounter
        SET LastNumber = LastNumber + 1,
            UpdateDate = SYSDATETIME(),
            @EmpCode   = Prefix + RIGHT(REPLICATE('0', PadLength) + CAST(LastNumber + 1 AS NVARCHAR(20)), PadLength)
        WHERE CompanyID = @CompanyID AND CounterType = N'EMPCODE'
          AND Scope = N'-' AND ISNULL(BranchID, 0) = ISNULL(@BranchID, 0);

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Code_NextInvoiceNo
    @CompanyID      INT,
    @FinancialYear  NVARCHAR(20),          -- e.g. '2026-27'
    @InvoiceNo      NVARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @lock NVARCHAR(200) = CONCAT(N'invoiceno:', @CompanyID, N':', @FinancialYear);
    DECLARE @rc INT;

    BEGIN TRY
        BEGIN TRAN;

        EXEC @rc = sp_getapplock @Resource = @lock, @LockMode = 'Exclusive',
                                 @LockOwner = 'Transaction', @LockTimeout = 5000;
        IF @rc < 0 THROW 51011, 'Could not acquire the invoice-number lock. Try again.', 1;

        IF NOT EXISTS (SELECT 1 FROM mst.CodeCounter
                       WHERE CompanyID = @CompanyID AND CounterType = N'INVOICE'
                         AND Scope = @FinancialYear AND BranchID IS NULL)
        BEGIN
            INSERT INTO mst.CodeCounter (CompanyID, BranchID, CounterType, Scope, Prefix, PadLength, LastNumber)
            SELECT @CompanyID, NULL, N'INVOICE', @FinancialYear,
                   ISNULL((SELECT TOP (1) LEFT(c.CompanyCode, 3) FROM org.Company c WHERE c.CompanyID = @CompanyID), N'INV')
                   + N'/' + @FinancialYear + N'/',
                   4, 0;
        END

        UPDATE mst.CodeCounter
        SET LastNumber = LastNumber + 1,
            UpdateDate = SYSDATETIME(),
            @InvoiceNo = Prefix + RIGHT(REPLICATE('0', PadLength) + CAST(LastNumber + 1 AS NVARCHAR(20)), PadLength)
        WHERE CompanyID = @CompanyID AND CounterType = N'INVOICE'
          AND Scope = @FinancialYear AND BranchID IS NULL;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

PRINT '300_functions.sql  ->  OK  (15 functions + 2 code-generator procedures)';
GO
