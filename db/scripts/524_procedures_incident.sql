/*==============================================================================
  524_procedures_incident.sql
  Incidents, field reports, complaints and gate pass.
  Spec: docs/prd/01-database.md §7.2 ; split rationale DECISIONS.md #21
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*==============================================================================
  INCIDENTS
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Incident_Insert
    @CompanyID       INT,
    @UserID          INT,
    @UnitID          INT,
    @IncidentTypeID  INT              = NULL,
    @IncidentDate    DATE             = NULL,
    @IncidentTime    TIME(0)          = NULL,
    @EmpID           INT              = NULL,
    @BeltNo          NVARCHAR(30)     = NULL,
    @FullName        NVARCHAR(200)    = NULL,
    @Severity        TINYINT          = NULL,
    @Remark          NVARCHAR(MAX)    = NULL,
    @ActionTaken     NVARCHAR(MAX)    = NULL,
    @PhotoUrl        NVARCHAR(500)    = NULL,
    @Latitude        DECIMAL(10,7)    = NULL,
    @Longitude       DECIMAL(10,7)    = NULL,
    @ClientRequestId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @IncidentID INT, @BranchID INT, @Existing INT;

    IF @ClientRequestId IS NOT NULL
    BEGIN
        SELECT @Existing = IncidentID FROM ops.Incident WHERE ClientRequestId = @ClientRequestId;
        IF @Existing IS NOT NULL
        BEGIN
            SELECT Success = CAST(1 AS BIT), Status = 200, Id = @Existing, Message = N'Already recorded';
            RETURN;
        END
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) WHERE UnitID = @UnitID)
        THROW 51500, 'You do not have access to this unit.', 1;

    IF @IncidentDate IS NULL SET @IncidentDate = CAST(SYSDATETIME() AS DATE);
    IF @IncidentTime IS NULL SET @IncidentTime = CAST(SYSDATETIME() AS TIME(0));

    SELECT @BranchID = BranchID FROM crm.Unit WHERE UnitID = @UnitID;
    IF @Severity IS NULL SELECT @Severity = Severity FROM mst.IncidentType WHERE IncidentTypeID = @IncidentTypeID;
    IF @EmpID IS NOT NULL AND @FullName IS NULL SELECT @FullName = EmpFullName, @BeltNo = ISNULL(@BeltNo, BeltNo)
                                                FROM hr.Employee WHERE EmpID = @EmpID;

    INSERT INTO ops.Incident (CompanyID, BranchID, UnitID, EmpID, BeltNo, FullName, IncidentTypeID,
                              IncidentDate, IncidentTime, Severity, Remark, ActionTaken, PhotoUrl,
                              Latitude, Longitude, ReportedBy, ClientRequestId, InsertDate, InsertUserID)
    VALUES (@CompanyID, @BranchID, @UnitID, @EmpID, @BeltNo, @FullName, @IncidentTypeID,
            @IncidentDate, @IncidentTime, ISNULL(@Severity, 2), @Remark, @ActionTaken, @PhotoUrl,
            @Latitude, @Longitude, @UserID, @ClientRequestId, SYSDATETIME(), @UserID);

    SET @IncidentID = SCOPE_IDENTITY();

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @IncidentID, Message = N'Incident recorded';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Incident_Close
    @CompanyID   INT,
    @UserID      INT,
    @IncidentID  INT,
    @ActionTaken NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    IF @ActionTaken IS NULL OR LTRIM(RTRIM(@ActionTaken)) = N''
        THROW 51501, 'Action taken is required to close an incident.', 1;

    UPDATE i
    SET i.IsClosed = 1, i.ClosedOn = SYSDATETIME(), i.ActionTaken = @ActionTaken,
        i.UpdateDate = SYSDATETIME(), i.UpdateUserID = @UserID
    FROM ops.Incident AS i
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = i.UnitID
    WHERE i.IncidentID = @IncidentID AND i.CompanyID = @CompanyID AND i.IsClosed = 0;

    SELECT Success = CAST(CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END AS BIT),
           Status = CASE WHEN @@ROWCOUNT > 0 THEN 200 ELSE 404 END,
           Id = @IncidentID, Message = N'Incident closed';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Incident_GetReport
    @CompanyID INT,
    @UserID    INT,
    @FromDate  DATE = NULL,
    @ToDate    DATE = NULL,
    @UnitID    INT  = NULL,
    @IncidentTypeID INT = NULL,
    @Severity  TINYINT = NULL,
    @IsClosed  BIT  = NULL,
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
        i.IncidentID, i.IncidentDate, i.IncidentTime, i.UnitID, u.UnitName, cl.ClientName,
        i.EmpID, i.BeltNo, i.FullName, i.IncidentTypeID, t.IncidentTypeName, i.Severity,
        i.Remark, i.ActionTaken, i.PhotoUrl, i.IsClosed, i.ClosedOn,
        ReportedByName = ISNULL(re.EmpFullName, ru.UserName)
    FROM ops.Incident AS i
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = i.UnitID
    INNER JOIN crm.Unit   AS u  ON u.UnitID = i.UnitID
    LEFT  JOIN crm.Client AS cl ON cl.ClientID = u.ClientID
    LEFT  JOIN mst.IncidentType AS t ON t.IncidentTypeID = i.IncidentTypeID
    LEFT  JOIN sec.Users  AS ru ON ru.UserID = i.ReportedBy
    LEFT  JOIN hr.Employee AS re ON re.EmpID = ru.EmpID
    WHERE i.CompanyID = @CompanyID AND i.IsCancel = 0
      AND i.IncidentDate BETWEEN @FromDate AND @ToDate
      AND (@UnitID         IS NULL OR i.UnitID = @UnitID)
      AND (@IncidentTypeID IS NULL OR i.IncidentTypeID = @IncidentTypeID)
      AND (@Severity       IS NULL OR i.Severity = @Severity)
      AND (@IsClosed       IS NULL OR i.IsClosed = @IsClosed)
    ORDER BY i.IncidentDate DESC, i.IncidentTime DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM ops.Incident AS i
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = i.UnitID
    WHERE i.CompanyID = @CompanyID AND i.IsCancel = 0
      AND i.IncidentDate BETWEEN @FromDate AND @ToDate
      AND (@UnitID         IS NULL OR i.UnitID = @UnitID)
      AND (@IncidentTypeID IS NULL OR i.IncidentTypeID = @IncidentTypeID)
      AND (@Severity       IS NULL OR i.Severity = @Severity)
      AND (@IsClosed       IS NULL OR i.IsClosed = @IsClosed);
END;
GO

/*==============================================================================
  FIELD REPORTS
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_FieldReport_Insert
    @CompanyID       INT,
    @UserID          INT,
    @UnitID          INT,
    @ContactPerson   NVARCHAR(150)    = NULL,
    @Remark          NVARCHAR(MAX)    = NULL,
    @Latitude        DECIMAL(10,7)    = NULL,
    @Longitude       DECIMAL(10,7)    = NULL,
    @PhotoUrl        NVARCHAR(500)    = NULL,
    @ClientRequestId UNIQUEIDENTIFIER = NULL,
    @EmpRemarksJson  NVARCHAR(MAX)    = NULL   -- [{"EmpID":1,"Remark":"..."}]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ReportID INT, @BranchID INT, @SupEmpID INT, @Existing INT;

    IF @ClientRequestId IS NOT NULL
    BEGIN
        SELECT @Existing = ReportID FROM ops.FieldReport WHERE ClientRequestId = @ClientRequestId;
        IF @Existing IS NOT NULL
        BEGIN
            SELECT Success = CAST(1 AS BIT), Status = 200, Id = @Existing, Message = N'Already recorded';
            RETURN;
        END
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) WHERE UnitID = @UnitID)
        THROW 51500, 'You do not have access to this unit.', 1;

    IF @EmpRemarksJson IS NOT NULL AND ISJSON(@EmpRemarksJson) = 0
        THROW 51502, 'EmpRemarksJson is not valid JSON.', 1;

    SELECT @BranchID = BranchID FROM crm.Unit WHERE UnitID = @UnitID;
    SELECT @SupEmpID = EmpID FROM sec.Users WHERE UserID = @UserID;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO ops.FieldReport (CompanyID, BranchID, UnitID, SupervisorEmpID, Createdate,
                                     ContactPerson, Remark, Latitude, Longitude, PhotoUrl,
                                     ClientRequestId, InsertDate, InsertUserID)
        VALUES (@CompanyID, @BranchID, @UnitID, @SupEmpID, SYSDATETIME(),
                @ContactPerson, @Remark, @Latitude, @Longitude, @PhotoUrl,
                @ClientRequestId, SYSDATETIME(), @UserID);

        SET @ReportID = SCOPE_IDENTITY();

        IF @EmpRemarksJson IS NOT NULL
            INSERT INTO ops.FieldReportDetail (ReportID, CompanyID, EmpID, Name, DesignationName,
                                               Joindate, Photo, Remark, InsertDate, InsertUserID)
            SELECT @ReportID, @CompanyID, e.EmpID, e.EmpFullName, d.DesignationName,
                   e.Doj, e.Photo, j.Remark, SYSDATETIME(), @UserID
            FROM OPENJSON(@EmpRemarksJson)
                 WITH (EmpID INT '$.EmpID', Remark NVARCHAR(1000) '$.Remark') AS j
            INNER JOIN hr.Employee AS e ON e.EmpID = j.EmpID AND e.CompanyID = @CompanyID
            LEFT  JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @ReportID, Message = N'Field report saved';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_FieldReport_GetDetail
    @CompanyID INT,
    @UserID    INT,
    @ReportID  INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT f.ReportID, f.Createdate, f.UnitID, u.UnitName, cl.ClientName,
           f.ContactPerson, f.Remark, f.Latitude, f.Longitude, f.PhotoUrl,
           SupervisorName = e.EmpFullName
    FROM ops.FieldReport AS f
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = f.UnitID
    INNER JOIN crm.Unit   AS u  ON u.UnitID = f.UnitID
    LEFT  JOIN crm.Client AS cl ON cl.ClientID = u.ClientID
    LEFT  JOIN hr.Employee AS e ON e.EmpID = f.SupervisorEmpID
    WHERE f.ReportID = @ReportID AND f.CompanyID = @CompanyID AND f.IsCancel = 0;

    SELECT DetailID, EmpID, Name, DesignationName, Joindate, Photo, Remark
    FROM ops.FieldReportDetail
    WHERE ReportID = @ReportID AND CompanyID = @CompanyID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Report_GetCounts
    @CompanyID INT,
    @UserID    INT,
    @OnDate    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @OnDate IS NULL SET @OnDate = CAST(SYSDATETIME() AS DATE);

    SELECT
        Fieldcount   = (SELECT COUNT(*) FROM ops.FieldReport AS f
                        INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = f.UnitID
                        WHERE f.CompanyID = @CompanyID AND CAST(f.Createdate AS DATE) = @OnDate AND f.IsCancel = 0),
        Recruitcount = (SELECT COUNT(*) FROM hr.Recruit
                        WHERE CompanyID = @CompanyID AND Dated = @OnDate AND IsCancel = 0),
        Turnoutcount = (SELECT COUNT(*) FROM ops.Turnout AS t
                        INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = t.UnitID
                        WHERE t.CompanyID = @CompanyID AND t.TurnoutDate = @OnDate AND t.IsCancel = 0),
        Incidentcount = (SELECT COUNT(*) FROM ops.Incident AS i
                        INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = i.UnitID
                        WHERE i.CompanyID = @CompanyID AND i.IncidentDate = @OnDate AND i.IsCancel = 0);
END;
GO

/*==============================================================================
  COMPLAINTS
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Complaint_Insert
    @CompanyID       INT,
    @UserID          INT,
    @UnitID          INT,
    @Description     NVARCHAR(MAX),
    @ComplaintTypeID INT              = NULL,
    @ClientID        INT              = NULL,
    @PhotoUrl        NVARCHAR(500)    = NULL,
    @ClientRequestId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ComplaintID INT, @BranchID INT, @Sla INT, @TypeName NVARCHAR(100);

    SELECT @BranchID = BranchID, @ClientID = ISNULL(@ClientID, ClientID)
    FROM crm.Unit WHERE UnitID = @UnitID AND CompanyID = @CompanyID;

    SELECT @Sla = DefaultSlaHours, @TypeName = ComplaintTypeName
    FROM mst.ComplaintType WHERE ComplaintTypeID = @ComplaintTypeID;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO ops.Complaint (CompanyID, BranchID, UnitID, ClientID, RaisedByUserID,
                                   ComplaintTypeID, Complainttype, Description, PhotoUrl,
                                   DueOn, Status, InsertDate, InsertUserID)
        VALUES (@CompanyID, @BranchID, @UnitID, @ClientID, @UserID,
                @ComplaintTypeID, @TypeName, @Description, @PhotoUrl,
                DATEADD(HOUR, ISNULL(@Sla, 24), SYSDATETIME()), N'Open', SYSDATETIME(), @UserID);

        SET @ComplaintID = SCOPE_IDENTITY();

        INSERT INTO ops.ComplaintHistory (CompanyID, ComplaintID, Status, Remark, ChangedBy, ChangedOn)
        VALUES (@CompanyID, @ComplaintID, N'Open', N'Complaint raised', @UserID, SYSDATETIME());

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @ComplaintID, Message = N'Complaint registered';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Complaint_UpdateStatus
    @CompanyID       INT,
    @UserID          INT,
    @ComplaintID     INT,
    @Status          NVARCHAR(20),
    @Remark          NVARCHAR(1000) = NULL,
    @AssignedToEmpID INT            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Status NOT IN (N'Open', N'Assigned', N'InProgress', N'Closed', N'Rejected')
        THROW 51503, 'Invalid complaint status.', 1;

    IF @Status IN (N'Closed', N'Rejected') AND (@Remark IS NULL OR LTRIM(RTRIM(@Remark)) = N'')
        THROW 51504, 'A closure remark is required.', 1;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE c
        SET c.Status          = @Status,
            c.AssignedToEmpID = ISNULL(@AssignedToEmpID, c.AssignedToEmpID),
            c.IsClosed        = CASE WHEN @Status IN (N'Closed', N'Rejected') THEN 1 ELSE 0 END,
            c.ClosedOn        = CASE WHEN @Status IN (N'Closed', N'Rejected') THEN SYSDATETIME() ELSE NULL END,
            c.ClosureRemark   = CASE WHEN @Status IN (N'Closed', N'Rejected') THEN @Remark ELSE c.ClosureRemark END,
            c.UpdateDate = SYSDATETIME(), c.UpdateUserID = @UserID
        FROM ops.Complaint AS c
        INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = c.UnitID
        WHERE c.ComplaintID = @ComplaintID AND c.CompanyID = @CompanyID AND c.IsCancel = 0;

        IF @@ROWCOUNT = 0 THROW 51505, 'Complaint not found.', 1;

        INSERT INTO ops.ComplaintHistory (CompanyID, ComplaintID, Status, Remark, ChangedBy, ChangedOn)
        VALUES (@CompanyID, @ComplaintID, @Status, @Remark, @UserID, SYSDATETIME());

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @ComplaintID,
           Message = CONCAT(N'Complaint moved to ', @Status);
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Complaint_GetList
    @CompanyID INT,
    @UserID    INT,
    @UnitID    INT  = NULL,
    @ClientID  INT  = NULL,
    @Status    NVARCHAR(20) = NULL,
    @IsClosed  BIT  = NULL,
    @OnlySlaBreached BIT = 0,
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

    SELECT
        c.ComplaintID, c.InsertDate, c.UnitID, u.UnitName, c.ClientID, cl.ClientName,
        c.ComplaintTypeID, ct.ComplaintTypeName, c.Complainttype, c.Description, c.PhotoUrl,
        c.Status, c.IsClosed, c.ClosedOn, c.ClosureRemark, c.DueOn,
        c.AssignedToEmpID, AssignedToName = ae.EmpFullName,
        RaisedByName = ISNULL(re.EmpFullName, ru.UserName),
        AgeHours = DATEDIFF(HOUR, c.InsertDate, SYSDATETIME()),
        IsSlaBreached = CASE WHEN c.IsClosed = 0 AND c.DueOn IS NOT NULL AND c.DueOn < SYSDATETIME()
                             THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END
    FROM ops.Complaint AS c
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = c.UnitID
    INNER JOIN crm.Unit   AS u  ON u.UnitID = c.UnitID
    LEFT  JOIN crm.Client AS cl ON cl.ClientID = c.ClientID
    LEFT  JOIN mst.ComplaintType AS ct ON ct.ComplaintTypeID = c.ComplaintTypeID
    LEFT  JOIN hr.Employee AS ae ON ae.EmpID = c.AssignedToEmpID
    LEFT  JOIN sec.Users   AS ru ON ru.UserID = c.RaisedByUserID
    LEFT  JOIN hr.Employee AS re ON re.EmpID = ru.EmpID
    WHERE c.CompanyID = @CompanyID AND c.IsCancel = 0
      AND (@UnitID   IS NULL OR c.UnitID = @UnitID)
      AND (@ClientID IS NULL OR c.ClientID = @ClientID)
      AND (@Status   IS NULL OR c.Status = @Status)
      AND (@IsClosed IS NULL OR c.IsClosed = @IsClosed)
      AND (@FromDate IS NULL OR CAST(c.InsertDate AS DATE) >= @FromDate)
      AND (@ToDate   IS NULL OR CAST(c.InsertDate AS DATE) <= @ToDate)
      AND (@OnlySlaBreached = 0 OR (c.IsClosed = 0 AND c.DueOn IS NOT NULL AND c.DueOn < SYSDATETIME()))
    ORDER BY CASE WHEN c.IsClosed = 0 AND c.DueOn < SYSDATETIME() THEN 0 ELSE 1 END,
             c.InsertDate DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM ops.Complaint AS c
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = c.UnitID
    WHERE c.CompanyID = @CompanyID AND c.IsCancel = 0
      AND (@UnitID   IS NULL OR c.UnitID = @UnitID)
      AND (@ClientID IS NULL OR c.ClientID = @ClientID)
      AND (@Status   IS NULL OR c.Status = @Status)
      AND (@IsClosed IS NULL OR c.IsClosed = @IsClosed)
      AND (@OnlySlaBreached = 0 OR (c.IsClosed = 0 AND c.DueOn IS NOT NULL AND c.DueOn < SYSDATETIME()));
END;
GO

/*==============================================================================
  GATE PASS
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_GatePass_Insert
    @CompanyID       INT,
    @UserID          INT,
    @UnitID          INT,
    @Name            NVARCHAR(200),
    @MobileNo        NVARCHAR(15)     = NULL,
    @Purpose         NVARCHAR(300)    = NULL,
    @WhomToMeet      NVARCHAR(200)    = NULL,
    @VehicleNo       NVARCHAR(30)     = NULL,
    @MaterialDetails NVARCHAR(1000)   = NULL,
    @VisitorImage    NVARCHAR(500)    = NULL,
    @ClientRequestId UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @GatePassID INT, @BranchID INT, @EmpID INT, @Existing INT;

    IF @ClientRequestId IS NOT NULL
    BEGIN
        SELECT @Existing = GatePassID FROM ops.GatePass WHERE ClientRequestId = @ClientRequestId;
        IF @Existing IS NOT NULL
        BEGIN
            SELECT Success = CAST(1 AS BIT), Status = 200, Id = @Existing, Message = N'Already recorded';
            RETURN;
        END
    END

    SELECT @BranchID = BranchID FROM crm.Unit WHERE UnitID = @UnitID AND CompanyID = @CompanyID;
    SELECT @EmpID = EmpID FROM sec.Users WHERE UserID = @UserID;

    INSERT INTO ops.GatePass (CompanyID, BranchID, UnitID, Dated, Name, MobileNo, Purpose,
                              WhomToMeet, VehicleNo, MaterialDetails, VisitorImage, InTime,
                              EnteredByEmpID, ClientRequestId, InsertDate, InsertUserID)
    VALUES (@CompanyID, @BranchID, @UnitID, CAST(SYSDATETIME() AS DATE), @Name, @MobileNo, @Purpose,
            @WhomToMeet, @VehicleNo, @MaterialDetails, @VisitorImage, SYSDATETIME(),
            @EmpID, @ClientRequestId, SYSDATETIME(), @UserID);

    SET @GatePassID = SCOPE_IDENTITY();

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @GatePassID, Message = N'Visitor entry recorded';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GatePass_Exit
    @CompanyID  INT,
    @UserID     INT,
    @GatePassID INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE g
    SET g.OutTime = SYSDATETIME(), g.UpdateDate = SYSDATETIME(), g.UpdateUserID = @UserID
    FROM ops.GatePass AS g
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = g.UnitID
    WHERE g.GatePassID = @GatePassID AND g.CompanyID = @CompanyID AND g.OutTime IS NULL;

    SELECT Success = CAST(CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END AS BIT),
           Status = CASE WHEN @@ROWCOUNT > 0 THEN 200 ELSE 404 END,
           Id = @GatePassID, Message = N'Exit recorded';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GatePass_GetList
    @CompanyID  INT,
    @UserID     INT,
    @UnitID     INT  = NULL,
    @FromDate   DATE = NULL,
    @ToDate     DATE = NULL,
    @OnlyInside BIT  = 0,
    @Search     NVARCHAR(200) = NULL,
    @PageNo     INT  = 1,
    @PageSize   INT  = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;
    IF @FromDate IS NULL SET @FromDate = CAST(SYSDATETIME() AS DATE);
    IF @ToDate   IS NULL SET @ToDate   = CAST(SYSDATETIME() AS DATE);

    SELECT
        g.GatePassID, g.Dated, g.Name, g.MobileNo, g.Purpose, g.WhomToMeet,
        g.VehicleNo, g.MaterialDetails, g.VisitorImage, g.InTime, g.OutTime,
        g.UnitID, u.UnitName,
        EnteredByName = e.EmpFullName,
        IsInside = CASE WHEN g.OutTime IS NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END,
        DurationMinutes = DATEDIFF(MINUTE, g.InTime, ISNULL(g.OutTime, SYSDATETIME()))
    FROM ops.GatePass AS g
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = g.UnitID
    INNER JOIN crm.Unit AS u ON u.UnitID = g.UnitID
    LEFT  JOIN hr.Employee AS e ON e.EmpID = g.EnteredByEmpID
    WHERE g.CompanyID = @CompanyID AND g.IsCancel = 0
      AND (@OnlyInside = 1 OR g.Dated BETWEEN @FromDate AND @ToDate)
      AND (@OnlyInside = 0 OR g.OutTime IS NULL)
      AND (@UnitID IS NULL OR g.UnitID = @UnitID)
      AND (@Search IS NULL OR g.Name LIKE N'%' + @Search + N'%'
                           OR g.MobileNo LIKE N'%' + @Search + N'%'
                           OR g.VehicleNo LIKE N'%' + @Search + N'%')
    ORDER BY g.InTime DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM ops.GatePass AS g
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = g.UnitID
    WHERE g.CompanyID = @CompanyID AND g.IsCancel = 0
      AND (@OnlyInside = 1 OR g.Dated BETWEEN @FromDate AND @ToDate)
      AND (@OnlyInside = 0 OR g.OutTime IS NULL)
      AND (@UnitID IS NULL OR g.UnitID = @UnitID);
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Suggestion_Insert
    @CompanyID   INT,
    @UserID      INT,
    @Subject     NVARCHAR(200) = NULL,
    @Description NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @EmpID INT, @Id INT;
    SELECT @EmpID = EmpID FROM sec.Users WHERE UserID = @UserID;

    INSERT INTO hr.Suggestion (CompanyID, EmpID, Subject, Description, InsertDate, InsertUserID)
    VALUES (@CompanyID, @EmpID, @Subject, @Description, SYSDATETIME(), @UserID);
    SET @Id = SCOPE_IDENTITY();

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @Id, Message = N'Suggestion submitted';
END;
GO

PRINT '524_procedures_incident.sql  ->  OK  (13 procedures)';
GO
