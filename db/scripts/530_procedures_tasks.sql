/*==============================================================================
  530_procedures_tasks.sql
  Task management. Spec: docs/prd/01-database.md §7.3
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Task_Insert
    @CompanyID     INT,
    @UserID        INT,
    @Heading       NVARCHAR(200),
    @Assignedto    INT,
    @Description   NVARCHAR(MAX)  = NULL,
    @UnitID        INT            = NULL,
    @StartDate     DATE           = NULL,
    @EndDate       DATE           = NULL,
    @StartTime     TIME(0)        = NULL,
    @EndTime       TIME(0)        = NULL,
    @PriorityID    INT            = NULL,
    @RepetitionId  INT            = NULL,
    @Attachment    NVARCHAR(500)  = NULL,
    @Important     BIT            = 0,
    @ChecklistJson NVARCHAR(MAX)  = NULL,   -- ["item 1","item 2"]
    @ParentTaskID  INT            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TaskID INT, @BranchID INT, @StatusID INT, @DueDays INT;

    IF NOT EXISTS (SELECT 1 FROM sec.Users WHERE UserID = @Assignedto AND CompanyID = @CompanyID AND IsCancel = 0)
        THROW 51700, 'The assignee does not belong to this company.', 1;

    IF @ChecklistJson IS NOT NULL AND ISJSON(@ChecklistJson) = 0
        THROW 51701, 'ChecklistJson is not valid JSON.', 1;

    IF @StartDate IS NULL SET @StartDate = CAST(SYSDATETIME() AS DATE);
    SET @DueDays = CASE WHEN @EndDate IS NULL THEN NULL ELSE DATEDIFF(DAY, @StartDate, @EndDate) END;

    SELECT @BranchID = BranchID FROM sec.Users WHERE UserID = @Assignedto;
    SELECT TOP (1) @StatusID = TaskStatusID FROM mst.TaskStatus WHERE Name = N'Pending' AND IsCancel = 0;
    IF @StatusID IS NULL SELECT TOP (1) @StatusID = TaskStatusID FROM mst.TaskStatus ORDER BY SortOrder;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO ops.Task (CompanyID, BranchID, UnitID, Heading, Description, Assignedby, Assignedto,
                              StartDate, EndDate, StartTime, EndTime, DueDays, PriorityID,
                              RepetitionId, TaskStatusID, Attachment, Important, ParentTaskID,
                              InsertDate, InsertUserID)
        VALUES (@CompanyID, @BranchID, @UnitID, @Heading, @Description, @UserID, @Assignedto,
                @StartDate, @EndDate, @StartTime, @EndTime, @DueDays, @PriorityID,
                @RepetitionId, @StatusID, @Attachment, @Important, @ParentTaskID,
                SYSDATETIME(), @UserID);

        SET @TaskID = SCOPE_IDENTITY();

        INSERT INTO ops.TaskStatusHistory (CompanyID, TaskID, FromStatusID, ToStatusID, ChangedBy, ChangedOn, Remark)
        VALUES (@CompanyID, @TaskID, NULL, @StatusID, @UserID, SYSDATETIME(), N'Task created');

        IF @ChecklistJson IS NOT NULL
            INSERT INTO ops.TaskChecklist (CompanyID, TaskID, ItemText, SequenceNo, InsertDate, InsertUserID)
            SELECT @CompanyID, @TaskID, j.value,
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), SYSDATETIME(), @UserID
            FROM OPENJSON(@ChecklistJson) AS j;

        INSERT INTO doc.Notification (CompanyID, UserID, Title, Body, Category, DeepLink, InsertDate)
        VALUES (@CompanyID, @Assignedto, N'New task assigned', @Heading, N'Task',
                CONCAT(N'/tasks/', @TaskID), SYSDATETIME());

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @TaskID, Message = N'Task assigned';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Task_UpdateStatus
    @CompanyID   INT,
    @UserID      INT,
    @TaskID      INT,
    @TaskStatusID INT,
    @Remark      NVARCHAR(1000) = NULL,
    @Attachment  NVARCHAR(500)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @FromStatus INT, @IsTerminal BIT, @Assignedby INT, @Heading NVARCHAR(200),
            @RepetitionId INT, @IntervalDays INT, @EndDate DATE, @StartDate DATE, @NewTaskID INT;

    SELECT @FromStatus = t.TaskStatusID, @Assignedby = t.Assignedby, @Heading = t.Heading,
           @RepetitionId = t.RepetitionId, @StartDate = t.StartDate, @EndDate = t.EndDate
    FROM ops.Task AS t
    WHERE t.TaskID = @TaskID AND t.CompanyID = @CompanyID AND t.IsCancel = 0
      AND (t.Assignedto = @UserID OR t.Assignedby = @UserID);

    IF @FromStatus IS NULL
        THROW 51702, 'Task not found, or you are neither the assigner nor the assignee.', 1;

    SELECT @IsTerminal = IsTerminal FROM mst.TaskStatus WHERE TaskStatusID = @TaskStatusID;
    IF @IsTerminal IS NULL THROW 51703, 'Invalid task status.', 1;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE ops.Task
        SET TaskStatusID = @TaskStatusID,
            Isclosed     = @IsTerminal,
            ClosedOn     = CASE WHEN @IsTerminal = 1 THEN SYSDATETIME() ELSE NULL END,
            ClosureRemark = CASE WHEN @IsTerminal = 1 THEN @Remark ELSE ClosureRemark END,
            UpdateDate   = SYSDATETIME(), UpdateUserID = @UserID
        WHERE TaskID = @TaskID;

        INSERT INTO ops.TaskStatusHistory (CompanyID, TaskID, FromStatusID, ToStatusID,
                                           ChangedBy, ChangedOn, Remark, Attachment)
        VALUES (@CompanyID, @TaskID, @FromStatus, @TaskStatusID, @UserID, SYSDATETIME(), @Remark, @Attachment);

        /* a recurring task spawns its next instance when it closes */
        IF @IsTerminal = 1 AND @RepetitionId IS NOT NULL
        BEGIN
            SELECT @IntervalDays = IntervalDays FROM mst.TaskRepetition WHERE RepetitionID = @RepetitionId;

            IF ISNULL(@IntervalDays, 0) > 0
            BEGIN
                INSERT INTO ops.Task (CompanyID, BranchID, UnitID, Heading, Description, Assignedby,
                                      Assignedto, StartDate, EndDate, StartTime, EndTime, DueDays,
                                      PriorityID, RepetitionId, TaskStatusID, Important, ParentTaskID,
                                      InsertDate, InsertUserID)
                SELECT t.CompanyID, t.BranchID, t.UnitID, t.Heading, t.Description, t.Assignedby,
                       t.Assignedto, DATEADD(DAY, @IntervalDays, t.StartDate),
                       DATEADD(DAY, @IntervalDays, t.EndDate), t.StartTime, t.EndTime, t.DueDays,
                       t.PriorityID, t.RepetitionId,
                       (SELECT TOP (1) TaskStatusID FROM mst.TaskStatus WHERE Name = N'Pending'),
                       t.Important, t.TaskID, SYSDATETIME(), @UserID
                FROM ops.Task AS t WHERE t.TaskID = @TaskID;

                SET @NewTaskID = SCOPE_IDENTITY();
            END
        END

        INSERT INTO doc.Notification (CompanyID, UserID, Title, Body, Category, DeepLink, InsertDate)
        VALUES (@CompanyID, @Assignedby, N'Task status changed', @Heading, N'Task',
                CONCAT(N'/tasks/', @TaskID), SYSDATETIME());

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @TaskID,
           Message = CASE WHEN @NewTaskID IS NOT NULL
                          THEN N'Task closed; next occurrence created'
                          ELSE N'Task status updated' END,
           NextTaskID = @NewTaskID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Task_GetList
    @CompanyID   INT,
    @UserID      INT,
    @Mode        NVARCHAR(10)  = N'to',    -- to / by / all
    @TaskStatusID INT          = NULL,
    @PriorityID  INT           = NULL,
    @UnitID      INT           = NULL,
    @OnlyOverdue BIT           = 0,
    @Search      NVARCHAR(200) = NULL,
    @PageNo      INT           = 1,
    @PageSize    INT           = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;

    SELECT
        t.TaskID AS Id, t.Task_id, t.Heading, t.Description, t.Attachment,
        t.Assignedby, Assignedby_Name = ISNULL(be.EmpFullName, bu.UserName),
        t.Assignedto, Assignedto_Name = ISNULL(ae.EmpFullName, au2.UserName),
        t.StartDate, t.EndDate, t.StartTime, t.EndTime, t.DueDays,
        t.PriorityID, Priority = p.Name, PriorityColor = p.ColorHex,
        t.TaskStatusID, TaskStatus_Name = ts.Name, StatusColor = ts.ColorHex,
        t.RepetitionId, t.Isclosed, t.Isread, t.Important, t.InsertDate,
        t.UnitID, u.UnitName,
        IsOverdue = CASE WHEN t.Isclosed = 0 AND t.EndDate IS NOT NULL
                              AND t.EndDate < CAST(SYSDATETIME() AS DATE)
                         THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END,
        ChecklistTotal = ISNULL(cl.Total, 0),
        ChecklistDone  = ISNULL(cl.Done, 0)
    FROM (SELECT TaskID, Task_id = TaskID, Heading, Description, Attachment, Assignedby, Assignedto,
                 StartDate, EndDate, StartTime, EndTime, DueDays, PriorityID, TaskStatusID,
                 RepetitionId, Isclosed, Isread, Important, InsertDate, UnitID, CompanyID, IsCancel
          FROM ops.Task) AS t
    LEFT JOIN sec.Users  AS bu  ON bu.UserID = t.Assignedby
    LEFT JOIN hr.Employee AS be ON be.EmpID = bu.EmpID
    LEFT JOIN sec.Users  AS au2 ON au2.UserID = t.Assignedto
    LEFT JOIN hr.Employee AS ae ON ae.EmpID = au2.EmpID
    LEFT JOIN mst.Priority   AS p  ON p.PriorityID = t.PriorityID
    LEFT JOIN mst.TaskStatus AS ts ON ts.TaskStatusID = t.TaskStatusID
    LEFT JOIN crm.Unit       AS u  ON u.UnitID = t.UnitID
    OUTER APPLY (SELECT Total = COUNT(*), Done = SUM(CASE WHEN c.IsDone = 1 THEN 1 ELSE 0 END)
                 FROM ops.TaskChecklist AS c WHERE c.TaskID = t.TaskID AND c.IsCancel = 0) AS cl
    WHERE t.CompanyID = @CompanyID AND t.IsCancel = 0
      AND ( (@Mode = N'to'  AND t.Assignedto = @UserID)
         OR (@Mode = N'by'  AND t.Assignedby = @UserID)
         OR (@Mode = N'all') )
      AND (@TaskStatusID IS NULL OR t.TaskStatusID = @TaskStatusID)
      AND (@PriorityID   IS NULL OR t.PriorityID   = @PriorityID)
      AND (@UnitID       IS NULL OR t.UnitID       = @UnitID)
      AND (@OnlyOverdue = 0 OR (t.Isclosed = 0 AND t.EndDate < CAST(SYSDATETIME() AS DATE)))
      AND (@Search IS NULL OR t.Heading LIKE N'%' + @Search + N'%')
    ORDER BY t.Important DESC,
             CASE WHEN t.Isclosed = 0 AND t.EndDate < CAST(SYSDATETIME() AS DATE) THEN 0 ELSE 1 END,
             t.EndDate, t.InsertDate DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM ops.Task AS t
    WHERE t.CompanyID = @CompanyID AND t.IsCancel = 0
      AND ( (@Mode = N'to'  AND t.Assignedto = @UserID)
         OR (@Mode = N'by'  AND t.Assignedby = @UserID)
         OR (@Mode = N'all') )
      AND (@TaskStatusID IS NULL OR t.TaskStatusID = @TaskStatusID)
      AND (@PriorityID   IS NULL OR t.PriorityID   = @PriorityID)
      AND (@UnitID       IS NULL OR t.UnitID       = @UnitID)
      AND (@OnlyOverdue = 0 OR (t.Isclosed = 0 AND t.EndDate < CAST(SYSDATETIME() AS DATE)))
      AND (@Search IS NULL OR t.Heading LIKE N'%' + @Search + N'%');
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Task_GetDetail
    @CompanyID INT,
    @UserID    INT,
    @TaskID    INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT t.TaskID, t.Heading, t.Description, t.Attachment, t.StartDate, t.EndDate,
           t.StartTime, t.EndTime, t.DueDays, t.Isclosed, t.Important, t.ClosedOn, t.ClosureRemark,
           t.Assignedby, Assignedby_Name = ISNULL(be.EmpFullName, bu.UserName),
           t.Assignedto, Assignedto_Name = ISNULL(ae.EmpFullName, au2.UserName),
           t.PriorityID, Priority = p.Name, t.TaskStatusID, TaskStatus_Name = ts.Name,
           t.RepetitionId, t.UnitID, u.UnitName, t.InsertDate
    FROM ops.Task AS t
    LEFT JOIN sec.Users   AS bu  ON bu.UserID = t.Assignedby
    LEFT JOIN hr.Employee AS be  ON be.EmpID = bu.EmpID
    LEFT JOIN sec.Users   AS au2 ON au2.UserID = t.Assignedto
    LEFT JOIN hr.Employee AS ae  ON ae.EmpID = au2.EmpID
    LEFT JOIN mst.Priority   AS p  ON p.PriorityID = t.PriorityID
    LEFT JOIN mst.TaskStatus AS ts ON ts.TaskStatusID = t.TaskStatusID
    LEFT JOIN crm.Unit       AS u  ON u.UnitID = t.UnitID
    WHERE t.TaskID = @TaskID AND t.CompanyID = @CompanyID AND t.IsCancel = 0;

    SELECT h.HistoryID, h.FromStatusID, FromStatus = fs.Name, h.ToStatusID, ToStatus = tsx.Name,
           h.ChangedOn, h.Remark, h.Attachment,
           ChangedByName = ISNULL(ce.EmpFullName, cu.UserName)
    FROM ops.TaskStatusHistory AS h
    LEFT JOIN mst.TaskStatus AS fs  ON fs.TaskStatusID = h.FromStatusID
    LEFT JOIN mst.TaskStatus AS tsx ON tsx.TaskStatusID = h.ToStatusID
    LEFT JOIN sec.Users   AS cu ON cu.UserID = h.ChangedBy
    LEFT JOIN hr.Employee AS ce ON ce.EmpID = cu.EmpID
    WHERE h.TaskID = @TaskID AND h.CompanyID = @CompanyID
    ORDER BY h.ChangedOn DESC;

    SELECT ChecklistID, ItemText, SequenceNo, IsDone, DoneBy, DoneOn
    FROM ops.TaskChecklist
    WHERE TaskID = @TaskID AND CompanyID = @CompanyID AND IsCancel = 0
    ORDER BY SequenceNo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Task_MarkRead
    @CompanyID INT, @UserID INT, @TaskID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE ops.Task SET Isread = 1, UpdateDate = SYSDATETIME()
    WHERE TaskID = @TaskID AND CompanyID = @CompanyID AND Assignedto = @UserID;
    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @TaskID, Message = N'Marked read';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Task_ToggleChecklist
    @CompanyID   INT, @UserID INT, @ChecklistID INT, @IsDone BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE ops.TaskChecklist
    SET IsDone = @IsDone,
        DoneBy = CASE WHEN @IsDone = 1 THEN @UserID ELSE NULL END,
        DoneOn = CASE WHEN @IsDone = 1 THEN SYSDATETIME() ELSE NULL END,
        UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
    WHERE ChecklistID = @ChecklistID AND CompanyID = @CompanyID;
    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @ChecklistID, Message = N'Checklist updated';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Task_Delete
    @CompanyID INT, @UserID INT, @TaskID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE ops.Task
    SET IsCancel = 1, UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
    WHERE TaskID = @TaskID AND CompanyID = @CompanyID AND Assignedby = @UserID AND Isclosed = 0;

    SELECT Success = CAST(CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END AS BIT),
           Status = CASE WHEN @@ROWCOUNT > 0 THEN 200 ELSE 403 END,
           Id = @TaskID,
           Message = CASE WHEN @@ROWCOUNT > 0 THEN N'Task deleted'
                          ELSE N'Only the assigner can delete an open task' END;
END;
GO

PRINT '530_procedures_tasks.sql  ->  OK  (7 procedures)';
GO
