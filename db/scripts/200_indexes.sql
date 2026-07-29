/*==============================================================================
  200_indexes.sql
  Performance indexes. Spec: docs/prd/01-database.md §3

  Every index leads with CompanyID because every query is tenant-scoped.
  Unique/idempotency indexes are created inline with their tables (010-150);
  this file holds the read-path covering indexes only.
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*============================  ATTENDANCE  =================================*/
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Attendance_Company_Date_Unit' AND object_id=OBJECT_ID('ops.Attendance'))
    CREATE INDEX IX_Attendance_Company_Date_Unit ON ops.Attendance (CompanyID, AttendanceDate, UnitID)
        INCLUDE (EmpID, Status, ApprovalStatus, InTime, OutTime, WorkedHours, ShiftID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Attendance_Company_Emp_Date' AND object_id=OBJECT_ID('ops.Attendance'))
    CREATE INDEX IX_Attendance_Company_Emp_Date ON ops.Attendance (CompanyID, EmpID, AttendanceDate DESC)
        INCLUDE (Status, ShiftID, ApprovalStatus, WorkedHours, OtHours);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Attendance_Approval_Queue' AND object_id=OBJECT_ID('ops.Attendance'))
    CREATE INDEX IX_Attendance_Approval_Queue ON ops.Attendance (CompanyID, ApprovalStatus, AttendanceDate)
        INCLUDE (EmpID, UnitID, InTime, OutTime, InDistanceMeters, OutDistanceMeters, InSelfieUrl)
        WHERE ApprovalStatus = 0 AND IsCancel = 0;
GO
-- Exceptions. A filtered index predicate may not contain OR, so the two
-- exception classes get one index each.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Attendance_MockLocation' AND object_id=OBJECT_ID('ops.Attendance'))
    CREATE INDEX IX_Attendance_MockLocation ON ops.Attendance (CompanyID, AttendanceDate)
        INCLUDE (EmpID, UnitID, InDistanceMeters, OutDistanceMeters, DeviceID)
        WHERE IsMockLocation = 1 AND IsCancel = 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Attendance_MissingOutPunch' AND object_id=OBJECT_ID('ops.Attendance'))
    CREATE INDEX IX_Attendance_MissingOutPunch ON ops.Attendance (CompanyID, AttendanceDate)
        INCLUDE (EmpID, UnitID, ShiftID, InTime)
        WHERE OutTime IS NULL AND IsCancel = 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_AttendanceSummary_Emp_Month' AND object_id=OBJECT_ID('ops.AttendanceSummary'))
    CREATE INDEX IX_AttendanceSummary_Emp_Month ON ops.AttendanceSummary (CompanyID, MonthYear, EmpID)
        INCLUDE (PresentDays, AbsentDays, HalfDays, PayableDays, OtHours);
GO

/*==========================  PATROL / LOCATION  ============================*/
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_QrScan_Company_Time' AND object_id=OBJECT_ID('ops.QrScanLog'))
    CREATE INDEX IX_QrScan_Company_Time ON ops.QrScanLog (CompanyID, Scantime DESC)
        INCLUDE (QrID, EmpID, UnitID, IsWithinRange, DistanceMeters, ImageUrl);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_QrScan_Unit_Time' AND object_id=OBJECT_ID('ops.QrScanLog'))
    CREATE INDEX IX_QrScan_Unit_Time ON ops.QrScanLog (CompanyID, UnitID, Scantime DESC)
        INCLUDE (QrID, EmpID, RoundID, IsWithinRange);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_QrCheckpoint_Unit' AND object_id=OBJECT_ID('ops.QrCheckpoint'))
    CREATE INDEX IX_QrCheckpoint_Unit ON ops.QrCheckpoint (CompanyID, UnitID)
        INCLUDE (Name, Latitude, Longitude, MaxDistanceMeters, RequirePhoto) WHERE IsActive = 1 AND IsCancel = 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_LocationLog_User_Time' AND object_id=OBJECT_ID('ops.LocationLog'))
    CREATE INDEX IX_LocationLog_User_Time ON ops.LocationLog (CompanyID, UserID, LoggedAt DESC)
        INCLUDE (Latitude, Longitude, Accuracy, BatteryLevel);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_LocationLog_Company_Time' AND object_id=OBJECT_ID('ops.LocationLog'))
    CREATE INDEX IX_LocationLog_Company_Time ON ops.LocationLog (CompanyID, LoggedAt DESC)
        INCLUDE (UserID, EmpID, Latitude, Longitude);
GO

/*==============================  PEOPLE  ===================================*/
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Employee_Company_Unit_Status' AND object_id=OBJECT_ID('hr.Employee'))
    CREATE INDEX IX_Employee_Company_Unit_Status ON hr.Employee (CompanyID, UnitID, EmpStatus)
        INCLUDE (EmpCode, FirstName, LastName, DesignationID, Mobile1, Photo, BeltNo);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Employee_Company_Branch' AND object_id=OBJECT_ID('hr.Employee'))
    CREATE INDEX IX_Employee_Company_Branch ON hr.Employee (CompanyID, BranchID, EmpStatus)
        INCLUDE (EmpID, EmpCode, EmpFullName, DesignationID, UnitID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Employee_Name' AND object_id=OBJECT_ID('hr.Employee'))
    CREATE INDEX IX_Employee_Name ON hr.Employee (CompanyID, EmpFullName) INCLUDE (EmpCode, Mobile1, UnitID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Employee_Mobile' AND object_id=OBJECT_ID('hr.Employee'))
    CREATE INDEX IX_Employee_Mobile ON hr.Employee (CompanyID, Mobile1) WHERE Mobile1 IS NOT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_EmployeeStatutory_Aadhaar' AND object_id=OBJECT_ID('hr.EmployeeStatutory'))
    CREATE INDEX IX_EmployeeStatutory_Aadhaar ON hr.EmployeeStatutory (CompanyID, AdharCardNo) WHERE AdharCardNo IS NOT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Recruit_Company_Status' AND object_id=OBJECT_ID('hr.Recruit'))
    CREATE INDEX IX_Recruit_Company_Status ON hr.Recruit (CompanyID, Status, Dated DESC)
        INCLUDE (Name, Mobile, DesignationID, BranchID) WHERE IsCancel = 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_EmpStatusHistory_Emp' AND object_id=OBJECT_ID('hr.EmployeeStatusHistory'))
    CREATE INDEX IX_EmpStatusHistory_Emp ON hr.EmployeeStatusHistory (CompanyID, EmpID, EventDate DESC) INCLUDE (EventType, Remark);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_EmployeeRequest_Pending' AND object_id=OBJECT_ID('hr.EmployeeRequest'))
    CREATE INDEX IX_EmployeeRequest_Pending ON hr.EmployeeRequest (CompanyID, Status, InsertDate DESC)
        INCLUDE (EmpID, RequestType, Amount, FromDate, ToDate) WHERE Status = N'Pending';
GO

/*===========================  DEPLOYMENT  ==================================*/
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Deployment_Unit_Active' AND object_id=OBJECT_ID('ops.Deployment'))
    CREATE INDEX IX_Deployment_Unit_Active ON ops.Deployment (CompanyID, UnitID, Status)
        INCLUDE (EmpID, ShiftID, PostID, FromDate, ToDate, IsReliever);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Deployment_Emp' AND object_id=OBJECT_ID('ops.Deployment'))
    CREATE INDEX IX_Deployment_Emp ON ops.Deployment (CompanyID, EmpID, FromDate DESC) INCLUDE (UnitID, PostID, ShiftID, Status);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Turnout_Company_Date' AND object_id=OBJECT_ID('ops.Turnout'))
    CREATE INDEX IX_Turnout_Company_Date ON ops.Turnout (CompanyID, TurnoutDate DESC)
        INCLUDE (UnitID, ShiftID, RequiredNos, PresentNos, AbsentNos, RelieverNos);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Movement_Company_Date' AND object_id=OBJECT_ID('ops.Movement'))
    CREATE INDEX IX_Movement_Company_Date ON ops.Movement (CompanyID, MovementDate DESC) INCLUDE (EmpID, FromUnitID, ToUnitID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_UnitPost_Unit' AND object_id=OBJECT_ID('crm.UnitPost'))
    CREATE INDEX IX_UnitPost_Unit ON crm.UnitPost (CompanyID, UnitID)
        INCLUDE (PostName, DesignationID, ShiftID, RequiredStrength, RatePerGuard) WHERE IsActive = 1 AND IsCancel = 0;
GO

/*==============================  TASKS  ====================================*/
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Task_AssignedTo_Status' AND object_id=OBJECT_ID('ops.Task'))
    CREATE INDEX IX_Task_AssignedTo_Status ON ops.Task (CompanyID, Assignedto, TaskStatusID, EndDate)
        INCLUDE (Heading, PriorityID, Assignedby, Isread, Isclosed, StartDate);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Task_AssignedBy' AND object_id=OBJECT_ID('ops.Task'))
    CREATE INDEX IX_Task_AssignedBy ON ops.Task (CompanyID, Assignedby, InsertDate DESC)
        INCLUDE (Heading, Assignedto, TaskStatusID, PriorityID, Isclosed);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_TaskStatusHistory_Task' AND object_id=OBJECT_ID('ops.TaskStatusHistory'))
    CREATE INDEX IX_TaskStatusHistory_Task ON ops.TaskStatusHistory (TaskID, ChangedOn DESC);
GO

/*=====================  INCIDENTS / COMPLAINTS / GATE  =====================*/
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Complaint_Open' AND object_id=OBJECT_ID('ops.Complaint'))
    CREATE INDEX IX_Complaint_Open ON ops.Complaint (CompanyID, IsClosed, InsertDate DESC)
        INCLUDE (UnitID, ClientID, ComplaintTypeID, AssignedToEmpID, DueOn, Status);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Complaint_Sla' AND object_id=OBJECT_ID('ops.Complaint'))
    CREATE INDEX IX_Complaint_Sla ON ops.Complaint (CompanyID, DueOn) INCLUDE (UnitID, Status, AssignedToEmpID)
        WHERE IsClosed = 0 AND IsCancel = 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Incident_Company_Date' AND object_id=OBJECT_ID('ops.Incident'))
    CREATE INDEX IX_Incident_Company_Date ON ops.Incident (CompanyID, IncidentDate DESC)
        INCLUDE (UnitID, EmpID, IncidentTypeID, Severity, IsClosed);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_FieldReport_Company_Date' AND object_id=OBJECT_ID('ops.FieldReport'))
    CREATE INDEX IX_FieldReport_Company_Date ON ops.FieldReport (CompanyID, Createdate DESC) INCLUDE (UnitID, SupervisorEmpID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_GatePass_Unit_Date' AND object_id=OBJECT_ID('ops.GatePass'))
    CREATE INDEX IX_GatePass_Unit_Date ON ops.GatePass (CompanyID, UnitID, Dated DESC)
        INCLUDE (Name, MobileNo, VehicleNo, InTime, OutTime);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_GatePass_Inside' AND object_id=OBJECT_ID('ops.GatePass'))
    CREATE INDEX IX_GatePass_Inside ON ops.GatePass (CompanyID, UnitID) INCLUDE (Name, MobileNo, InTime)
        WHERE OutTime IS NULL AND IsCancel = 0;
GO

/*===============================  CRM  =====================================*/
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Unit_Company_Client' AND object_id=OBJECT_ID('crm.Unit'))
    CREATE INDEX IX_Unit_Company_Client ON crm.Unit (CompanyID, ClientID)
        INCLUDE (UnitName, BranchID, Latitude, Longitude, GeofenceRadiusMeters, IsActive);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Unit_AgreementExpiry' AND object_id=OBJECT_ID('crm.Unit'))
    CREATE INDEX IX_Unit_AgreementExpiry ON crm.Unit (CompanyID, AgreementExpDate)
        INCLUDE (UnitName, ClientID, OrderExpiryDate) WHERE AgreementExpDate IS NOT NULL AND IsCancel = 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_FollowUp_Next' AND object_id=OBJECT_ID('crm.FollowUp'))
    CREATE INDEX IX_FollowUp_Next ON crm.FollowUp (CompanyID, NextFollowupDate)
        INCLUDE (EmpID, CompanyName, ContactPerson, ContactNo, Purpose) WHERE StopFollow = 0 AND IsCancel = 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_SalesVisit_Emp_Date' AND object_id=OBJECT_ID('crm.SalesVisit'))
    CREATE INDEX IX_SalesVisit_Emp_Date ON crm.SalesVisit (CompanyID, EmpID, VisitDate DESC) INCLUDE (CompanyName, Purpose);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Contract_Company_Date' AND object_id=OBJECT_ID('crm.Contract'))
    CREATE INDEX IX_Contract_Company_Date ON crm.Contract (CompanyID, ContractType, Dated DESC) INCLUDE (ClientID, UnitID, Nop, Status);
GO

/*=========================  FINANCE / INVENTORY  ===========================*/
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Salary_Run' AND object_id=OBJECT_ID('fin.Salary'))
    CREATE INDEX IX_Salary_Run ON fin.Salary (RunID, EmpID) INCLUDE (NetPayble, TotalEarnings, DeductionAmt, UnitID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Salary_Emp_Month' AND object_id=OBJECT_ID('fin.Salary'))
    CREATE INDEX IX_Salary_Emp_Month ON fin.Salary (CompanyID, EmpID, MonthYear DESC) INCLUDE (NetPayble, TotalEarnings, DeductionAmt);
GO
-- Open advances. Filtering on BalanceAmount rather than a status IN-list keeps
-- the predicate legal for a filtered index and is the condition payroll cares about.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Advance_Emp_Open' AND object_id=OBJECT_ID('fin.Advance'))
    CREATE INDEX IX_Advance_Emp_Open ON fin.Advance (CompanyID, EmpID)
        INCLUDE (Amount, BalanceAmount, InstallmentAmount, Status)
        WHERE BalanceAmount > 0 AND IsCancel = 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Invoice_Client_Status' AND object_id=OBJECT_ID('fin.Invoice'))
    CREATE INDEX IX_Invoice_Client_Status ON fin.Invoice (CompanyID, ClientID, Status)
        INCLUDE (InvoiceNo, InvoiceDate, DueDate, GrandTotal, ReceivedAmount);
GO
-- Ageing. Status leads the key instead of being a filter predicate, so the
-- unpaid statuses seek together without needing an illegal IN-list filter.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Invoice_Ageing' AND object_id=OBJECT_ID('fin.Invoice'))
    CREATE INDEX IX_Invoice_Ageing ON fin.Invoice (CompanyID, Status, DueDate)
        INCLUDE (ClientID, InvoiceNo, GrandTotal, ReceivedAmount);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_EmployeeIssue_Emp' AND object_id=OBJECT_ID('inv.EmployeeIssue'))
    CREATE INDEX IX_EmployeeIssue_Emp ON inv.EmployeeIssue (CompanyID, EmpID)
        INCLUDE (ItemID, IssuedQty, RecievedQty, Rate, RecoverInSalary, RecoveredAmount);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_StockTxn_Item_Date' AND object_id=OBJECT_ID('inv.StockTxn'))
    CREATE INDEX IX_StockTxn_Item_Date ON inv.StockTxn (CompanyID, ItemID, TxnDate DESC) INCLUDE (TxnType, Qty, Amount, EmpID);
GO

/*======================  DOCUMENTS / COMMS / AUDIT  ========================*/
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Document_Expiry' AND object_id=OBJECT_ID('doc.Document'))
    CREATE INDEX IX_Document_Expiry ON doc.Document (CompanyID, ExpiryDate)
        INCLUDE (OwnerType, OwnerID, DocTypeID, DocumentFilename) WHERE ExpiryDate IS NOT NULL AND IsCancel = 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Document_Owner' AND object_id=OBJECT_ID('doc.Document'))
    CREATE INDEX IX_Document_Owner ON doc.Document (CompanyID, OwnerType, OwnerID)
        INCLUDE (DocTypeID, BlobUrl, ExpiryDate, IsVerified);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Notification_User_Unread' AND object_id=OBJECT_ID('doc.Notification'))
    CREATE INDEX IX_Notification_User_Unread ON doc.Notification (CompanyID, UserID, InsertDate DESC)
        INCLUDE (Title, Body, Category, DeepLink) WHERE IsRead = 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_ChatMessage_Thread' AND object_id=OBJECT_ID('doc.ChatMessage'))
    CREATE INDEX IX_ChatMessage_Thread ON doc.ChatMessage (ThreadID, SentAt DESC) INCLUDE (FromUserID, Body, MessageType, ReadAt);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_AuditLog_Table_Record' AND object_id=OBJECT_ID('aud.AuditLog'))
    CREATE INDEX IX_AuditLog_Table_Record ON aud.AuditLog (CompanyID, TableName, RecordID, ChangedAt DESC);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_AuditLog_Company_Time' AND object_id=OBJECT_ID('aud.AuditLog'))
    CREATE INDEX IX_AuditLog_Company_Time ON aud.AuditLog (CompanyID, ChangedAt DESC) INCLUDE (UserID, TableName, [Action]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_ApiRequestLog_Time' AND object_id=OBJECT_ID('aud.ApiRequestLog'))
    CREATE INDEX IX_ApiRequestLog_Time ON aud.ApiRequestLog (RequestedAt DESC) INCLUDE (CompanyID, StatusCode, DurationMs, Path);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_LoginLog_Company_Time' AND object_id=OBJECT_ID('sec.LoginLog'))
    CREATE INDEX IX_LoginLog_Company_Time ON sec.LoginLog (CompanyID, LoginAt DESC) INCLUDE (UserID, IsSuccess, Platform, AppVersion);
GO

PRINT '200_indexes.sql  ->  OK';
GO
