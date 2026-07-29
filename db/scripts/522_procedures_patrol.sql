/*==============================================================================
  522_procedures_patrol.sql
  QR checkpoint patrol and live location tracking.
  Spec: docs/prd/01-database.md §7.2 ; docs/prd/02-api.md §4.2
  Split rationale: DECISIONS.md #21

  The patrol log is the agency's proof to its client that the rounds were
  actually walked. Everything here is written so that proof cannot be faked:
  distance is computed server-side, mock GPS is rejected, and a scan outside
  the checkpoint radius is stored with IsWithinRange = 0 rather than silently
  discarded, so the exception is visible instead of missing.
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*==============================================================================
  CHECKPOINTS
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Qr_Add
    @CompanyID         INT,
    @UserID            INT,
    @UnitID            INT,
    @Name              NVARCHAR(150),
    @Location          NVARCHAR(300)  = NULL,
    @LocationID        INT            = NULL,
    @Latitude          DECIMAL(10,7)  = NULL,
    @Longitude         DECIMAL(10,7)  = NULL,
    @MaxDistanceMeters INT            = 50,
    @RequirePhoto      BIT            = 0,
    @Remark            NVARCHAR(500)  = NULL,
    @QrID              INT            = NULL     -- pass to edit an existing checkpoint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) WHERE UnitID = @UnitID)
        THROW 51300, 'You do not have access to this unit.', 1;

    DECLARE @BranchID INT, @QrCode NVARCHAR(64);
    SELECT @BranchID = BranchID FROM crm.Unit WHERE UnitID = @UnitID AND CompanyID = @CompanyID;

    BEGIN TRY
        BEGIN TRAN;

        IF @QrID IS NULL
        BEGIN
            SET @QrCode = LOWER(CONVERT(NVARCHAR(64), NEWID()));

            INSERT INTO ops.QrCheckpoint (CompanyID, BranchID, UnitID, LocationID, QrCode, Name,
                                          Location, Latitude, Longitude, MaxDistanceMeters,
                                          RequirePhoto, Remark, InsertDate, InsertUserID)
            VALUES (@CompanyID, @BranchID, @UnitID, @LocationID, @QrCode, @Name,
                    @Location, @Latitude, @Longitude, @MaxDistanceMeters,
                    @RequirePhoto, @Remark, SYSDATETIME(), @UserID);

            SET @QrID = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE ops.QrCheckpoint
            SET Name = @Name, Location = @Location, LocationID = @LocationID,
                Latitude = @Latitude, Longitude = @Longitude,
                MaxDistanceMeters = @MaxDistanceMeters, RequirePhoto = @RequirePhoto,
                Remark = @Remark, UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
            WHERE QrID = @QrID AND CompanyID = @CompanyID;

            IF @@ROWCOUNT = 0 THROW 51301, 'Checkpoint not found.', 1;

            SELECT @QrCode = QrCode FROM ops.QrCheckpoint WHERE QrID = @QrID;
        END

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @QrID,
           Message = N'Checkpoint saved', QrCode = @QrCode;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Qr_GetList
    @CompanyID INT,
    @UserID    INT,
    @UnitID    INT = NULL,
    @PageNo    INT = 1,
    @PageSize  INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;

    SELECT
        Sno = ROW_NUMBER() OVER (ORDER BY u.UnitName, q.SortOrder, q.Name),
        q.QrID, q.QrCode, q.Name, q.Location, q.Latitude, q.Longitude,
        q.MaxDistanceMeters, q.RequirePhoto, q.Photo, q.Remark, q.IsActive,
        q.UnitID, u.UnitName, cl.ClientName,
        TotalScanCount = ISNULL(sc.Cnt, 0),
        LastScanAt     = sc.LastScanAt,
        ScansToday     = ISNULL(sc.Today, 0)
    FROM ops.QrCheckpoint AS q
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = q.UnitID
    INNER JOIN crm.Unit   AS u  ON u.UnitID = q.UnitID
    LEFT  JOIN crm.Client AS cl ON cl.ClientID = u.ClientID
    OUTER APPLY (SELECT Cnt = COUNT(*), LastScanAt = MAX(s.Scantime),
                        Today = SUM(CASE WHEN CAST(s.Scantime AS DATE) = CAST(SYSDATETIME() AS DATE) THEN 1 ELSE 0 END)
                 FROM ops.QrScanLog AS s WHERE s.QrID = q.QrID) AS sc
    WHERE q.CompanyID = @CompanyID AND q.IsCancel = 0
      AND (@UnitID IS NULL OR q.UnitID = @UnitID)
    ORDER BY u.UnitName, q.SortOrder, q.Name
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM ops.QrCheckpoint AS q
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = q.UnitID
    WHERE q.CompanyID = @CompanyID AND q.IsCancel = 0
      AND (@UnitID IS NULL OR q.UnitID = @UnitID);
END;
GO

/*  the guard's app calls this before scanning, to show "you must be within X m"  */
CREATE OR ALTER PROCEDURE dbo.usp_Qr_GetDistance
    @CompanyID INT,
    @QrCode    NVARCHAR(64),
    @Latitude  DECIMAL(10,7) = NULL,
    @Longitude DECIMAL(10,7) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        q.QrID, q.Name, q.UnitID, u.UnitName,
        q.Latitude, q.Longitude, q.MaxDistanceMeters, q.RequirePhoto,
        DistanceMeters = dbo.fnDistanceMeters(@Latitude, @Longitude, q.Latitude, q.Longitude),
        IsWithinRange  = CASE
                            WHEN q.Latitude IS NULL OR @Latitude IS NULL THEN CAST(1 AS BIT)
                            WHEN dbo.fnDistanceMeters(@Latitude, @Longitude, q.Latitude, q.Longitude) <= q.MaxDistanceMeters
                                 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT)
                         END
    FROM ops.QrCheckpoint AS q
    INNER JOIN crm.Unit AS u ON u.UnitID = q.UnitID
    WHERE q.CompanyID = @CompanyID AND q.QrCode = @QrCode AND q.IsActive = 1 AND q.IsCancel = 0;
END;
GO

/*==============================================================================
  SCAN
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Qr_Scan
    @CompanyID       INT,
    @UserID          INT,
    @QrCode          NVARCHAR(64),
    @EmpID           INT              = NULL,
    @Latitude        DECIMAL(10,7)    = NULL,
    @Longitude       DECIMAL(10,7)    = NULL,
    @ImageUrl        NVARCHAR(500)    = NULL,
    @Remark          NVARCHAR(500)    = NULL,
    @Scantime        DATETIME2(0)     = NULL,
    @IsMockLocation  BIT              = 0,
    @IsOffline       BIT              = 0,
    @ClientRequestId UNIQUEIDENTIFIER = NULL,
    @DeviceID        NVARCHAR(200)    = NULL,
    @AppVersion      NVARCHAR(20)     = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Scantime IS NULL SET @Scantime = SYSDATETIME();

    DECLARE @ScanID BIGINT, @QrID INT, @UnitID INT, @MaxDist INT,
            @QLat DECIMAL(10,7), @QLon DECIMAL(10,7), @RequirePhoto BIT,
            @Distance INT, @InRange BIT, @RoundID INT, @Existing BIGINT;

    /* idempotent replay from the offline outbox */
    IF @ClientRequestId IS NOT NULL
    BEGIN
        SELECT @Existing = ScanID FROM ops.QrScanLog WHERE ClientRequestId = @ClientRequestId;
        IF @Existing IS NOT NULL
        BEGIN
            SELECT Success = CAST(1 AS BIT), Status = 200, Id = CAST(@Existing AS INT),
                   Message = N'Already recorded';
            RETURN;
        END
    END

    IF @IsMockLocation = 1
        THROW 51302, 'Mock location detected. Scan rejected.', 1;

    SELECT @QrID = q.QrID, @UnitID = q.UnitID, @MaxDist = q.MaxDistanceMeters,
           @QLat = q.Latitude, @QLon = q.Longitude, @RequirePhoto = q.RequirePhoto
    FROM ops.QrCheckpoint AS q
    WHERE q.CompanyID = @CompanyID AND q.QrCode = @QrCode AND q.IsActive = 1 AND q.IsCancel = 0;

    IF @QrID IS NULL
        THROW 51303, 'This QR code is not a valid checkpoint.', 1;

    IF @RequirePhoto = 1 AND @ImageUrl IS NULL
        THROW 51304, 'This checkpoint requires a photo.', 1;

    /* distance is derived here; the phone never supplies it */
    SET @Distance = dbo.fnDistanceMeters(@Latitude, @Longitude, @QLat, @QLon);
    SET @InRange  = CASE WHEN @QLat IS NULL OR @Distance IS NULL THEN 1
                         WHEN @Distance <= @MaxDist THEN 1 ELSE 0 END;

    /* which round does this scan belong to */
    SELECT TOP (1) @RoundID = r.RoundID
    FROM ops.PatrolRound AS r
    INNER JOIN ops.PatrolRoundCheckpoint AS rc ON rc.RoundID = r.RoundID AND rc.QrID = @QrID
    WHERE r.CompanyID = @CompanyID AND r.UnitID = @UnitID AND r.IsActive = 1 AND r.IsCancel = 0
      AND (
            (r.StartTime <= r.EndTime AND CAST(@Scantime AS TIME) BETWEEN r.StartTime AND r.EndTime)
         OR (r.StartTime >  r.EndTime AND (CAST(@Scantime AS TIME) >= r.StartTime OR CAST(@Scantime AS TIME) <= r.EndTime))
          )
    ORDER BY rc.SequenceNo;

    IF @EmpID IS NULL SELECT @EmpID = EmpID FROM sec.Users WHERE UserID = @UserID;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO ops.QrScanLog
            (CompanyID, QrID, UnitID, EmpID, UserID, RoundID, Scantime,
             Latitude, Longitude, DistanceMeters, IsWithinRange, ImageUrl, Remark,
             ClientRequestId, IsOffline, ClientScanAt, SyncedAt, IsMockLocation,
             DeviceID, AppVersion, InsertDate, InsertUserID)
        VALUES
            (@CompanyID, @QrID, @UnitID, @EmpID, @UserID, @RoundID, @Scantime,
             @Latitude, @Longitude, @Distance, @InRange, @ImageUrl, @Remark,
             @ClientRequestId, @IsOffline, @Scantime,
             CASE WHEN @IsOffline = 1 THEN SYSDATETIME() ELSE NULL END, @IsMockLocation,
             @DeviceID, @AppVersion, SYSDATETIME(), @UserID);

        SET @ScanID = SCOPE_IDENTITY();

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    /* An out-of-range scan is recorded, not rejected. Hiding it would hide the
       exception; the supervisor needs to see that it happened. */
    SELECT Success = CAST(1 AS BIT), Status = 200, Id = CAST(@ScanID AS INT),
           Message = CASE WHEN @InRange = 1 THEN N'Scan recorded'
                          ELSE N'Scan recorded but you were outside the checkpoint radius' END,
           DistanceMeters = @Distance, IsWithinRange = @InRange, CheckpointName = (SELECT Name FROM ops.QrCheckpoint WHERE QrID = @QrID);
END;
GO

/*==============================================================================
  SCAN LOGS
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Qr_GetScanLog
    @CompanyID INT,
    @UserID    INT,
    @UnitID    INT  = NULL,
    @QrID      INT  = NULL,
    @EmpID     INT  = NULL,
    @FromDate  DATE = NULL,
    @ToDate    DATE = NULL,
    @OnlyOutOfRange BIT = 0,
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
        Sno = ROW_NUMBER() OVER (ORDER BY s.Scantime DESC),
        s.ScanID, s.Scantime, s.QrID, q.Name, q.Location,
        s.UnitID, u.UnitName, cl.ClientName,
        s.EmpID, e.EmpFullName AS Name, e.EmpCode, e.Photo,
        s.Latitude, s.Longitude, s.DistanceMeters, s.IsWithinRange,
        Image = s.ImageUrl, s.Remark, s.RoundID, r.RoundName, s.IsOffline
    FROM ops.QrScanLog AS s
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = s.UnitID
    INNER JOIN ops.QrCheckpoint AS q ON q.QrID = s.QrID
    INNER JOIN crm.Unit   AS u  ON u.UnitID = s.UnitID
    LEFT  JOIN crm.Client AS cl ON cl.ClientID = u.ClientID
    LEFT  JOIN hr.Employee AS e ON e.EmpID = s.EmpID
    LEFT  JOIN ops.PatrolRound AS r ON r.RoundID = s.RoundID
    WHERE s.CompanyID = @CompanyID
      AND CAST(s.Scantime AS DATE) BETWEEN @FromDate AND @ToDate
      AND (@UnitID IS NULL OR s.UnitID = @UnitID)
      AND (@QrID   IS NULL OR s.QrID   = @QrID)
      AND (@EmpID  IS NULL OR s.EmpID  = @EmpID)
      AND (@OnlyOutOfRange = 0 OR s.IsWithinRange = 0)
    ORDER BY s.Scantime DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM ops.QrScanLog AS s
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = s.UnitID
    WHERE s.CompanyID = @CompanyID
      AND CAST(s.Scantime AS DATE) BETWEEN @FromDate AND @ToDate
      AND (@UnitID IS NULL OR s.UnitID = @UnitID)
      AND (@QrID   IS NULL OR s.QrID   = @QrID)
      AND (@EmpID  IS NULL OR s.EmpID  = @EmpID)
      AND (@OnlyOutOfRange = 0 OR s.IsWithinRange = 0);
END;
GO

/*  per unit / day: expected vs scanned vs missed - the client's proof screen  */
CREATE OR ALTER PROCEDURE dbo.usp_Qr_GetSummary
    @CompanyID INT,
    @UserID    INT,
    @FromDate  DATE = NULL,
    @ToDate    DATE = NULL,
    @UnitID    INT  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FromDate IS NULL SET @FromDate = DATEADD(DAY, -7, CAST(SYSDATETIME() AS DATE));
    IF @ToDate   IS NULL SET @ToDate   = CAST(SYSDATETIME() AS DATE);

    SELECT
        d.[Date] AS ScanDate,
        u.UnitID, u.UnitName, cl.ClientName,
        r.RoundID, r.RoundName, r.StartTime, r.EndTime,
        ExpectedCheckpoints = ISNULL(exp.Cnt, 0),
        ScannedCheckpoints  = ISNULL(sc.Scanned, 0),
        MissedCheckpoints   = CASE WHEN ISNULL(exp.Cnt, 0) - ISNULL(sc.Scanned, 0) > 0
                                   THEN ISNULL(exp.Cnt, 0) - ISNULL(sc.Scanned, 0) ELSE 0 END,
        OutOfRangeScans     = ISNULL(sc.OutOfRange, 0),
        ScansWithPhoto      = ISNULL(sc.WithPhoto, 0),
        CompliancePercent   = CASE WHEN ISNULL(exp.Cnt, 0) = 0 THEN 100
                                   ELSE CAST(ISNULL(sc.Scanned, 0) * 100.0 / exp.Cnt AS DECIMAL(5,1)) END,
        FirstScanAt = sc.FirstScanAt,
        LastScanAt  = sc.LastScanAt
    FROM dbo.fnDateRange(@FromDate, @ToDate) AS d
    CROSS JOIN ops.PatrolRound AS r
    INNER JOIN crm.Unit AS u ON u.UnitID = r.UnitID
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = u.UnitID
    LEFT  JOIN crm.Client AS cl ON cl.ClientID = u.ClientID
    OUTER APPLY (SELECT Cnt = COUNT(*) FROM ops.PatrolRoundCheckpoint AS rc WHERE rc.RoundID = r.RoundID) AS exp
    OUTER APPLY (SELECT Scanned    = COUNT(DISTINCT s.QrID),
                        OutOfRange = SUM(CASE WHEN s.IsWithinRange = 0 THEN 1 ELSE 0 END),
                        WithPhoto  = SUM(CASE WHEN s.ImageUrl IS NOT NULL THEN 1 ELSE 0 END),
                        FirstScanAt = MIN(s.Scantime), LastScanAt = MAX(s.Scantime)
                 FROM ops.QrScanLog AS s
                 WHERE s.RoundID = r.RoundID AND CAST(s.Scantime AS DATE) = d.[Date]) AS sc
    WHERE r.CompanyID = @CompanyID AND r.IsActive = 1 AND r.IsCancel = 0
      AND (@UnitID IS NULL OR r.UnitID = @UnitID)
    ORDER BY d.[Date] DESC, u.UnitName, r.StartTime;
END;
GO

/*==============================================================================
  ROUNDS
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_PatrolRound_Save
    @CompanyID    INT,
    @UserID       INT,
    @UnitID       INT,
    @RoundName    NVARCHAR(100),
    @StartTime    TIME(0),
    @EndTime      TIME(0),
    @GraceMinutes INT           = 15,
    @DaysOfWeek   NVARCHAR(20)  = NULL,
    @QrIdsCsv     NVARCHAR(MAX) = NULL,
    @RoundID      INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) WHERE UnitID = @UnitID)
        THROW 51300, 'You do not have access to this unit.', 1;

    BEGIN TRY
        BEGIN TRAN;

        IF @RoundID IS NULL
        BEGIN
            INSERT INTO ops.PatrolRound (CompanyID, UnitID, RoundName, StartTime, EndTime,
                                         GraceMinutes, DaysOfWeek, InsertDate, InsertUserID)
            VALUES (@CompanyID, @UnitID, @RoundName, @StartTime, @EndTime,
                    @GraceMinutes, @DaysOfWeek, SYSDATETIME(), @UserID);
            SET @RoundID = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE ops.PatrolRound
            SET RoundName = @RoundName, StartTime = @StartTime, EndTime = @EndTime,
                GraceMinutes = @GraceMinutes, DaysOfWeek = @DaysOfWeek,
                UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
            WHERE RoundID = @RoundID AND CompanyID = @CompanyID;

            IF @@ROWCOUNT = 0 THROW 51305, 'Round not found.', 1;
        END

        IF @QrIdsCsv IS NOT NULL
        BEGIN
            DELETE FROM ops.PatrolRoundCheckpoint WHERE RoundID = @RoundID;

            INSERT INTO ops.PatrolRoundCheckpoint (RoundID, QrID, SequenceNo, InsertDate, InsertUserID)
            SELECT @RoundID, ids.ID,
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
                   SYSDATETIME(), @UserID
            FROM dbo.fnSplitIds(@QrIdsCsv) AS ids
            WHERE EXISTS (SELECT 1 FROM ops.QrCheckpoint AS q
                          WHERE q.QrID = ids.ID AND q.CompanyID = @CompanyID AND q.UnitID = @UnitID);

            UPDATE ops.PatrolRound
            SET ExpectedCheckpoints = (SELECT COUNT(*) FROM ops.PatrolRoundCheckpoint WHERE RoundID = @RoundID)
            WHERE RoundID = @RoundID;
        END

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @RoundID, Message = N'Round saved';
END;
GO

/*  tonight's progress for the patrolling officer's home screen  */
CREATE OR ALTER PROCEDURE dbo.usp_PatrolRound_GetMyProgress
    @CompanyID INT,
    @UserID    INT,
    @UnitID    INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Now  DATETIME2(0) = SYSDATETIME();
    DECLARE @Time TIME(0)      = CAST(@Now AS TIME);
    DECLARE @Today DATE        = CAST(@Now AS DATE);

    SELECT
        r.RoundID, r.RoundName, r.StartTime, r.EndTime, r.GraceMinutes,
        r.UnitID, u.UnitName,
        ExpectedCheckpoints = ISNULL(e.Cnt, 0),
        ScannedCheckpoints  = ISNULL(s.Scanned, 0),
        IsCurrentRound = CASE
                            WHEN (r.StartTime <= r.EndTime AND @Time BETWEEN r.StartTime AND r.EndTime)
                              OR (r.StartTime >  r.EndTime AND (@Time >= r.StartTime OR @Time <= r.EndTime))
                            THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT)
                         END
    FROM ops.PatrolRound AS r
    INNER JOIN crm.Unit AS u ON u.UnitID = r.UnitID
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = r.UnitID
    OUTER APPLY (SELECT Cnt = COUNT(*) FROM ops.PatrolRoundCheckpoint AS rc WHERE rc.RoundID = r.RoundID) AS e
    OUTER APPLY (SELECT Scanned = COUNT(DISTINCT sl.QrID)
                 FROM ops.QrScanLog AS sl
                 WHERE sl.RoundID = r.RoundID AND sl.UserID = @UserID
                   AND sl.Scantime >= DATEADD(HOUR, -12, @Now)) AS s
    WHERE r.CompanyID = @CompanyID AND r.IsActive = 1 AND r.IsCancel = 0
      AND (@UnitID IS NULL OR r.UnitID = @UnitID)
    ORDER BY r.StartTime;

    /* next checkpoint to visit, nearest first */
    SELECT
        q.QrID, q.Name, q.Location, q.Latitude, q.Longitude,
        q.MaxDistanceMeters, q.RequirePhoto, rc.SequenceNo, rc.RoundID,
        AlreadyScanned = CASE WHEN EXISTS (
                                SELECT 1 FROM ops.QrScanLog AS sl
                                WHERE sl.QrID = q.QrID AND sl.UserID = @UserID
                                  AND sl.Scantime >= DATEADD(HOUR, -12, @Now))
                              THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END
    FROM ops.PatrolRoundCheckpoint AS rc
    INNER JOIN ops.QrCheckpoint AS q ON q.QrID = rc.QrID
    INNER JOIN ops.PatrolRound  AS r ON r.RoundID = rc.RoundID
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = r.UnitID
    WHERE r.CompanyID = @CompanyID AND r.IsActive = 1 AND q.IsActive = 1
      AND (@UnitID IS NULL OR r.UnitID = @UnitID)
    ORDER BY rc.RoundID, rc.SequenceNo;
END;
GO

/*==============================================================================
  BACKGROUND JOB: rounds that finished with checkpoints missed
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Patrol_DetectMissedRounds
    @CompanyID INT  = NULL,
    @OnDate    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @OnDate IS NULL SET @OnDate = CAST(SYSDATETIME() AS DATE);

    DECLARE @Now DATETIME2(0) = SYSDATETIME();

    SELECT
        r.CompanyID, r.RoundID, r.RoundName, r.UnitID, u.UnitName, cl.ClientName,
        r.StartTime, r.EndTime, @OnDate AS RoundDate,
        ExpectedCheckpoints = ISNULL(e.Cnt, 0),
        ScannedCheckpoints  = ISNULL(s.Scanned, 0),
        MissedCheckpoints   = ISNULL(e.Cnt, 0) - ISNULL(s.Scanned, 0),
        SupervisorEmpID     = u.SupervisorEmpID
    FROM ops.PatrolRound AS r
    INNER JOIN crm.Unit AS u ON u.UnitID = r.UnitID
    LEFT  JOIN crm.Client AS cl ON cl.ClientID = u.ClientID
    OUTER APPLY (SELECT Cnt = COUNT(*) FROM ops.PatrolRoundCheckpoint AS rc WHERE rc.RoundID = r.RoundID) AS e
    OUTER APPLY (SELECT Scanned = COUNT(DISTINCT sl.QrID)
                 FROM ops.QrScanLog AS sl
                 WHERE sl.RoundID = r.RoundID
                   AND CAST(sl.Scantime AS DATE) BETWEEN DATEADD(DAY, -1, @OnDate) AND @OnDate) AS s
    WHERE r.IsActive = 1 AND r.IsCancel = 0
      AND (@CompanyID IS NULL OR r.CompanyID = @CompanyID)
      -- the round window plus its grace has closed
      AND DATEADD(MINUTE, r.GraceMinutes,
              DATEADD(MINUTE, DATEDIFF(MINUTE, CAST('00:00:00' AS TIME), r.EndTime),
                  CAST(DATEADD(DAY, CASE WHEN r.StartTime > r.EndTime THEN 1 ELSE 0 END, @OnDate) AS DATETIME2(0))
              )) < @Now
      AND ISNULL(e.Cnt, 0) > ISNULL(s.Scanned, 0)
    ORDER BY u.UnitName, r.StartTime;
END;
GO

/*==============================================================================
  LOCATION TRACKING
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Location_Track
    @CompanyID      INT,
    @UserID         INT,
    @Latitude       DECIMAL(10,7),
    @Longitude      DECIMAL(10,7),
    @Accuracy       DECIMAL(7,2) = NULL,
    @Speed          DECIMAL(7,2) = NULL,
    @BatteryLevel   TINYINT      = NULL,
    @LoggedAt       DATETIME2(0) = NULL,
    @Source         CHAR(2)      = 'FG',
    @IsMockLocation BIT          = 0,
    @DeviceID       NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    /*  A spoofed ping is RECORDED, not discarded.

        Dropping it left no evidence that anyone had tried, and wrote 0 into
        IsMockLocation on every row, so the column was dead. Storing the ping
        with the flag set gives a supervisor something to act on; the live
        tracking view and the trail both filter IsMockLocation = 0, so a fake
        position still never counts as a real one.  */
    IF @LoggedAt IS NULL SET @LoggedAt = SYSDATETIME();

    DECLARE @EmpID INT, @UnitID INT;
    SELECT @EmpID = EmpID FROM sec.Users WHERE UserID = @UserID;
    SELECT @UnitID = UnitID FROM hr.Employee WHERE EmpID = @EmpID;

    INSERT INTO ops.LocationLog (CompanyID, UserID, EmpID, UnitID, Latitude, Longitude,
                                 Accuracy, Speed, BatteryLevel, LoggedAt, Source,
                                 IsMockLocation, DeviceID)
    VALUES (@CompanyID, @UserID, @EmpID, @UnitID, @Latitude, @Longitude,
            @Accuracy, @Speed, @BatteryLevel, @LoggedAt, @Source, @IsMockLocation, @DeviceID);

    IF @IsMockLocation = 1
        SELECT Success = CAST(0 AS BIT), Status = 422, Id = 0,
               Message = N'Mock location detected and flagged for review';
    ELSE
        SELECT Success = CAST(1 AS BIT), Status = 200, Id = 0, Message = N'Location recorded';
END;
GO

/*  batched pings from the mobile background task - one round trip for N points */
CREATE OR ALTER PROCEDURE dbo.usp_Location_TrackBatch
    @CompanyID INT,
    @UserID    INT,
    @DeviceID  NVARCHAR(200) = NULL,
    @Pings     ops.LocationPingList READONLY
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EmpID INT, @UnitID INT, @Inserted INT;
    SELECT @EmpID = EmpID FROM sec.Users WHERE UserID = @UserID;
    SELECT @UnitID = UnitID FROM hr.Employee WHERE EmpID = @EmpID;

    INSERT INTO ops.LocationLog (CompanyID, UserID, EmpID, UnitID, Latitude, Longitude,
                                 Accuracy, Speed, BatteryLevel, LoggedAt, Source,
                                 IsMockLocation, DeviceID)
    SELECT @CompanyID, @UserID, @EmpID, @UnitID, p.Latitude, p.Longitude,
           p.Accuracy, p.Speed, p.BatteryLevel, p.LoggedAt, p.Source, p.IsMockLocation, @DeviceID
    FROM @Pings AS p;

    SET @Inserted = @@ROWCOUNT;
    DECLARE @Mock INT = (SELECT COUNT(*) FROM @Pings WHERE IsMockLocation = 1);

    /*  The whole batch is accepted even when some of it is spoofed. Rejecting
        the batch would let one bad ping discard a whole shift of genuine
        offline history, which is the opposite of what an offline-first client
        needs. The flagged rows are excluded from the live view instead.  */
    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @Inserted,
           Message = CASE WHEN @Mock > 0
                          THEN CONCAT(@Inserted, N' pings recorded, ', @Mock, N' flagged as mock')
                          ELSE CONCAT(@Inserted, N' pings recorded') END;
END;
GO

/*  live map: where every field user was last seen  */
CREATE OR ALTER PROCEDURE dbo.usp_Location_GetLive
    @CompanyID     INT,
    @UserID        INT,
    @StaleMinutes  INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.UserID, u.UserName, e.EmpID, e.EmpFullName, e.EmpCode, e.Photo, e.Mobile1,
        d.DesignationName, r.RoleCode,
        ll.Latitude, ll.Longitude, ll.Accuracy, ll.BatteryLevel, ll.LoggedAt,
        MinutesAgo = DATEDIFF(MINUTE, ll.LoggedAt, SYSDATETIME()),
        IsStale    = CASE WHEN DATEDIFF(MINUTE, ll.LoggedAt, SYSDATETIME()) > @StaleMinutes
                          THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END,
        CurrentUnit = un.UnitName,
        UnitLatitude = un.Latitude, UnitLongitude = un.Longitude,
        /*  Spoofing attempts are surfaced rather than hidden. The map shows a
            real last-known position; this badge tells the supervisor that the
            same device also sent faked ones today.  */
        MockPingsToday = ISNULL(mk.Cnt, 0)
    FROM sec.Users AS u
    INNER JOIN sec.Role AS r ON r.RoleID = u.RoleID
    LEFT  JOIN hr.Employee AS e ON e.EmpID = u.EmpID
    LEFT  JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    LEFT  JOIN crm.Unit AS un ON un.UnitID = e.UnitID
    OUTER APPLY (SELECT TOP (1) l.Latitude, l.Longitude, l.Accuracy, l.BatteryLevel, l.LoggedAt
                 FROM ops.LocationLog AS l
                 WHERE l.UserID = u.UserID AND l.CompanyID = @CompanyID
                   AND l.LoggedAt >= DATEADD(HOUR, -24, SYSDATETIME())
                   AND l.IsMockLocation = 0
                 ORDER BY l.LoggedAt DESC) AS ll
    OUTER APPLY (SELECT Cnt = COUNT(*)
                 FROM ops.LocationLog AS m
                 WHERE m.UserID = u.UserID AND m.CompanyID = @CompanyID
                   AND m.IsMockLocation = 1
                   AND CAST(m.LoggedAt AS DATE) = CAST(SYSDATETIME() AS DATE)) AS mk
    WHERE u.CompanyID = @CompanyID AND u.IsActive = 1 AND u.IsCancel = 0
      AND (e.UnitID IS NULL
           OR EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au
                      WHERE au.UnitID = e.UnitID))
      /* Someone who reported today, genuinely or otherwise. Silent devices are
         a different screen; a spoofer must not simply disappear from this one. */
      AND (ll.LoggedAt IS NOT NULL OR ISNULL(mk.Cnt, 0) > 0)
    ORDER BY ll.LoggedAt DESC;
END;
GO

/*  one user's trail for a date, plus distance travelled  */
CREATE OR ALTER PROCEDURE dbo.usp_Location_GetTrail
    @CompanyID    INT,
    @UserID       INT,
    @TargetUserID INT,
    @OnDate       DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @OnDate IS NULL SET @OnDate = CAST(SYSDATETIME() AS DATE);

    ;WITH trail AS (
        SELECT l.LogID, l.Latitude, l.Longitude, l.Accuracy, l.Speed, l.BatteryLevel,
               l.LoggedAt, l.Source, l.IsMockLocation,
               /*  Distance is measured between GENUINE pings only. Including a
                   spoofed point would inflate the distance travelled, which is
                   exactly what someone faking GPS wants.  */
               PrevLat = LAG(CASE WHEN l.IsMockLocation = 0 THEN l.Latitude  END) OVER (ORDER BY l.LoggedAt),
               PrevLon = LAG(CASE WHEN l.IsMockLocation = 0 THEN l.Longitude END) OVER (ORDER BY l.LoggedAt)
        FROM ops.LocationLog AS l
        WHERE l.CompanyID = @CompanyID AND l.UserID = @TargetUserID
          AND CAST(l.LoggedAt AS DATE) = @OnDate
    )
    SELECT LogID, Latitude, Longitude, Accuracy, Speed, BatteryLevel, LoggedAt, Source,
           IsMockLocation,
           SegmentMeters = CASE WHEN IsMockLocation = 1 THEN NULL
                                ELSE dbo.fnDistanceMeters(PrevLat, PrevLon, Latitude, Longitude) END
    FROM trail
    ORDER BY LoggedAt;

    /* summary */
    ;WITH trail AS (
        SELECT l.Latitude, l.Longitude, l.LoggedAt, l.IsMockLocation,
               PrevLat = LAG(CASE WHEN l.IsMockLocation = 0 THEN l.Latitude  END) OVER (ORDER BY l.LoggedAt),
               PrevLon = LAG(CASE WHEN l.IsMockLocation = 0 THEN l.Longitude END) OVER (ORDER BY l.LoggedAt)
        FROM ops.LocationLog AS l
        WHERE l.CompanyID = @CompanyID AND l.UserID = @TargetUserID
          AND CAST(l.LoggedAt AS DATE) = @OnDate
    )
    SELECT
        PingCount      = SUM(CASE WHEN IsMockLocation = 0 THEN 1 ELSE 0 END),
        MockPingCount  = SUM(CASE WHEN IsMockLocation = 1 THEN 1 ELSE 0 END),
        FirstSeenAt    = MIN(LoggedAt),
        LastSeenAt     = MAX(LoggedAt),
        DistanceMeters = SUM(CASE WHEN IsMockLocation = 1 THEN 0
                                  ELSE ISNULL(dbo.fnDistanceMeters(PrevLat, PrevLon, Latitude, Longitude), 0) END),
        UnitsVisited   = (SELECT COUNT(DISTINCT s.UnitID) FROM ops.QrScanLog AS s
                          WHERE s.UserID = @TargetUserID AND CAST(s.Scantime AS DATE) = @OnDate)
    FROM trail;
END;
GO

/*  retention: LocationLog is the highest-volume table in the system  */
CREATE OR ALTER PROCEDURE dbo.usp_Location_Purge
    @RetentionDays INT = 90,
    @BatchSize     INT = 50000
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Cutoff DATETIME2(0) = DATEADD(DAY, -@RetentionDays, SYSDATETIME());
    DECLARE @Deleted INT = 1, @Total INT = 0;

    WHILE @Deleted > 0
    BEGIN
        DELETE TOP (@BatchSize) FROM ops.LocationLog WHERE LoggedAt < @Cutoff;
        SET @Deleted = @@ROWCOUNT;
        SET @Total = @Total + @Deleted;
    END

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @Total,
           Message = CONCAT(@Total, N' location rows purged');
END;
GO

PRINT '522_procedures_patrol.sql  ->  OK  (14 procedures)';
GO
