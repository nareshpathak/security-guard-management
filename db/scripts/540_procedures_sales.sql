/*==============================================================================
  540_procedures_sales.sql
  Sales visits, follow-ups, pipeline and client-relation visits.
  Spec: docs/prd/01-database.md §7.4
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Sales_VisitEntry
    @CompanyID     INT,
    @UserID        INT,
    @CompanyName   NVARCHAR(200),
    @ContactPerson NVARCHAR(150)  = NULL,
    @ContactNo     NVARCHAR(15)   = NULL,
    @Location      NVARCHAR(300)  = NULL,
    @Latitude      DECIMAL(10,7)  = NULL,
    @Longitude     DECIMAL(10,7)  = NULL,
    @Purpose       NVARCHAR(300)  = NULL,
    @Remark        NVARCHAR(1000) = NULL,
    @VisitDate     DATE           = NULL,
    @PhotoUrl      NVARCHAR(500)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @VisitID INT, @EmpID INT, @BranchID INT;

    IF @VisitDate IS NULL SET @VisitDate = CAST(SYSDATETIME() AS DATE);
    SELECT @EmpID = EmpID, @BranchID = BranchID FROM sec.Users WHERE UserID = @UserID;

    INSERT INTO crm.SalesVisit (CompanyID, BranchID, EmpID, CompanyName, ContactPerson, ContactNo,
                                Location, Latitude, Longitude, Purpose, Remark, VisitDate,
                                PhotoUrl, InsertDate, InsertUserID)
    VALUES (@CompanyID, @BranchID, @EmpID, @CompanyName, @ContactPerson, @ContactNo,
            @Location, @Latitude, @Longitude, @Purpose, @Remark, @VisitDate,
            @PhotoUrl, SYSDATETIME(), @UserID);

    SET @VisitID = SCOPE_IDENTITY();

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @VisitID, Message = N'Visit recorded';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Sales_FollowupEntry
    @CompanyID        INT,
    @UserID           INT,
    @CompanyName      NVARCHAR(200),
    @SalesVisitID     INT            = NULL,
    @ContactPerson    NVARCHAR(150)  = NULL,
    @ContactNo        NVARCHAR(15)   = NULL,
    @Location         NVARCHAR(300)  = NULL,
    @Purpose          NVARCHAR(300)  = NULL,
    @FollowupDate     DATE           = NULL,
    @NextFollowupDate DATE           = NULL,
    @Remark           NVARCHAR(1000) = NULL,
    @StopFollow       BIT            = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FollowupID INT, @EmpID INT, @BranchID INT;

    IF @FollowupDate IS NULL SET @FollowupDate = CAST(SYSDATETIME() AS DATE);
    IF @StopFollow = 0 AND @NextFollowupDate IS NULL
        THROW 51800, 'Set a next follow-up date, or mark the lead as stopped.', 1;

    SELECT @EmpID = EmpID, @BranchID = BranchID FROM sec.Users WHERE UserID = @UserID;

    INSERT INTO crm.FollowUp (CompanyID, BranchID, SalesVisitID, EmpID, CompanyName, ContactPerson,
                              ContactNo, Location, Purpose, FollowupDate, NextFollowupDate,
                              Remark, StopFollow, InsertDate, InsertUserID)
    VALUES (@CompanyID, @BranchID, @SalesVisitID, @EmpID, @CompanyName, @ContactPerson,
            @ContactNo, @Location, @Purpose, @FollowupDate, @NextFollowupDate,
            @Remark, @StopFollow, SYSDATETIME(), @UserID);

    SET @FollowupID = SCOPE_IDENTITY();

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @FollowupID, Message = N'Follow-up recorded';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Sales_GetVisitReport
    @CompanyID INT,
    @UserID    INT,
    @OnlyMine  BIT  = 1,
    @EmpID     INT  = NULL,
    @FromDate  DATE = NULL,
    @ToDate    DATE = NULL,
    @Search    NVARCHAR(200) = NULL,
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

    DECLARE @MyEmpID INT;
    SELECT @MyEmpID = EmpID FROM sec.Users WHERE UserID = @UserID;

    SELECT v.VisitID AS Id, v.CompanyName, v.ContactPerson, v.ContactNo, v.Location,
           v.Purpose, v.Remark, v.VisitDate, v.PhotoUrl, v.Latitude, v.Longitude,
           v.EmpID, ExecutiveName = e.EmpFullName
    FROM crm.SalesVisit AS v
    LEFT JOIN hr.Employee AS e ON e.EmpID = v.EmpID
    WHERE v.CompanyID = @CompanyID AND v.IsCancel = 0
      AND v.VisitDate BETWEEN @FromDate AND @ToDate
      AND (@OnlyMine = 0 OR v.EmpID = @MyEmpID)
      AND (@EmpID IS NULL OR v.EmpID = @EmpID)
      AND (@Search IS NULL OR v.CompanyName LIKE N'%' + @Search + N'%'
                           OR v.ContactPerson LIKE N'%' + @Search + N'%')
    ORDER BY v.VisitDate DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM crm.SalesVisit AS v
    WHERE v.CompanyID = @CompanyID AND v.IsCancel = 0
      AND v.VisitDate BETWEEN @FromDate AND @ToDate
      AND (@OnlyMine = 0 OR v.EmpID = @MyEmpID)
      AND (@EmpID IS NULL OR v.EmpID = @EmpID);
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Sales_GetFollowUps
    @CompanyID INT,
    @UserID    INT,
    @Bucket    NVARCHAR(20) = N'due',   -- due / overdue / upcoming / all
    @OnlyMine  BIT  = 1,
    @EmpID     INT  = NULL,
    @PageNo    INT  = 1,
    @PageSize  INT  = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;

    DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE), @MyEmpID INT;
    SELECT @MyEmpID = EmpID FROM sec.Users WHERE UserID = @UserID;

    SELECT f.FollowupID AS Id, f.CompanyName, f.ContactPerson, f.ContactNo, f.Location,
           f.Purpose, f.FollowupDate, f.NextFollowupDate, f.Remark, f.StopFollow,
           f.EmpID, ExecutiveName = e.EmpFullName,
           DaysOverdue = CASE WHEN f.NextFollowupDate < @Today
                              THEN DATEDIFF(DAY, f.NextFollowupDate, @Today) ELSE 0 END
    FROM crm.FollowUp AS f
    LEFT JOIN hr.Employee AS e ON e.EmpID = f.EmpID
    WHERE f.CompanyID = @CompanyID AND f.IsCancel = 0 AND f.StopFollow = 0
      AND (@OnlyMine = 0 OR f.EmpID = @MyEmpID)
      AND (@EmpID IS NULL OR f.EmpID = @EmpID)
      AND ( (@Bucket = N'due'      AND f.NextFollowupDate = @Today)
         OR (@Bucket = N'overdue'  AND f.NextFollowupDate < @Today)
         OR (@Bucket = N'upcoming' AND f.NextFollowupDate > @Today)
         OR (@Bucket = N'all') )
    ORDER BY f.NextFollowupDate
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM crm.FollowUp AS f
    WHERE f.CompanyID = @CompanyID AND f.IsCancel = 0 AND f.StopFollow = 0
      AND (@OnlyMine = 0 OR f.EmpID = @MyEmpID)
      AND (@EmpID IS NULL OR f.EmpID = @EmpID)
      AND ( (@Bucket = N'due'      AND f.NextFollowupDate = @Today)
         OR (@Bucket = N'overdue'  AND f.NextFollowupDate < @Today)
         OR (@Bucket = N'upcoming' AND f.NextFollowupDate > @Today)
         OR (@Bucket = N'all') );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Sales_GetPipeline
    @CompanyID INT,
    @UserID    INT,
    @FromDate  DATE = NULL,
    @ToDate    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FromDate IS NULL SET @FromDate = DATEADD(DAY, -90, CAST(SYSDATETIME() AS DATE));
    IF @ToDate   IS NULL SET @ToDate   = CAST(SYSDATETIME() AS DATE);

    /* funnel */
    SELECT Stage, Cnt = COUNT(*)
    FROM dbo.vwSalesPipeline
    WHERE CompanyID = @CompanyID AND VisitDate BETWEEN @FromDate AND @ToDate
    GROUP BY Stage;

    /* leaderboard */
    SELECT p.EmpID, p.ExecutiveName,
           Visits      = COUNT(*),
           Following   = SUM(CASE WHEN p.Stage = N'Following' THEN 1 ELSE 0 END),
           Dropped     = SUM(CASE WHEN p.Stage = N'Dropped'   THEN 1 ELSE 0 END),
           Contracts   = ISNULL(c.Cnt, 0),
           ConversionPercent = CASE WHEN COUNT(*) = 0 THEN 0
                                    ELSE CAST(ISNULL(c.Cnt, 0) * 100.0 / COUNT(*) AS DECIMAL(5,1)) END
    FROM dbo.vwSalesPipeline AS p
    OUTER APPLY (SELECT Cnt = COUNT(*) FROM crm.Contract AS ct
                 WHERE ct.CompanyID = @CompanyID AND ct.ContractType = N'New'
                   AND ct.Dated BETWEEN @FromDate AND @ToDate
                   AND ct.InsertUserID = @UserID) AS c
    WHERE p.CompanyID = @CompanyID AND p.VisitDate BETWEEN @FromDate AND @ToDate
    GROUP BY p.EmpID, p.ExecutiveName, c.Cnt
    ORDER BY Visits DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Sales_ClientRelationEntry
    @CompanyID     INT,
    @UserID        INT,
    @UnitID        INT,
    @ContactPerson NVARCHAR(150)  = NULL,
    @MobileNo      NVARCHAR(15)   = NULL,
    @Dated         DATE           = NULL,
    @Timing        NVARCHAR(50)   = NULL,
    @Remark        NVARCHAR(1000) = NULL,
    @Latitude      DECIMAL(10,7)  = NULL,
    @Longitude     DECIMAL(10,7)  = NULL,
    @PhotoUrl      NVARCHAR(500)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @VisitID INT, @EmpID INT, @BranchID INT;

    IF @Dated IS NULL SET @Dated = CAST(SYSDATETIME() AS DATE);
    IF NOT EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) WHERE UnitID = @UnitID)
        THROW 51801, 'You do not have access to this unit.', 1;

    SELECT @EmpID = EmpID FROM sec.Users WHERE UserID = @UserID;
    SELECT @BranchID = BranchID FROM crm.Unit WHERE UnitID = @UnitID;

    INSERT INTO crm.ClientRelationVisit (CompanyID, BranchID, UnitID, ExecutiveEmpID, ContactPerson,
                                         MobileNo, Dated, Timing, Remark, Latitude, Longitude,
                                         PhotoUrl, InsertDate, InsertUserID)
    VALUES (@CompanyID, @BranchID, @UnitID, @EmpID, @ContactPerson,
            @MobileNo, @Dated, @Timing, @Remark, @Latitude, @Longitude,
            @PhotoUrl, SYSDATETIME(), @UserID);

    SET @VisitID = SCOPE_IDENTITY();

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @VisitID, Message = N'Client relation visit recorded';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Sales_ClientRelationReport
    @CompanyID INT,
    @UserID    INT,
    @FromDate  DATE = NULL,
    @ToDate    DATE = NULL,
    @UnitID    INT  = NULL,
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

    SELECT v.VisitID, v.Dated, v.Timing, v.ContactPerson, v.MobileNo, v.Remark,
           v.UnitID, UnitName = u.UnitName, cl.ClientName,
           Executive = e.EmpFullName, v.PhotoUrl
    FROM crm.ClientRelationVisit AS v
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = v.UnitID
    INNER JOIN crm.Unit   AS u  ON u.UnitID = v.UnitID
    LEFT  JOIN crm.Client AS cl ON cl.ClientID = u.ClientID
    LEFT  JOIN hr.Employee AS e ON e.EmpID = v.ExecutiveEmpID
    WHERE v.CompanyID = @CompanyID AND v.IsCancel = 0
      AND v.Dated BETWEEN @FromDate AND @ToDate
      AND (@UnitID IS NULL OR v.UnitID = @UnitID)
    ORDER BY v.Dated DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM crm.ClientRelationVisit AS v
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = v.UnitID
    WHERE v.CompanyID = @CompanyID AND v.IsCancel = 0
      AND v.Dated BETWEEN @FromDate AND @ToDate
      AND (@UnitID IS NULL OR v.UnitID = @UnitID);
END;
GO

PRINT '540_procedures_sales.sql  ->  OK  (7 procedures)';
GO
