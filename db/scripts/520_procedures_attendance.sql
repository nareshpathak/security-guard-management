/*==============================================================================
  520_procedures_attendance.sql
  Attendance: punch, offline sync, approval, summary, register.
  Spec: docs/prd/01-database.md §7.2 ; docs/prd/02-api.md §4.2

  The spec lists one file, 520_procedures_operation.sql, for the whole of module
  M5-M16. That would be several thousand lines in a single file. It is split by
  domain instead: 520 attendance, 521 deployment, 522 patrol/location,
  523 people, 524 incident/complaint, 525 inventory/HR. See DECISIONS.md #21.

  RULES APPLIED THROUGHOUT
  ------------------------
  * @CompanyID and @UserID come from the JWT, never from the request body.
  * Every write is idempotent on @ClientRequestId so the mobile outbox can retry.
  * Distance, worked hours and status are computed server-side. A punch payload
    that carries them is ignored - the phone must not be trusted.
  * A month that belongs to a locked payroll run cannot be edited.
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*==============================================================================
  Helper: is the attendance month closed by a locked payroll run
==============================================================================*/
CREATE OR ALTER FUNCTION dbo.fnIsAttendanceMonthLocked (@CompanyID INT, @EmpID INT, @OnDate DATE)
RETURNS BIT
WITH SCHEMABINDING
AS
BEGIN
    RETURN CASE WHEN EXISTS (
        SELECT 1
        FROM fin.Salary   AS s
        INNER JOIN fin.SalaryRun AS r ON r.RunID = s.RunID
        WHERE s.CompanyID = @CompanyID
          AND s.EmpID     = @EmpID
          AND s.MonthYear = CONVERT(CHAR(7), @OnDate, 126)
          AND r.Status IN (N'Locked', N'Paid')
          AND s.IsCancel = 0
    ) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END;
END;
GO

/*==============================================================================
  PUNCH IN
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Attendance_InsertPunchIn
    @CompanyID       INT,
    @UserID          INT,
    @EmpID           INT,
    @UnitID          INT,
    @ShiftID         INT              = NULL,
    @PunchAt         DATETIME2(0)     = NULL,     -- client punch time; defaults to now
    @Latitude        DECIMAL(10,7)    = NULL,
    @Longitude       DECIMAL(10,7)    = NULL,
    @SelfieUrl       NVARCHAR(500)    = NULL,
    @IsMockLocation  BIT              = 0,
    @IsOffline       BIT              = 0,
    @ClientRequestId UNIQUEIDENTIFIER = NULL,
    @DeviceID        NVARCHAR(200)    = NULL,
    @AppVersion      NVARCHAR(20)     = NULL,
    @AllowOutOfGeofence BIT           = 0,        -- set only when a supervisor approves an exception
    @Remark          NVARCHAR(500)    = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @PunchAt IS NULL SET @PunchAt = SYSDATETIME();

    DECLARE @AttendanceDate DATE      = CAST(@PunchAt AS DATE),
            @AttendanceID   BIGINT,
            @Distance       INT,
            @Radius         INT,
            @BranchID       INT,
            @PostID         INT,
            @Existing       BIGINT;

    /* ---- idempotency: an outbox retry returns the original row ---- */
    IF @ClientRequestId IS NOT NULL
    BEGIN
        SELECT @Existing = AttendanceID FROM ops.Attendance WHERE ClientRequestId = @ClientRequestId;
        IF @Existing IS NOT NULL
        BEGIN
            SELECT Success = CAST(1 AS BIT), Status = 200, Id = CAST(@Existing AS INT),
                   Message = N'Already recorded';
            RETURN;
        END
    END

    /* ---- guard rails ---- */
    IF @IsMockLocation = 1
        THROW 51100, 'Mock location detected. Punch rejected.', 1;

    IF dbo.fnIsAttendanceMonthLocked(@CompanyID, @EmpID, @AttendanceDate) = 1
        THROW 51101, 'This month is closed by a locked payroll run.', 1;

    IF NOT EXISTS (SELECT 1 FROM hr.Employee
                   WHERE EmpID = @EmpID AND CompanyID = @CompanyID AND IsCancel = 0 AND EmpStatus = N'Active')
        THROW 51102, 'Employee is not active.', 1;

    SELECT @Radius = u.GeofenceRadiusMeters, @BranchID = u.BranchID
    FROM crm.Unit AS u WHERE u.UnitID = @UnitID AND u.CompanyID = @CompanyID AND u.IsCancel = 0;

    IF @Radius IS NULL
        THROW 51103, 'Unit not found for this company.', 1;

    /* ---- distance is computed here; whatever the phone sent is ignored ---- */
    SELECT @Distance = dbo.fnDistanceMeters(@Latitude, @Longitude, u.Latitude, u.Longitude)
    FROM crm.Unit AS u WHERE u.UnitID = @UnitID;

    IF @AllowOutOfGeofence = 0 AND @Distance IS NOT NULL AND @Distance > @Radius
        THROW 51104, 'You are outside the site geofence. Punch rejected.', 1;

    /* ---- default shift and current post from the active deployment ---- */
    SELECT TOP (1) @ShiftID = ISNULL(@ShiftID, d.ShiftID), @PostID = d.PostID
    FROM ops.Deployment AS d
    WHERE d.CompanyID = @CompanyID AND d.EmpID = @EmpID AND d.UnitID = @UnitID
      AND d.Status = N'Active' AND d.IsCancel = 0
    ORDER BY d.FromDate DESC;

    IF @ShiftID IS NULL SELECT @ShiftID = ShiftID FROM hr.Employee WHERE EmpID = @EmpID;

    BEGIN TRY
        BEGIN TRAN;

        IF EXISTS (SELECT 1 FROM ops.Attendance
                   WHERE CompanyID = @CompanyID AND EmpID = @EmpID
                     AND AttendanceDate = @AttendanceDate
                     AND ISNULL(ShiftID, 0) = ISNULL(@ShiftID, 0) AND IsCancel = 0)
            THROW 51105, 'Already punched in for this shift.', 1;

        INSERT INTO ops.Attendance
            (CompanyID, BranchID, UnitID, PostID, EmpID, ShiftID, AttendanceDate,
             InTime, InLatitude, InLongitude, InDistanceMeters, InSelfieUrl,
             Status, Source, ClientRequestId, IsOffline, ClientPunchAt, SyncedAt,
             IsMockLocation, ApprovalStatus, DeviceID, AppVersion, Remark,
             InsertDate, InsertUserID)
        VALUES
            (@CompanyID, @BranchID, @UnitID, @PostID, @EmpID, @ShiftID, @AttendanceDate,
             @PunchAt, @Latitude, @Longitude, @Distance, @SelfieUrl,
             'P ', 1, @ClientRequestId, @IsOffline, @PunchAt,
             CASE WHEN @IsOffline = 1 THEN SYSDATETIME() ELSE NULL END,
             @IsMockLocation, 0, @DeviceID, @AppVersion, @Remark,
             SYSDATETIME(), @UserID);

        SET @AttendanceID = SCOPE_IDENTITY();

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = CAST(@AttendanceID AS INT),
           Message = N'Punched in', DistanceMeters = @Distance, PunchAt = @PunchAt;
END;
GO

/*==============================================================================
  PUNCH OUT
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Attendance_InsertPunchOut
    @CompanyID       INT,
    @UserID          INT,
    @EmpID           INT,
    @UnitID          INT,
    @ShiftID         INT              = NULL,
    @PunchAt         DATETIME2(0)     = NULL,
    @Latitude        DECIMAL(10,7)    = NULL,
    @Longitude       DECIMAL(10,7)    = NULL,
    @SelfieUrl       NVARCHAR(500)    = NULL,
    @IsMockLocation  BIT              = 0,
    @IsOffline       BIT              = 0,
    @ClientRequestId UNIQUEIDENTIFIER = NULL,
    @DeviceID        NVARCHAR(200)    = NULL,
    @AppVersion      NVARCHAR(20)     = NULL,
    @AllowOutOfGeofence BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @PunchAt IS NULL SET @PunchAt = SYSDATETIME();

    DECLARE @AttendanceID BIGINT, @Distance INT, @Radius INT,
            @Worked DECIMAL(5,2), @Status CHAR(2), @InTime DATETIME2(0),
            @AttendanceDate DATE;

    IF @IsMockLocation = 1
        THROW 51100, 'Mock location detected. Punch rejected.', 1;

    /* the punch-out may belong to the previous calendar day on a night shift */
    SELECT TOP (1) @AttendanceID = a.AttendanceID, @InTime = a.InTime, @AttendanceDate = a.AttendanceDate
    FROM ops.Attendance AS a
    WHERE a.CompanyID = @CompanyID AND a.EmpID = @EmpID AND a.UnitID = @UnitID
      AND a.OutTime IS NULL AND a.IsCancel = 0
      AND a.AttendanceDate >= DATEADD(DAY, -1, CAST(@PunchAt AS DATE))
      AND (@ShiftID IS NULL OR a.ShiftID = @ShiftID)
    ORDER BY a.InTime DESC;

    IF @AttendanceID IS NULL
        THROW 51106, 'No open punch-in found to close.', 1;

    IF dbo.fnIsAttendanceMonthLocked(@CompanyID, @EmpID, @AttendanceDate) = 1
        THROW 51101, 'This month is closed by a locked payroll run.', 1;

    SELECT @Radius = u.GeofenceRadiusMeters,
           @Distance = dbo.fnDistanceMeters(@Latitude, @Longitude, u.Latitude, u.Longitude)
    FROM crm.Unit AS u WHERE u.UnitID = @UnitID;

    IF @AllowOutOfGeofence = 0 AND @Distance IS NOT NULL AND @Distance > @Radius
        THROW 51104, 'You are outside the site geofence. Punch rejected.', 1;

    SELECT @ShiftID = ISNULL(@ShiftID, ShiftID) FROM ops.Attendance WHERE AttendanceID = @AttendanceID;
    SET @Worked = dbo.fnCalcWorkedHours(@InTime, @PunchAt, @ShiftID);
    SET @Status = dbo.fnAttendanceStatus(@Worked, @ShiftID);

    BEGIN TRY
        BEGIN TRAN;

        UPDATE ops.Attendance
        SET OutTime           = @PunchAt,
            OutLatitude       = @Latitude,
            OutLongitude      = @Longitude,
            OutDistanceMeters = @Distance,
            OutSelfieUrl      = @SelfieUrl,
            WorkedHours       = @Worked,
            OtHours           = CASE WHEN @Worked > (SELECT ISNULL(FullDayHours, 8) FROM mst.Shift WHERE ShiftID = @ShiftID)
                                     THEN @Worked - (SELECT ISNULL(FullDayHours, 8) FROM mst.Shift WHERE ShiftID = @ShiftID)
                                     ELSE 0 END,
            Status            = @Status,
            IsOffline         = CASE WHEN @IsOffline = 1 THEN 1 ELSE IsOffline END,
            SyncedAt          = CASE WHEN @IsOffline = 1 THEN SYSDATETIME() ELSE SyncedAt END,
            UpdateDate        = SYSDATETIME(),
            UpdateUserID      = @UserID
        WHERE AttendanceID = @AttendanceID;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = CAST(@AttendanceID AS INT),
           Message = N'Punched out', WorkedHours = @Worked, AttendanceStatus = @Status,
           DistanceMeters = @Distance;
END;
GO

/*==============================================================================
  OFFLINE BATCH SYNC  (table-valued parameter, one round trip for N punches)
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Attendance_SyncBatch
    @CompanyID INT,
    @UserID    INT,
    @Punches   ops.AttendancePunchList READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Result TABLE (
        ClientRequestId UNIQUEIDENTIFIER PRIMARY KEY,
        AttendanceID    BIGINT NULL,
        Accepted        BIT    NOT NULL,
        Message         NVARCHAR(200) NOT NULL
    );

    /* rows already applied on a previous sync attempt */
    INSERT INTO @Result (ClientRequestId, AttendanceID, Accepted, Message)
    SELECT p.ClientRequestId, a.AttendanceID, 1, N'Already recorded'
    FROM @Punches AS p
    INNER JOIN ops.Attendance AS a ON a.ClientRequestId = p.ClientRequestId;

    /* mock-location rows are rejected but still consumed, so the phone stops retrying */
    INSERT INTO @Result (ClientRequestId, AttendanceID, Accepted, Message)
    SELECT p.ClientRequestId, NULL, 0, N'Mock location - rejected'
    FROM @Punches AS p
    WHERE p.IsMockLocation = 1
      AND NOT EXISTS (SELECT 1 FROM @Result AS r WHERE r.ClientRequestId = p.ClientRequestId);

    DECLARE @Id UNIQUEIDENTIFIER, @EmpID INT, @UnitID INT, @ShiftID INT,
            @PunchAt DATETIME2(0), @Lat DECIMAL(10,7), @Lon DECIMAL(10,7),
            @Dir CHAR(3), @Selfie NVARCHAR(500), @Device NVARCHAR(200), @App NVARCHAR(20);

    DECLARE punch_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT p.ClientRequestId, p.EmpID, p.UnitID, p.ShiftID, p.PunchAt,
               p.Latitude, p.Longitude, p.Direction, p.SelfieUrl, p.DeviceID, p.AppVersion
        FROM @Punches AS p
        WHERE NOT EXISTS (SELECT 1 FROM @Result AS r WHERE r.ClientRequestId = p.ClientRequestId)
        ORDER BY p.PunchAt;   -- chronological, so IN precedes its OUT

    OPEN punch_cur;
    FETCH NEXT FROM punch_cur INTO @Id, @EmpID, @UnitID, @ShiftID, @PunchAt, @Lat, @Lon, @Dir, @Selfie, @Device, @App;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            IF @Dir = 'IN '
                EXEC dbo.usp_Attendance_InsertPunchIn
                     @CompanyID = @CompanyID, @UserID = @UserID, @EmpID = @EmpID, @UnitID = @UnitID,
                     @ShiftID = @ShiftID, @PunchAt = @PunchAt, @Latitude = @Lat, @Longitude = @Lon,
                     @SelfieUrl = @Selfie, @IsOffline = 1, @ClientRequestId = @Id,
                     @DeviceID = @Device, @AppVersion = @App;
            ELSE
                EXEC dbo.usp_Attendance_InsertPunchOut
                     @CompanyID = @CompanyID, @UserID = @UserID, @EmpID = @EmpID, @UnitID = @UnitID,
                     @ShiftID = @ShiftID, @PunchAt = @PunchAt, @Latitude = @Lat, @Longitude = @Lon,
                     @SelfieUrl = @Selfie, @IsOffline = 1, @ClientRequestId = @Id,
                     @DeviceID = @Device, @AppVersion = @App;

            INSERT INTO @Result (ClientRequestId, AttendanceID, Accepted, Message)
            SELECT @Id, (SELECT TOP (1) AttendanceID FROM ops.Attendance WHERE ClientRequestId = @Id), 1, N'Accepted';
        END TRY
        BEGIN CATCH
            -- a rejected punch must not abort the rest of the batch
            INSERT INTO @Result (ClientRequestId, AttendanceID, Accepted, Message)
            VALUES (@Id, NULL, 0, LEFT(ERROR_MESSAGE(), 200));
        END CATCH

        FETCH NEXT FROM punch_cur INTO @Id, @EmpID, @UnitID, @ShiftID, @PunchAt, @Lat, @Lon, @Dir, @Selfie, @Device, @App;
    END

    CLOSE punch_cur;
    DEALLOCATE punch_cur;

    SELECT ClientRequestId, AttendanceID, Accepted, Message FROM @Result;
END;
GO

/*==============================================================================
  SUPERVISOR BULK MARKING
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Attendance_Insert
    @CompanyID      INT,
    @UserID         INT,
    @UnitID         INT,
    @AttendanceDate DATE,
    @ShiftID        INT,
    @EmpIdsCsv      NVARCHAR(MAX),
    @Status         CHAR(2) = 'P ',
    @Remark         NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @BranchID INT, @Inserted INT = 0, @Updated INT = 0;
    SELECT @BranchID = BranchID FROM crm.Unit WHERE UnitID = @UnitID AND CompanyID = @CompanyID;

    IF @BranchID IS NULL AND NOT EXISTS (SELECT 1 FROM crm.Unit WHERE UnitID = @UnitID AND CompanyID = @CompanyID)
        THROW 51103, 'Unit not found for this company.', 1;

    BEGIN TRY
        BEGIN TRAN;

        -- MERGE is avoided here: two supervisors marking the same unit at the
        -- same moment can hit its known concurrency defects against a unique
        -- index. Explicit UPDATE-then-INSERT with HOLDLOCK is safe.
        UPDATE a
        SET a.Status = @Status, a.Remark = @Remark,
            a.UpdateDate = SYSDATETIME(), a.UpdateUserID = @UserID
        FROM ops.Attendance AS a WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.fnSplitIds(@EmpIdsCsv) AS ids ON ids.ID = a.EmpID
        WHERE a.CompanyID = @CompanyID
          AND a.AttendanceDate = @AttendanceDate
          AND ISNULL(a.ShiftID, 0) = ISNULL(@ShiftID, 0)
          AND a.IsCancel = 0
          AND dbo.fnIsAttendanceMonthLocked(@CompanyID, a.EmpID, @AttendanceDate) = 0;

        SET @Updated = @@ROWCOUNT;

        INSERT INTO ops.Attendance
            (CompanyID, BranchID, UnitID, EmpID, ShiftID, AttendanceDate,
             Status, Source, ApprovalStatus, Remark, InsertDate, InsertUserID)
        SELECT @CompanyID, @BranchID, @UnitID, ids.ID, @ShiftID, @AttendanceDate,
               @Status, 2, 0, @Remark, SYSDATETIME(), @UserID
        FROM dbo.fnSplitIds(@EmpIdsCsv) AS ids
        WHERE NOT EXISTS (SELECT 1 FROM ops.Attendance AS a WITH (UPDLOCK, HOLDLOCK)
                          WHERE a.CompanyID = @CompanyID AND a.EmpID = ids.ID
                            AND a.AttendanceDate = @AttendanceDate
                            AND ISNULL(a.ShiftID, 0) = ISNULL(@ShiftID, 0)
                            AND a.IsCancel = 0)
          AND dbo.fnIsAttendanceMonthLocked(@CompanyID, ids.ID, @AttendanceDate) = 0;

        SET @Inserted = @@ROWCOUNT;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @Inserted + @Updated,
           Message = CONCAT(@Inserted, N' inserted, ', @Updated, N' updated');
END;
GO

/*==============================================================================
  APPROVAL QUEUE
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Attendance_GetForApproval
    @CompanyID INT,
    @UserID    INT,
    @UnitID    INT  = NULL,
    @FromDate  DATE = NULL,
    @ToDate    DATE = NULL,
    @PageNo    INT  = 1,
    @PageSize  INT  = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;
    IF @FromDate IS NULL SET @FromDate = DATEADD(DAY, -7, CAST(SYSDATETIME() AS DATE));
    IF @ToDate   IS NULL SET @ToDate   = CAST(SYSDATETIME() AS DATE);

    SELECT
        a.AttendanceID, a.AttendanceDate, a.EmpID, e.EmpCode, e.EmpFullName, e.Photo,
        d.DesignationName, a.UnitID, u.UnitName, a.ShiftID, s.ShiftName,
        a.InTime, a.OutTime, a.WorkedHours, a.OtHours, a.Status,
        a.InDistanceMeters, a.OutDistanceMeters, a.InSelfieUrl, a.OutSelfieUrl,
        a.IsMockLocation, a.IsOffline, a.Source,
        OutsideGeofence = CASE WHEN a.InDistanceMeters > u.GeofenceRadiusMeters THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END,
        MissingOutPunch = CASE WHEN a.OutTime IS NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END
    FROM ops.Attendance AS a
    INNER JOIN hr.Employee AS e ON e.EmpID  = a.EmpID
    INNER JOIN crm.Unit    AS u ON u.UnitID = a.UnitID
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = a.UnitID
    LEFT  JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    LEFT  JOIN mst.Shift   AS s ON s.ShiftID = a.ShiftID
    WHERE a.CompanyID = @CompanyID
      AND a.ApprovalStatus = 0
      AND a.IsCancel = 0
      AND a.AttendanceDate BETWEEN @FromDate AND @ToDate
      AND (@UnitID IS NULL OR a.UnitID = @UnitID)
    ORDER BY a.AttendanceDate DESC, u.UnitName, e.EmpFullName
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM ops.Attendance AS a
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = a.UnitID
    WHERE a.CompanyID = @CompanyID AND a.ApprovalStatus = 0 AND a.IsCancel = 0
      AND a.AttendanceDate BETWEEN @FromDate AND @ToDate
      AND (@UnitID IS NULL OR a.UnitID = @UnitID);
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Attendance_Approve
    @CompanyID        INT,
    @UserID           INT,
    @AttendanceIdsCsv NVARCHAR(MAX),
    @Approve          BIT,
    @RejectReason     NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Approve = 0 AND (@RejectReason IS NULL OR LTRIM(RTRIM(@RejectReason)) = N'')
        THROW 51107, 'A reason is required when rejecting attendance.', 1;

    DECLARE @Affected INT = 0;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE a
        SET a.ApprovalStatus = CASE WHEN @Approve = 1 THEN 1 ELSE 2 END,
            a.ApprovedBy     = @UserID,
            a.ApprovedOn     = SYSDATETIME(),
            a.RejectReason   = CASE WHEN @Approve = 0 THEN @RejectReason ELSE NULL END,
            a.UpdateDate     = SYSDATETIME(),
            a.UpdateUserID   = @UserID
        FROM ops.Attendance AS a
        INNER JOIN dbo.fnSplitIds(@AttendanceIdsCsv) AS ids ON ids.ID = a.AttendanceID
        INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = a.UnitID
        WHERE a.CompanyID = @CompanyID
          AND a.IsCancel = 0
          AND a.ApprovalStatus = 0
          AND dbo.fnIsAttendanceMonthLocked(@CompanyID, a.EmpID, a.AttendanceDate) = 0;

        SET @Affected = @@ROWCOUNT;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @Affected,
           Message = CONCAT(@Affected, CASE WHEN @Approve = 1 THEN N' approved' ELSE N' rejected' END);
END;
GO

/*==============================================================================
  READS
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Attendance_Get
    @CompanyID INT,
    @UserID    INT,
    @UnitID    INT  = NULL,
    @EmpID     INT  = NULL,
    @FromDate  DATE = NULL,
    @ToDate    DATE = NULL,
    @PageNo    INT  = 1,
    @PageSize  INT  = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;
    IF @FromDate IS NULL SET @FromDate = DATEFROMPARTS(YEAR(SYSDATETIME()), MONTH(SYSDATETIME()), 1);
    IF @ToDate   IS NULL SET @ToDate   = CAST(SYSDATETIME() AS DATE);

    SELECT
        r.AttendanceID, r.AttendanceDate, r.EmpID, r.EmpCode, r.EmpFullName,
        r.DesignationName, r.UnitID, r.UnitName, r.ShiftID, r.ShiftName,
        r.InTime, r.OutTime, r.WorkedHours, r.OtHours, r.Status, r.ApprovalStatus,
        r.InDistanceMeters, r.OutDistanceMeters, r.InSelfieUrl, r.OutSelfieUrl,
        r.OutsideGeofence, r.IsMockLocation, r.IsOffline
    FROM dbo.vwAttendanceRegister AS r
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = r.UnitID
    WHERE r.CompanyID = @CompanyID
      AND r.AttendanceDate BETWEEN @FromDate AND @ToDate
      AND (@UnitID IS NULL OR r.UnitID = @UnitID)
      AND (@EmpID  IS NULL OR r.EmpID  = @EmpID)
    ORDER BY r.AttendanceDate DESC, r.EmpFullName
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM ops.Attendance AS a
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = a.UnitID
    WHERE a.CompanyID = @CompanyID AND a.IsCancel = 0
      AND a.AttendanceDate BETWEEN @FromDate AND @ToDate
      AND (@UnitID IS NULL OR a.UnitID = @UnitID)
      AND (@EmpID  IS NULL OR a.EmpID  = @EmpID);
END;
GO

/*  the guard's own attendance - no unit scoping needed, it is his own data  */
CREATE OR ALTER PROCEDURE dbo.usp_Attendance_GetSelf
    @CompanyID INT,
    @UserID    INT,
    @EmpID     INT,
    @MonthYear CHAR(7) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @MonthYear IS NULL SET @MonthYear = CONVERT(CHAR(7), SYSDATETIME(), 126);

    SELECT
        a.AttendanceID, a.AttendanceDate, a.InTime, a.OutTime, a.WorkedHours, a.OtHours,
        a.Status, a.ApprovalStatus, a.InSelfieUrl, a.OutSelfieUrl,
        a.InDistanceMeters, a.OutDistanceMeters, a.IsOffline,
        u.UnitName, s.ShiftName
    FROM ops.Attendance AS a
    LEFT JOIN crm.Unit  AS u ON u.UnitID  = a.UnitID
    LEFT JOIN mst.Shift AS s ON s.ShiftID = a.ShiftID
    WHERE a.CompanyID = @CompanyID
      AND a.EmpID     = @EmpID
      AND a.IsCancel  = 0
      AND CONVERT(CHAR(7), a.AttendanceDate, 126) = @MonthYear
    ORDER BY a.AttendanceDate;

    SELECT
        PresentDays = SUM(CASE WHEN a.Status = 'P ' THEN 1.0 WHEN a.Status = 'DS' THEN 2.0 ELSE 0 END),
        HalfDays    = SUM(CASE WHEN a.Status = 'HD' THEN 1 ELSE 0 END),
        AbsentDays  = SUM(CASE WHEN a.Status = 'A ' THEN 1 ELSE 0 END),
        LeaveDays   = SUM(CASE WHEN a.Status = 'LV' THEN 1 ELSE 0 END),
        OtHours     = SUM(ISNULL(a.OtHours, 0))
    FROM ops.Attendance AS a
    WHERE a.CompanyID = @CompanyID AND a.EmpID = @EmpID AND a.IsCancel = 0
      AND CONVERT(CHAR(7), a.AttendanceDate, 126) = @MonthYear;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Attendance_GetSummary
    @CompanyID INT,
    @UserID    INT,
    @MonthYear CHAR(7),
    @UnitID    INT = NULL,
    @BranchID  INT = NULL,
    @PageNo    INT = 1,
    @PageSize  INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;

    ;WITH agg AS (
        SELECT
            a.EmpID, a.UnitID,
            PresentDays = SUM(CASE WHEN a.Status = 'P ' THEN 1.0 WHEN a.Status = 'DS' THEN 2.0 ELSE 0 END),
            HalfDays    = SUM(CASE WHEN a.Status = 'HD' THEN 1.0 ELSE 0 END),
            AbsentDays  = SUM(CASE WHEN a.Status = 'A ' THEN 1.0 ELSE 0 END),
            WeekOff     = SUM(CASE WHEN a.Status = 'WO' THEN 1.0 ELSE 0 END),
            Holidays    = SUM(CASE WHEN a.Status = 'HO' THEN 1.0 ELSE 0 END),
            LeaveDays   = SUM(CASE WHEN a.Status = 'LV' THEN 1.0 ELSE 0 END),
            OtHours     = SUM(ISNULL(a.OtHours, 0)),
            PendingApproval = SUM(CASE WHEN a.ApprovalStatus = 0 THEN 1 ELSE 0 END)
        FROM ops.Attendance AS a
        INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = a.UnitID
        WHERE a.CompanyID = @CompanyID AND a.IsCancel = 0
          AND CONVERT(CHAR(7), a.AttendanceDate, 126) = @MonthYear
          AND (@UnitID IS NULL OR a.UnitID = @UnitID)
        GROUP BY a.EmpID, a.UnitID
    )
    SELECT
        g.EmpID, e.EmpCode, e.EmpFullName, d.DesignationName, u.UnitName,
        g.PresentDays, g.HalfDays, g.AbsentDays, g.WeekOff, g.Holidays, g.LeaveDays,
        g.OtHours, g.PendingApproval,
        PayableDays = dbo.fnPayableDays(@CompanyID, g.EmpID, @MonthYear)
    FROM agg AS g
    INNER JOIN hr.Employee AS e ON e.EmpID  = g.EmpID
    LEFT  JOIN crm.Unit    AS u ON u.UnitID = g.UnitID
    LEFT  JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    WHERE (@BranchID IS NULL OR e.BranchID = @BranchID)
    ORDER BY u.UnitName, e.EmpFullName
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(DISTINCT a.EmpID)
    FROM ops.Attendance AS a
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = a.UnitID
    WHERE a.CompanyID = @CompanyID AND a.IsCancel = 0
      AND CONVERT(CHAR(7), a.AttendanceDate, 126) = @MonthYear
      AND (@UnitID IS NULL OR a.UnitID = @UnitID);
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Attendance_GetCount
    @CompanyID INT,
    @UserID    INT,
    @EmpID     INT = NULL,
    @OnDate    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @OnDate IS NULL SET @OnDate = CAST(SYSDATETIME() AS DATE);

    SELECT
        AttendanceCount = COUNT(*),
        PresentCount    = SUM(CASE WHEN a.Status IN ('P ','DS') THEN 1 ELSE 0 END),
        AbsentCount     = SUM(CASE WHEN a.Status = 'A ' THEN 1 ELSE 0 END),
        PendingCount    = SUM(CASE WHEN a.ApprovalStatus = 0 THEN 1 ELSE 0 END)
    FROM ops.Attendance AS a
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = a.UnitID
    WHERE a.CompanyID = @CompanyID AND a.IsCancel = 0
      AND a.AttendanceDate = @OnDate
      AND (@EmpID IS NULL OR a.EmpID = @EmpID);
END;
GO

/*  daily register - replaces the legacy PrintDailAttendance.aspx page  */
CREATE OR ALTER PROCEDURE dbo.usp_Attendance_GetRegister
    @CompanyID INT,
    @UserID    INT,
    @UnitID    INT,
    @MonthYear CHAR(7)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @From DATE = CAST(@MonthYear + '-01' AS DATE);
    DECLARE @To   DATE = EOMONTH(@From);

    IF NOT EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) WHERE UnitID = @UnitID)
        THROW 51108, 'You do not have access to this unit.', 1;

    /* 1. header */
    SELECT u.UnitID, u.UnitName, u.Address, c.ClientName, MonthYear = @MonthYear,
           FromDate = @From, ToDate = @To, co.CompanyName, co.LogoUrl
    FROM crm.Unit AS u
    INNER JOIN crm.Client  AS c  ON c.ClientID  = u.ClientID
    INNER JOIN org.Company AS co ON co.CompanyID = u.CompanyID
    WHERE u.UnitID = @UnitID;

    /* 2. one row per employee per day - the caller pivots into the day grid */
    SELECT
        e.EmpID, e.EmpCode, e.EmpFullName, d.DesignationName,
        dr.[Date] AS AttendanceDate,
        DayNo  = DATEPART(DAY, dr.[Date]),
        Status = ISNULL(a.Status, '  '),
        a.InTime, a.OutTime, a.WorkedHours, a.OtHours, a.ApprovalStatus
    FROM (SELECT DISTINCT EmpID FROM ops.Attendance
          WHERE CompanyID = @CompanyID AND UnitID = @UnitID
            AND AttendanceDate BETWEEN @From AND @To AND IsCancel = 0) AS emps
    INNER JOIN hr.Employee AS e ON e.EmpID = emps.EmpID
    LEFT  JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    CROSS JOIN dbo.fnDateRange(@From, @To) AS dr
    LEFT  JOIN ops.Attendance AS a
           ON a.EmpID = e.EmpID AND a.UnitID = @UnitID
          AND a.AttendanceDate = dr.[Date] AND a.IsCancel = 0
    ORDER BY e.EmpFullName, dr.[Date];

    /* 3. per-employee totals */
    SELECT
        a.EmpID,
        PresentDays = SUM(CASE WHEN a.Status = 'P ' THEN 1.0 WHEN a.Status = 'DS' THEN 2.0 ELSE 0 END),
        HalfDays    = SUM(CASE WHEN a.Status = 'HD' THEN 1.0 ELSE 0 END),
        AbsentDays  = SUM(CASE WHEN a.Status = 'A ' THEN 1.0 ELSE 0 END),
        LeaveDays   = SUM(CASE WHEN a.Status = 'LV' THEN 1.0 ELSE 0 END),
        OtHours     = SUM(ISNULL(a.OtHours, 0))
    FROM ops.Attendance AS a
    WHERE a.CompanyID = @CompanyID AND a.UnitID = @UnitID
      AND a.AttendanceDate BETWEEN @From AND @To AND a.IsCancel = 0
    GROUP BY a.EmpID;
END;
GO

/*==============================================================================
  BACKGROUND JOB: mark absent when no punch arrived after shift end + grace
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Attendance_MarkAbsentForNoPunch
    @CompanyID INT  = NULL,          -- NULL = all tenants (Hangfire runs it globally)
    @OnDate    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @OnDate IS NULL SET @OnDate = CAST(SYSDATETIME() AS DATE);

    DECLARE @Inserted INT = 0;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO ops.Attendance
            (CompanyID, BranchID, UnitID, PostID, EmpID, ShiftID, AttendanceDate,
             Status, Source, ApprovalStatus, Remark, InsertDate, InsertUserID)
        SELECT
            d.CompanyID, d.BranchID, d.UnitID, d.PostID, d.EmpID, d.ShiftID, @OnDate,
            'A ', 2, 0, N'Auto-marked absent: no punch received', SYSDATETIME(), NULL
        FROM ops.Deployment AS d
        INNER JOIN mst.Shift AS s ON s.ShiftID = d.ShiftID
        WHERE d.Status = N'Active' AND d.IsCancel = 0
          AND (@CompanyID IS NULL OR d.CompanyID = @CompanyID)
          AND d.FromDate <= @OnDate
          AND (d.ToDate IS NULL OR d.ToDate >= @OnDate)
          -- shift has ended plus its grace period.
          -- A night shift ends on the following calendar day.
          AND DATEADD(MINUTE, s.GraceOutMinutes,
                DATEADD(MINUTE, DATEDIFF(MINUTE, CAST('00:00:00' AS TIME), s.EndTime),
                    CAST(DATEADD(DAY, CASE WHEN s.IsNight = 1 THEN 1 ELSE 0 END, @OnDate) AS DATETIME2(0))
                )) < SYSDATETIME()
          AND NOT EXISTS (SELECT 1 FROM ops.Attendance AS a
                          WHERE a.CompanyID = d.CompanyID AND a.EmpID = d.EmpID
                            AND a.AttendanceDate = @OnDate
                            AND ISNULL(a.ShiftID, 0) = ISNULL(d.ShiftID, 0)
                            AND a.IsCancel = 0)
          AND dbo.fnIsAttendanceMonthLocked(d.CompanyID, d.EmpID, @OnDate) = 0;

        SET @Inserted = @@ROWCOUNT;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @Inserted,
           Message = CONCAT(@Inserted, N' employees auto-marked absent');
END;
GO

/*==============================================================================
  BACKGROUND JOB: refresh the monthly rollup
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Attendance_RefreshSummary
    @CompanyID INT     = NULL,
    @MonthYear CHAR(7) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @MonthYear IS NULL SET @MonthYear = CONVERT(CHAR(7), SYSDATETIME(), 126);

    BEGIN TRY
        BEGIN TRAN;

        ;WITH agg AS (
            SELECT
                a.CompanyID, a.BranchID, a.UnitID, a.EmpID,
                PresentDays = SUM(CASE WHEN a.Status = 'P ' THEN 1.0 WHEN a.Status = 'DS' THEN 2.0 ELSE 0 END),
                AbsentDays  = SUM(CASE WHEN a.Status = 'A ' THEN 1.0 ELSE 0 END),
                HalfDays    = SUM(CASE WHEN a.Status = 'HD' THEN 1.0 ELSE 0 END),
                WeekOff     = SUM(CASE WHEN a.Status = 'WO' THEN 1.0 ELSE 0 END),
                Holidays    = SUM(CASE WHEN a.Status = 'HO' THEN 1.0 ELSE 0 END),
                LeaveDays   = SUM(CASE WHEN a.Status = 'LV' THEN 1.0 ELSE 0 END),
                OtHours     = SUM(ISNULL(a.OtHours, 0)),
                DoubleShifts = SUM(CASE WHEN a.Status = 'DS' THEN 1 ELSE 0 END)
            FROM ops.Attendance AS a
            WHERE a.IsCancel = 0
              AND CONVERT(CHAR(7), a.AttendanceDate, 126) = @MonthYear
              AND (@CompanyID IS NULL OR a.CompanyID = @CompanyID)
            GROUP BY a.CompanyID, a.BranchID, a.UnitID, a.EmpID
        )
        MERGE ops.AttendanceSummary AS tgt
        USING agg AS src
           ON tgt.CompanyID = src.CompanyID AND tgt.EmpID = src.EmpID AND tgt.MonthYear = @MonthYear
        WHEN MATCHED THEN UPDATE SET
            BranchID = src.BranchID, UnitID = src.UnitID,
            PresentDays = src.PresentDays, AbsentDays = src.AbsentDays, HalfDays = src.HalfDays,
            WeekOff = src.WeekOff, Holidays = src.Holidays, LeaveDays = src.LeaveDays,
            OtHours = src.OtHours, DoubleShifts = src.DoubleShifts,
            PayableDays = dbo.fnPayableDays(src.CompanyID, src.EmpID, @MonthYear),
            RefreshedAt = SYSDATETIME(), UpdateDate = SYSDATETIME()
        WHEN NOT MATCHED BY TARGET THEN INSERT
            (CompanyID, BranchID, UnitID, EmpID, MonthYear, PresentDays, AbsentDays, HalfDays,
             WeekOff, Holidays, LeaveDays, OtHours, DoubleShifts, PayableDays, RefreshedAt)
            VALUES
            (src.CompanyID, src.BranchID, src.UnitID, src.EmpID, @MonthYear, src.PresentDays,
             src.AbsentDays, src.HalfDays, src.WeekOff, src.Holidays, src.LeaveDays,
             src.OtHours, src.DoubleShifts,
             dbo.fnPayableDays(src.CompanyID, src.EmpID, @MonthYear), SYSDATETIME());

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = 0, Message = N'Summary refreshed';
END;
GO

PRINT '520_procedures_attendance.sql  ->  OK  (13 procedures + 1 function)';
GO
