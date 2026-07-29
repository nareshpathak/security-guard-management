/*==============================================================================
  521_procedures_deployment.sql
  Deployment, turnout, movement, relievers, inc/dec, contracts, events.
  Spec: docs/prd/01-database.md §7.2 ; docs/prd/02-api.md §4.2
  Split rationale: DECISIONS.md #21
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*==============================================================================
  DEPLOYMENT
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Deployment_Insert
    @CompanyID        INT,
    @UserID           INT,
    @EmpID            INT,
    @UnitID           INT,
    @PostID           INT           = NULL,
    @ShiftID          INT           = NULL,
    @DesignationID    INT           = NULL,
    @FromDate         DATE          = NULL,
    @ToDate           DATE          = NULL,
    @IsReliever       BIT           = 0,
    @RelieverForEmpID INT           = NULL,
    @Remark           NVARCHAR(500) = NULL,
    @AllowOverStrength BIT          = 0,
    @OverStrengthReason NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @FromDate IS NULL SET @FromDate = CAST(SYSDATETIME() AS DATE);

    DECLARE @DeploymentID INT, @BranchID INT, @Required INT, @Filled INT;

    IF NOT EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) WHERE UnitID = @UnitID)
        THROW 51200, 'You do not have access to this unit.', 1;

    SELECT @BranchID = BranchID FROM crm.Unit WHERE UnitID = @UnitID AND CompanyID = @CompanyID AND IsCancel = 0;
    IF @BranchID IS NULL AND NOT EXISTS (SELECT 1 FROM crm.Unit WHERE UnitID = @UnitID AND CompanyID = @CompanyID)
        THROW 51201, 'Unit not found for this company.', 1;

    IF NOT EXISTS (SELECT 1 FROM hr.Employee
                   WHERE EmpID = @EmpID AND CompanyID = @CompanyID AND IsCancel = 0 AND EmpStatus = N'Active')
        THROW 51202, 'Employee is not active.', 1;

    SELECT @ShiftID = ISNULL(@ShiftID, ShiftID), @DesignationID = ISNULL(@DesignationID, DesignationID)
    FROM hr.Employee WHERE EmpID = @EmpID;

    /* one active deployment per employee per shift */
    IF EXISTS (SELECT 1 FROM ops.Deployment
               WHERE CompanyID = @CompanyID AND EmpID = @EmpID AND Status = N'Active' AND IsCancel = 0
                 AND ISNULL(ShiftID, 0) = ISNULL(@ShiftID, 0)
                 AND (ToDate IS NULL OR ToDate >= @FromDate))
        THROW 51203, 'This employee already has an active deployment for that shift.', 1;

    /* post strength check */
    IF @PostID IS NOT NULL AND @AllowOverStrength = 0
    BEGIN
        SELECT @Required = RequiredStrength FROM crm.UnitPost WHERE PostID = @PostID AND CompanyID = @CompanyID;
        SELECT @Filled = COUNT(*) FROM ops.Deployment
        WHERE CompanyID = @CompanyID AND PostID = @PostID AND Status = N'Active' AND IsCancel = 0;

        IF @Required IS NOT NULL AND @Filled >= @Required
            THROW 51204, 'This post is already at contracted strength. Use the over-strength override with a reason.', 1;
    END

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO ops.Deployment
            (CompanyID, BranchID, UnitID, PostID, EmpID, ShiftID, DesignationID,
             FromDate, ToDate, IsReliever, RelieverForEmpID, Status, Remark,
             IsApproved, InsertDate, InsertUserID)
        VALUES
            (@CompanyID, @BranchID, @UnitID, @PostID, @EmpID, @ShiftID, @DesignationID,
             @FromDate, @ToDate, @IsReliever, @RelieverForEmpID, N'Active',
             CASE WHEN @AllowOverStrength = 1
                  THEN CONCAT(N'[Over-strength: ', @OverStrengthReason, N'] ', ISNULL(@Remark, N''))
                  ELSE @Remark END,
             1, SYSDATETIME(), @UserID);

        SET @DeploymentID = SCOPE_IDENTITY();

        /* keep the employee's current posting in sync */
        UPDATE hr.Employee
        SET UnitID = @UnitID,
            Clientid = (SELECT ClientID FROM crm.Unit WHERE UnitID = @UnitID),
            ShiftID = @ShiftID,
            DoDeployment = @FromDate,
            UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
        WHERE EmpID = @EmpID;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @DeploymentID, Message = N'Deployed';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Deployment_End
    @CompanyID    INT,
    @UserID       INT,
    @DeploymentID INT,
    @ToDate       DATE = NULL,
    @Remark       NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @ToDate IS NULL SET @ToDate = CAST(SYSDATETIME() AS DATE);

    UPDATE d
    SET d.Status = N'Ended', d.ToDate = @ToDate, d.Remark = ISNULL(@Remark, d.Remark),
        d.UpdateDate = SYSDATETIME(), d.UpdateUserID = @UserID
    FROM ops.Deployment AS d
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = d.UnitID
    WHERE d.DeploymentID = @DeploymentID AND d.CompanyID = @CompanyID AND d.Status = N'Active';

    SELECT Success = CAST(CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END AS BIT),
           Status  = CASE WHEN @@ROWCOUNT > 0 THEN 200 ELSE 404 END,
           Id      = @DeploymentID,
           Message = N'Deployment ended';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Deployment_GetList
    @CompanyID     INT,
    @UserID        INT,
    @UnitID        INT = NULL,
    @EmpID         INT = NULL,
    @BranchID      INT = NULL,
    @ShiftID       INT = NULL,
    @OnlyActive    BIT = 1,
    @Search        NVARCHAR(200) = NULL,
    @PageNo        INT = 1,
    @PageSize      INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;

    SELECT
        d.DeploymentID, d.EmpID, e.EmpCode, e.EmpFullName, e.Photo, e.Mobile1,
        d.UnitID, u.UnitName, u.ClientID, cl.ClientName,
        d.PostID, p.PostName, d.ShiftID, s.ShiftName, s.StartTime, s.EndTime,
        d.DesignationID, dg.DesignationName,
        d.FromDate, d.ToDate, d.IsReliever, d.RelieverForEmpID,
        RelieverForName = re.EmpFullName,
        d.Status, d.Remark
    FROM ops.Deployment AS d
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = d.UnitID
    INNER JOIN hr.Employee AS e  ON e.EmpID  = d.EmpID
    INNER JOIN crm.Unit    AS u  ON u.UnitID = d.UnitID
    LEFT  JOIN crm.Client  AS cl ON cl.ClientID = u.ClientID
    LEFT  JOIN crm.UnitPost AS p ON p.PostID = d.PostID
    LEFT  JOIN mst.Shift   AS s  ON s.ShiftID = d.ShiftID
    LEFT  JOIN mst.Designation AS dg ON dg.DesignationID = d.DesignationID
    LEFT  JOIN hr.Employee AS re ON re.EmpID = d.RelieverForEmpID
    WHERE d.CompanyID = @CompanyID AND d.IsCancel = 0
      AND (@OnlyActive = 0 OR d.Status = N'Active')
      AND (@UnitID   IS NULL OR d.UnitID   = @UnitID)
      AND (@EmpID    IS NULL OR d.EmpID    = @EmpID)
      AND (@BranchID IS NULL OR d.BranchID = @BranchID)
      AND (@ShiftID  IS NULL OR d.ShiftID  = @ShiftID)
      AND (@Search   IS NULL OR e.EmpFullName LIKE N'%' + @Search + N'%'
                             OR e.EmpCode     LIKE N'%' + @Search + N'%'
                             OR u.UnitName    LIKE N'%' + @Search + N'%')
    ORDER BY u.UnitName, s.StartTime, e.EmpFullName
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM ops.Deployment AS d
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = d.UnitID
    INNER JOIN hr.Employee AS e ON e.EmpID = d.EmpID
    INNER JOIN crm.Unit    AS u ON u.UnitID = d.UnitID
    WHERE d.CompanyID = @CompanyID AND d.IsCancel = 0
      AND (@OnlyActive = 0 OR d.Status = N'Active')
      AND (@UnitID   IS NULL OR d.UnitID   = @UnitID)
      AND (@EmpID    IS NULL OR d.EmpID    = @EmpID)
      AND (@BranchID IS NULL OR d.BranchID = @BranchID)
      AND (@ShiftID  IS NULL OR d.ShiftID  = @ShiftID)
      AND (@Search   IS NULL OR e.EmpFullName LIKE N'%' + @Search + N'%'
                             OR e.EmpCode     LIKE N'%' + @Search + N'%'
                             OR u.UnitName    LIKE N'%' + @Search + N'%');
END;
GO

/*  guards posted at a unit - api/Operation/getunitemployee  */
CREATE OR ALTER PROCEDURE dbo.usp_Deployment_GetUnitEmployees
    @CompanyID INT,
    @UserID    INT,
    @UnitID    INT,
    @ShiftID   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) WHERE UnitID = @UnitID)
        THROW 51200, 'You do not have access to this unit.', 1;

    SELECT
        e.EmpID, e.EmpCode, e.EmpFullName, e.Photo, e.Mobile1, e.BeltNo,
        d.DesignationName, s.ShiftName, dp.PostID, p.PostName, dp.IsReliever,
        TodayStatus = ISNULL(a.Status, N'--'),
        TodayInTime = a.InTime,
        TodayOutTime = a.OutTime
    FROM ops.Deployment AS dp
    INNER JOIN hr.Employee AS e ON e.EmpID = dp.EmpID
    LEFT  JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    LEFT  JOIN mst.Shift   AS s ON s.ShiftID = dp.ShiftID
    LEFT  JOIN crm.UnitPost AS p ON p.PostID = dp.PostID
    LEFT  JOIN ops.Attendance AS a
           ON a.EmpID = e.EmpID AND a.UnitID = dp.UnitID
          AND a.AttendanceDate = CAST(SYSDATETIME() AS DATE) AND a.IsCancel = 0
    WHERE dp.CompanyID = @CompanyID AND dp.UnitID = @UnitID
      AND dp.Status = N'Active' AND dp.IsCancel = 0
      AND (@ShiftID IS NULL OR dp.ShiftID = @ShiftID)
    ORDER BY s.StartTime, e.EmpFullName;
END;
GO

/*  relievers available to fill a vacancy - api/Operation/getreliever  */
CREATE OR ALTER PROCEDURE dbo.usp_Deployment_GetAvailableRelievers
    @CompanyID INT,
    @UserID    INT,
    @UnitID    INT,
    @OnDate    DATE = NULL,
    @ShiftID   INT  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @OnDate IS NULL SET @OnDate = CAST(SYSDATETIME() AS DATE);

    DECLARE @Lat DECIMAL(10,7), @Lon DECIMAL(10,7);
    SELECT @Lat = Latitude, @Lon = Longitude FROM crm.Unit WHERE UnitID = @UnitID;

    SELECT TOP (100)
        e.EmpID, e.EmpCode, e.EmpFullName, e.Photo, e.Mobile1,
        d.DesignationName, e.IsReliever, e.IsGunman,
        CurrentUnit = cu.UnitName,
        LastKnownLat  = ll.Latitude,
        LastKnownLon  = ll.Longitude,
        DistanceMeters = dbo.fnDistanceMeters(ll.Latitude, ll.Longitude, @Lat, @Lon),
        LastSeenAt    = ll.LoggedAt
    FROM hr.Employee AS e
    LEFT JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    LEFT JOIN crm.Unit AS cu ON cu.UnitID = e.UnitID
    OUTER APPLY (SELECT TOP (1) l.Latitude, l.Longitude, l.LoggedAt
                 FROM ops.LocationLog AS l
                 WHERE l.EmpID = e.EmpID AND l.CompanyID = @CompanyID
                 ORDER BY l.LoggedAt DESC) AS ll
    WHERE e.CompanyID = @CompanyID
      AND e.IsCancel = 0
      AND e.EmpStatus = N'Active'
      AND (e.IsReliever = 1 OR e.UnitID IS NULL)
      -- not already on duty that day for that shift
      AND NOT EXISTS (SELECT 1 FROM ops.Attendance AS a
                      WHERE a.EmpID = e.EmpID AND a.AttendanceDate = @OnDate
                        AND ISNULL(a.ShiftID, 0) = ISNULL(@ShiftID, ISNULL(a.ShiftID, 0))
                        AND a.IsCancel = 0)
    ORDER BY CASE WHEN ll.Latitude IS NULL THEN 1 ELSE 0 END,
             dbo.fnDistanceMeters(ll.Latitude, ll.Longitude, @Lat, @Lon),
             e.EmpFullName;
END;
GO

/*==============================================================================
  LIVE TURNOUT BOARD - the flagship operations screen
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Turnout_GetLive
    @CompanyID INT,
    @UserID    INT,
    @OnDate    DATE = NULL,
    @BranchID  INT  = NULL,
    @ClientID  INT  = NULL,
    @ShiftID   INT  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @OnDate IS NULL SET @OnDate = CAST(SYSDATETIME() AS DATE);

    ;WITH scoped AS (
        SELECT u.UnitID, u.UnitName, u.BranchID, u.ClientID, u.Latitude, u.Longitude
        FROM crm.Unit AS u
        INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = u.UnitID
        WHERE u.CompanyID = @CompanyID AND u.IsActive = 1 AND u.IsCancel = 0
          AND (@BranchID IS NULL OR u.BranchID = @BranchID)
          AND (@ClientID IS NULL OR u.ClientID = @ClientID)
    )
    SELECT
        s.UnitID, s.UnitName, s.ClientID, cl.ClientName, s.BranchID,
        RequiredNos = ISNULL(rq.RequiredStrength, 0),
        DeployedNos = ISNULL(dp.DeployedNos, 0),
        PresentNos  = ISNULL(at.PresentNos, 0),
        AbsentNos   = ISNULL(at.AbsentNos, 0),
        HalfDayNos  = ISNULL(at.HalfDayNos, 0),
        RelieverNos = ISNULL(at.RelieverNos, 0),
        PendingApprovalNos = ISNULL(at.PendingNos, 0),
        VacantNos   = CASE WHEN ISNULL(rq.RequiredStrength, 0) - ISNULL(at.PresentNos, 0) > 0
                           THEN ISNULL(rq.RequiredStrength, 0) - ISNULL(at.PresentNos, 0) ELSE 0 END,
        FillPercent = CASE WHEN ISNULL(rq.RequiredStrength, 0) = 0 THEN 100
                           ELSE CAST(ISNULL(at.PresentNos, 0) * 100.0 / rq.RequiredStrength AS DECIMAL(5,1)) END,
        LastPunchAt = at.LastPunchAt,
        s.Latitude, s.Longitude
    FROM scoped AS s
    LEFT JOIN crm.Client AS cl ON cl.ClientID = s.ClientID
    OUTER APPLY dbo.fnUnitRequiredStrength(@CompanyID, s.UnitID, @OnDate, @ShiftID) AS rq
    OUTER APPLY (SELECT DeployedNos = COUNT(*)
                 FROM ops.Deployment AS d
                 WHERE d.UnitID = s.UnitID AND d.Status = N'Active' AND d.IsCancel = 0
                   AND (@ShiftID IS NULL OR d.ShiftID = @ShiftID)) AS dp
    OUTER APPLY (SELECT
                    PresentNos  = SUM(CASE WHEN a.Status IN ('P ','DS') THEN 1 ELSE 0 END),
                    AbsentNos   = SUM(CASE WHEN a.Status = 'A ' THEN 1 ELSE 0 END),
                    HalfDayNos  = SUM(CASE WHEN a.Status = 'HD' THEN 1 ELSE 0 END),
                    RelieverNos = SUM(CASE WHEN a.Status IN ('P ','DS') AND rl.IsReliever = 1 THEN 1 ELSE 0 END),
                    PendingNos  = SUM(CASE WHEN a.ApprovalStatus = 0 THEN 1 ELSE 0 END),
                    LastPunchAt = MAX(a.InTime)
                 FROM ops.Attendance AS a
                 LEFT JOIN ops.Deployment AS rl
                        ON rl.EmpID = a.EmpID AND rl.UnitID = a.UnitID
                       AND rl.Status = N'Active' AND rl.IsCancel = 0
                 WHERE a.UnitID = s.UnitID AND a.AttendanceDate = @OnDate AND a.IsCancel = 0
                   AND (@ShiftID IS NULL OR a.ShiftID = @ShiftID)) AS at
    ORDER BY
        CASE WHEN ISNULL(rq.RequiredStrength, 0) - ISNULL(at.PresentNos, 0) > 0 THEN 0 ELSE 1 END,
        s.UnitName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Turnout_Insert
    @CompanyID   INT,
    @UserID      INT,
    @UnitID      INT,
    @TurnoutDate DATE,
    @ShiftID     INT           = NULL,
    @RequiredNos INT           = 0,
    @PresentNos  INT           = 0,
    @AbsentNos   INT           = 0,
    @RelieverNos INT           = 0,
    @Remark      NVARCHAR(500) = NULL,
    @EmpIdsCsv   NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) WHERE UnitID = @UnitID)
        THROW 51200, 'You do not have access to this unit.', 1;

    DECLARE @TurnoutID INT, @BranchID INT;
    SELECT @BranchID = BranchID FROM crm.Unit WHERE UnitID = @UnitID;

    BEGIN TRY
        BEGIN TRAN;

        SELECT @TurnoutID = TurnoutID FROM ops.Turnout WITH (UPDLOCK, HOLDLOCK)
        WHERE CompanyID = @CompanyID AND UnitID = @UnitID
          AND TurnoutDate = @TurnoutDate AND ISNULL(ShiftID, 0) = ISNULL(@ShiftID, 0) AND IsCancel = 0;

        IF @TurnoutID IS NULL
        BEGIN
            INSERT INTO ops.Turnout (CompanyID, BranchID, UnitID, TurnoutDate, ShiftID,
                                     RequiredNos, PresentNos, AbsentNos, RelieverNos,
                                     EnteredBy, Remark, InsertDate, InsertUserID)
            VALUES (@CompanyID, @BranchID, @UnitID, @TurnoutDate, @ShiftID,
                    @RequiredNos, @PresentNos, @AbsentNos, @RelieverNos,
                    @UserID, @Remark, SYSDATETIME(), @UserID);
            SET @TurnoutID = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE ops.Turnout
            SET RequiredNos = @RequiredNos, PresentNos = @PresentNos,
                AbsentNos = @AbsentNos, RelieverNos = @RelieverNos,
                Remark = @Remark, UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
            WHERE TurnoutID = @TurnoutID;

        IF @EmpIdsCsv IS NOT NULL
        BEGIN
            DELETE FROM ops.TurnoutDetail WHERE TurnoutID = @TurnoutID;

            INSERT INTO ops.TurnoutDetail (TurnoutID, CompanyID, EmpID, EmpName, Status, InsertDate, InsertUserID)
            SELECT @TurnoutID, @CompanyID, e.EmpID, e.EmpFullName, 'P ', SYSDATETIME(), @UserID
            FROM dbo.fnSplitIds(@EmpIdsCsv) AS ids
            INNER JOIN hr.Employee AS e ON e.EmpID = ids.ID AND e.CompanyID = @CompanyID;
        END

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @TurnoutID, Message = N'Turnout saved';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Turnout_GetReport
    @CompanyID INT,
    @UserID    INT,
    @FromDate  DATE = NULL,
    @ToDate    DATE = NULL,
    @UnitID    INT  = NULL,
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
        t.TurnoutID, t.TurnoutDate, t.UnitID, u.UnitName, cl.ClientName,
        t.ShiftID, s.ShiftName, t.RequiredNos, t.PresentNos, t.AbsentNos,
        t.RelieverNos, t.VacantNos, t.Remark,
        EnteredByName = e.EmpFullName
    FROM ops.Turnout AS t
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = t.UnitID
    INNER JOIN crm.Unit   AS u  ON u.UnitID = t.UnitID
    LEFT  JOIN crm.Client AS cl ON cl.ClientID = u.ClientID
    LEFT  JOIN mst.Shift  AS s  ON s.ShiftID = t.ShiftID
    LEFT  JOIN sec.Users  AS su ON su.UserID = t.EnteredBy
    LEFT  JOIN hr.Employee AS e ON e.EmpID = su.EmpID
    WHERE t.CompanyID = @CompanyID AND t.IsCancel = 0
      AND t.TurnoutDate BETWEEN @FromDate AND @ToDate
      AND (@UnitID   IS NULL OR t.UnitID   = @UnitID)
      AND (@BranchID IS NULL OR t.BranchID = @BranchID)
    ORDER BY t.TurnoutDate DESC, u.UnitName
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM ops.Turnout AS t
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = t.UnitID
    WHERE t.CompanyID = @CompanyID AND t.IsCancel = 0
      AND t.TurnoutDate BETWEEN @FromDate AND @ToDate
      AND (@UnitID   IS NULL OR t.UnitID   = @UnitID)
      AND (@BranchID IS NULL OR t.BranchID = @BranchID);
END;
GO

/*==============================================================================
  MOVEMENT
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Movement_Insert
    @CompanyID     INT,
    @UserID        INT,
    @EmpID         INT,
    @FromUnitID    INT           = NULL,
    @ToUnitID      INT           = NULL,
    @PostName      NVARCHAR(150) = NULL,
    @MovementDate  DATE          = NULL,
    @MovementTime  TIME(0)       = NULL,
    @InstructionBy NVARCHAR(150) = NULL,
    @Remark        NVARCHAR(1000) = NULL,
    @ApplyNow      BIT           = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @MovementDate IS NULL SET @MovementDate = CAST(SYSDATETIME() AS DATE);
    IF @MovementTime IS NULL SET @MovementTime = CAST(SYSDATETIME() AS TIME(0));

    DECLARE @MovementID INT, @BranchID INT;
    SELECT @BranchID = BranchID FROM hr.Employee WHERE EmpID = @EmpID AND CompanyID = @CompanyID;

    IF @ToUnitID IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) WHERE UnitID = @ToUnitID)
        THROW 51200, 'You do not have access to the destination unit.', 1;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO ops.Movement (CompanyID, BranchID, EmpID, FromUnitID, ToUnitID, PostName,
                                  MovementDate, MovementTime, InstructionBy, Remark,
                                  IsApproved, InsertDate, InsertUserID)
        VALUES (@CompanyID, @BranchID, @EmpID, @FromUnitID, @ToUnitID, @PostName,
                @MovementDate, @MovementTime, @InstructionBy, @Remark,
                @ApplyNow, SYSDATETIME(), @UserID);

        SET @MovementID = SCOPE_IDENTITY();

        IF @ApplyNow = 1 AND @ToUnitID IS NOT NULL
        BEGIN
            UPDATE ops.Deployment
            SET Status = N'Moved', ToDate = @MovementDate,
                UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
            WHERE CompanyID = @CompanyID AND EmpID = @EmpID AND Status = N'Active' AND IsCancel = 0;

            EXEC dbo.usp_Deployment_Insert
                 @CompanyID = @CompanyID, @UserID = @UserID, @EmpID = @EmpID,
                 @UnitID = @ToUnitID, @FromDate = @MovementDate,
                 @Remark = @Remark, @AllowOverStrength = 1,
                 @OverStrengthReason = N'Movement';

            INSERT INTO hr.EmployeeStatusHistory
                (CompanyID, EmpID, EventType, EventDate, FromUnitID, ToUnitID, Remark,
                 IsApproved, InsertDate, InsertUserID)
            VALUES (@CompanyID, @EmpID, N'Transfer', @MovementDate, @FromUnitID, @ToUnitID, @Remark,
                    1, SYSDATETIME(), @UserID);
        END

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @MovementID, Message = N'Movement recorded';
END;
GO

/*==============================================================================
  INCREASE / DECREASE DEPLOYMENT
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Deployment_IncDec
    @CompanyID     INT,
    @UserID        INT,
    @UnitID        INT,
    @ChangeType    NVARCHAR(10),
    @Dated         DATE,
    @Nop           INT,
    @Timing        NVARCHAR(50)   = NULL,
    @DesignationID INT            = NULL,
    @ShiftID       INT            = NULL,
    @Remark        NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ChangeType NOT IN (N'Increase', N'Decrease')
        THROW 51205, 'ChangeType must be Increase or Decrease.', 1;
    IF @Nop <= 0
        THROW 51206, 'Number of persons must be greater than zero.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) WHERE UnitID = @UnitID)
        THROW 51200, 'You do not have access to this unit.', 1;

    DECLARE @ChangeID INT, @BranchID INT;
    SELECT @BranchID = BranchID FROM crm.Unit WHERE UnitID = @UnitID;

    INSERT INTO ops.DeploymentChange (CompanyID, BranchID, UnitID, ChangeType, Dated, Timing,
                                      Nop, DesignationID, ShiftID, Remark, Status,
                                      InsertDate, InsertUserID)
    VALUES (@CompanyID, @BranchID, @UnitID, @ChangeType, @Dated, @Timing,
            @Nop, @DesignationID, @ShiftID, @Remark, N'Pending', SYSDATETIME(), @UserID);

    SET @ChangeID = SCOPE_IDENTITY();

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @ChangeID,
           Message = N'Change request submitted for approval';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Deployment_IncDecApprove
    @CompanyID INT,
    @UserID    INT,
    @ChangeID  INT,
    @Approve   BIT,
    @Remark    NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE dc
    SET dc.Status     = CASE WHEN @Approve = 1 THEN N'Applied' ELSE N'Rejected' END,
        dc.IsApproved = @Approve,
        dc.IsReject   = CASE WHEN @Approve = 1 THEN 0 ELSE 1 END,
        dc.ApprovedBy = @UserID,
        dc.ApprovedOn = SYSDATETIME(),
        dc.Remark     = ISNULL(@Remark, dc.Remark),
        dc.UpdateDate = SYSDATETIME(), dc.UpdateUserID = @UserID
    FROM ops.DeploymentChange AS dc
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = dc.UnitID
    WHERE dc.ChangeID = @ChangeID AND dc.CompanyID = @CompanyID AND dc.Status = N'Pending';

    SELECT Success = CAST(CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END AS BIT),
           Status  = CASE WHEN @@ROWCOUNT > 0 THEN 200 ELSE 404 END,
           Id      = @ChangeID,
           Message = CASE WHEN @Approve = 1 THEN N'Applied' ELSE N'Rejected' END;
END;
GO

/*==============================================================================
  CONTRACTS AND TEMPORARY EVENTS
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Contract_Insert
    @CompanyID     INT,
    @UserID        INT,
    @ContractType  NVARCHAR(20),
    @ClientID      INT            = NULL,
    @UnitID        INT            = NULL,
    @Dated         DATE           = NULL,
    @Nop           INT            = 0,
    @Timing        NVARCHAR(50)   = NULL,
    @EffectiveFrom DATE           = NULL,
    @EffectiveTo   DATE           = NULL,
    @Remark        NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ContractType NOT IN (N'New', N'Renewal', N'Termination', N'Temporary')
        THROW 51207, 'Invalid contract type.', 1;
    IF @Dated IS NULL SET @Dated = CAST(SYSDATETIME() AS DATE);

    DECLARE @ContractID INT, @BranchID INT;
    SELECT @BranchID = BranchID FROM crm.Unit WHERE UnitID = @UnitID;

    INSERT INTO crm.Contract (CompanyID, BranchID, ClientID, UnitID, ContractType, Dated,
                              Nop, Timing, Remark, EffectiveFrom, EffectiveTo, Status,
                              InsertDate, InsertUserID)
    VALUES (@CompanyID, @BranchID, @ClientID, @UnitID, @ContractType, @Dated,
            @Nop, @Timing, @Remark, @EffectiveFrom, @EffectiveTo, N'Pending',
            SYSDATETIME(), @UserID);

    SET @ContractID = SCOPE_IDENTITY();

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @ContractID, Message = N'Contract recorded';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_TemporaryEvent_Insert
    @CompanyID     INT,
    @UserID        INT,
    @UnitID        INT            = NULL,
    @ClientID      INT            = NULL,
    @TypeOfService NVARCHAR(100)  = NULL,
    @ServiceTypeID INT            = NULL,
    @StartDate     DATE,
    @EndDate       DATE           = NULL,
    @StartTime     TIME(0)        = NULL,
    @EndTime       TIME(0)        = NULL,
    @NOP           INT            = 0,
    @RatePerGuard  DECIMAL(18,2)  = NULL,
    @Remark        NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EventID INT, @BranchID INT;
    SELECT @BranchID = BranchID FROM crm.Unit WHERE UnitID = @UnitID;

    INSERT INTO ops.TemporaryEvent (CompanyID, BranchID, UnitID, ClientID, TypeOfService, ServiceTypeID,
                                    StartDate, EndDate, StartTime, EndTime, NOP, RatePerGuard,
                                    Remark, InsertDate, InsertUserID)
    VALUES (@CompanyID, @BranchID, @UnitID, @ClientID, @TypeOfService, @ServiceTypeID,
            @StartDate, @EndDate, @StartTime, @EndTime, @NOP, @RatePerGuard,
            @Remark, SYSDATETIME(), @UserID);

    SET @EventID = SCOPE_IDENTITY();

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @EventID, Message = N'Event recorded';
END;
GO

/*==============================================================================
  BACKGROUND JOB: alert on posts that will be vacant at shift start
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Turnout_DetectVacantPosts
    @CompanyID    INT = NULL,
    @MinutesAhead INT = 60
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Now DATETIME2(0) = SYSDATETIME();
    DECLARE @Today DATE = CAST(@Now AS DATE);

    SELECT
        u.CompanyID, u.UnitID, u.UnitName, u.BranchID, cl.ClientName,
        s.ShiftID, s.ShiftName, s.StartTime,
        ShiftStartsAt = DATEADD(MINUTE, DATEDIFF(MINUTE, CAST('00:00:00' AS TIME), s.StartTime),
                                CAST(@Today AS DATETIME2(0))),
        RequiredNos = ISNULL(rq.RequiredStrength, 0),
        DeployedNos = ISNULL(dp.DeployedNos, 0),
        VacantNos   = CASE WHEN ISNULL(rq.RequiredStrength, 0) - ISNULL(dp.DeployedNos, 0) > 0
                           THEN ISNULL(rq.RequiredStrength, 0) - ISNULL(dp.DeployedNos, 0) ELSE 0 END
    FROM crm.Unit AS u
    INNER JOIN crm.UnitPost AS p ON p.UnitID = u.UnitID AND p.IsActive = 1 AND p.IsCancel = 0
    INNER JOIN mst.Shift    AS s ON s.ShiftID = p.ShiftID
    LEFT  JOIN crm.Client   AS cl ON cl.ClientID = u.ClientID
    OUTER APPLY dbo.fnUnitRequiredStrength(u.CompanyID, u.UnitID, @Today, s.ShiftID) AS rq
    OUTER APPLY (SELECT DeployedNos = COUNT(*)
                 FROM ops.Deployment AS d
                 WHERE d.UnitID = u.UnitID AND d.ShiftID = s.ShiftID
                   AND d.Status = N'Active' AND d.IsCancel = 0) AS dp
    WHERE u.IsActive = 1 AND u.IsCancel = 0
      AND (@CompanyID IS NULL OR u.CompanyID = @CompanyID)
      AND DATEADD(MINUTE, DATEDIFF(MINUTE, CAST('00:00:00' AS TIME), s.StartTime), CAST(@Today AS DATETIME2(0)))
          BETWEEN @Now AND DATEADD(MINUTE, @MinutesAhead, @Now)
      AND ISNULL(rq.RequiredStrength, 0) > ISNULL(dp.DeployedNos, 0)
    GROUP BY u.CompanyID, u.UnitID, u.UnitName, u.BranchID, cl.ClientName,
             s.ShiftID, s.ShiftName, s.StartTime, rq.RequiredStrength, dp.DeployedNos
    ORDER BY s.StartTime, u.UnitName;
END;
GO

PRINT '521_procedures_deployment.sql  ->  OK  (14 procedures)';
GO
