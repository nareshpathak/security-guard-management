/*==============================================================================
  080_task_tables.sql
  Task management (schema: ops)
  Spec: docs/prd/01-database.md §2.6
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('ops.Task','U') IS NULL
CREATE TABLE ops.Task (
    TaskID          INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_Task PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    BranchID        INT             NULL,
    UnitID          INT             NULL,
    Heading         NVARCHAR(200)   NOT NULL,
    Description     NVARCHAR(MAX)   NULL,
    Assignedby      INT             NOT NULL,      -- sec.Users.UserID
    Assignedto      INT             NOT NULL,      -- sec.Users.UserID
    StartDate       DATE            NULL,
    EndDate         DATE            NULL,
    StartTime       TIME(0)         NULL,
    EndTime         TIME(0)         NULL,
    DueDays         INT             NULL,
    PriorityID      INT             NULL,
    RepetitionId    INT             NULL,
    TaskStatusID    INT             NOT NULL,
    Attachment      NVARCHAR(500)   NULL,
    Isclosed        BIT             NOT NULL CONSTRAINT DF_ops_Task_Isclosed  DEFAULT (0),
    Isread          BIT             NOT NULL CONSTRAINT DF_ops_Task_Isread    DEFAULT (0),
    Important       BIT             NOT NULL CONSTRAINT DF_ops_Task_Important DEFAULT (0),
    ParentTaskID    INT             NULL,          -- set on a recurring task's next instance
    ClosedOn        DATETIME2(0)    NULL,
    ClosureRemark   NVARCHAR(1000)  NULL,
    IsCancel        BIT             NOT NULL CONSTRAINT DF_ops_Task_IsCancel   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_Task_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_ops_Task_Company    FOREIGN KEY (CompanyID)    REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_Task_Branch     FOREIGN KEY (BranchID)     REFERENCES org.Branch (BranchID),
    CONSTRAINT FK_ops_Task_Unit       FOREIGN KEY (UnitID)       REFERENCES crm.Unit (UnitID),
    CONSTRAINT FK_ops_Task_AssignedBy FOREIGN KEY (Assignedby)   REFERENCES sec.Users (UserID),
    CONSTRAINT FK_ops_Task_AssignedTo FOREIGN KEY (Assignedto)   REFERENCES sec.Users (UserID),
    CONSTRAINT FK_ops_Task_Priority   FOREIGN KEY (PriorityID)   REFERENCES mst.Priority (PriorityID),
    CONSTRAINT FK_ops_Task_Repetition FOREIGN KEY (RepetitionId) REFERENCES mst.TaskRepetition (RepetitionID),
    CONSTRAINT FK_ops_Task_Status     FOREIGN KEY (TaskStatusID) REFERENCES mst.TaskStatus (TaskStatusID),
    CONSTRAINT FK_ops_Task_Parent     FOREIGN KEY (ParentTaskID) REFERENCES ops.Task (TaskID),
    CONSTRAINT CK_ops_Task_Dates CHECK (EndDate IS NULL OR StartDate IS NULL OR EndDate >= StartDate)
);
GO

IF OBJECT_ID('ops.TaskStatusHistory','U') IS NULL
CREATE TABLE ops.TaskStatusHistory (
    HistoryID       INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_TaskStatusHistory PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    TaskID          INT             NOT NULL,
    FromStatusID    INT             NULL,
    ToStatusID      INT             NOT NULL,
    ChangedBy       INT             NOT NULL,
    ChangedOn       DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_TaskStatusHistory_ChangedOn DEFAULT (SYSDATETIME()),
    Remark          NVARCHAR(1000)  NULL,
    Attachment      NVARCHAR(500)   NULL,
    CONSTRAINT FK_ops_TaskStatusHistory_Company    FOREIGN KEY (CompanyID)    REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_TaskStatusHistory_Task       FOREIGN KEY (TaskID)       REFERENCES ops.Task (TaskID),
    CONSTRAINT FK_ops_TaskStatusHistory_FromStatus FOREIGN KEY (FromStatusID) REFERENCES mst.TaskStatus (TaskStatusID),
    CONSTRAINT FK_ops_TaskStatusHistory_ToStatus   FOREIGN KEY (ToStatusID)   REFERENCES mst.TaskStatus (TaskStatusID),
    CONSTRAINT FK_ops_TaskStatusHistory_ChangedBy  FOREIGN KEY (ChangedBy)    REFERENCES sec.Users (UserID)
);
GO

IF OBJECT_ID('ops.TaskChecklist','U') IS NULL
CREATE TABLE ops.TaskChecklist (
    ChecklistID     INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_ops_TaskChecklist PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    TaskID          INT             NOT NULL,
    ItemText        NVARCHAR(500)   NOT NULL,
    SequenceNo      INT             NOT NULL CONSTRAINT DF_ops_TaskChecklist_Seq    DEFAULT (1),
    IsDone          BIT             NOT NULL CONSTRAINT DF_ops_TaskChecklist_IsDone DEFAULT (0),
    DoneBy          INT             NULL,
    DoneOn          DATETIME2(0)    NULL,
    IsCancel        BIT             NOT NULL CONSTRAINT DF_ops_TaskChecklist_IsCancel   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_ops_TaskChecklist_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    UpdateDate      DATETIME2(0)    NULL,
    UpdateUserID    INT             NULL,
    CONSTRAINT FK_ops_TaskChecklist_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_ops_TaskChecklist_Task    FOREIGN KEY (TaskID)    REFERENCES ops.Task (TaskID),
    CONSTRAINT FK_ops_TaskChecklist_DoneBy  FOREIGN KEY (DoneBy)    REFERENCES sec.Users (UserID)
);
GO

PRINT '080_task_tables.sql  ->  OK  (3 tables)';
GO
