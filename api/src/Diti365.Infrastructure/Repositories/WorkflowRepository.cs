using Diti365.Contracts.Common;
using Diti365.Infrastructure.Data;

namespace Diti365.Infrastructure.Repositories;

using Row = IReadOnlyDictionary<string, object?>;

/// <summary>Tasks, incidents, field reports, complaints, gate pass, HR lifecycle and uniform.</summary>
public interface IWorkflowRepository
{
    Task<PagedResult<Row>> GetFieldReportsAsync(int? unitId, int? branchId, string? search, DateOnly? from, DateOnly? to, int page, int pageSize, CancellationToken ct);
    Task<PagedResult<Row>> GetRequestsAsync(int? empId, string? requestType, string? status, string? search, DateOnly? from, DateOnly? to, int page, int pageSize, CancellationToken ct);
    // tasks
    Task<SpResult> CreateTaskAsync(string heading, int assignedTo, string? description, int? unitId,
                                   DateOnly? start, DateOnly? end, TimeOnly? startTime, TimeOnly? endTime,
                                   int? priorityId, int? repetitionId, string? attachment, bool important,
                                   IEnumerable<string>? checklist, int? parentTaskId, CancellationToken ct);
    Task<SpResult> UpdateTaskStatusAsync(int taskId, int statusId, string? remark, string? attachment, CancellationToken ct);
    Task<PagedResult<Row>> GetTasksAsync(string mode, int? statusId, int? priorityId, int? unitId,
                                         bool onlyOverdue, string? search, int page, int pageSize, CancellationToken ct);
    Task<IReadOnlyList<IReadOnlyList<Row>>> GetTaskDetailAsync(int taskId, CancellationToken ct);
    Task<SpResult> MarkTaskReadAsync(int taskId, CancellationToken ct);
    Task<SpResult> ToggleChecklistAsync(int checklistId, bool isDone, CancellationToken ct);
    Task<SpResult> DeleteTaskAsync(int taskId, CancellationToken ct);

    // incidents and field reports
    Task<SpResult> CreateIncidentAsync(int unitId, int? typeId, DateOnly? date, TimeOnly? time, int? empId,
                                       string? beltNo, string? fullName, byte? severity, string? remark,
                                       string? actionTaken, string? photoUrl, decimal? lat, decimal? lon,
                                       Guid? clientRequestId, CancellationToken ct);
    Task<SpResult> CloseIncidentAsync(int incidentId, string actionTaken, CancellationToken ct);
    Task<SpResult> CreateFieldReportAsync(int unitId, string? contactPerson, string? remark, decimal? lat,
                                          decimal? lon, string? photoUrl, Guid? clientRequestId,
                                          string? empRemarksJson, CancellationToken ct);
    Task<IReadOnlyList<IReadOnlyList<Row>>> GetFieldReportAsync(int reportId, CancellationToken ct);
    Task<IReadOnlyList<Row>> GetReportCountsAsync(DateOnly? onDate, CancellationToken ct);

    // complaints
    Task<SpResult> CreateComplaintAsync(int unitId, string description, int? typeId, int? clientId,
                                        string? photoUrl, Guid? clientRequestId, CancellationToken ct);
    Task<SpResult> UpdateComplaintAsync(int complaintId, string status, string? remark, int? assignedToEmpId, CancellationToken ct);
    Task<PagedResult<Row>> GetComplaintsAsync(int? unitId, int? clientId, string? status, bool? isClosed,
                                              bool onlySlaBreached, DateOnly? from, DateOnly? to,
                                              int page, int pageSize, CancellationToken ct);

    // gate pass
    Task<SpResult> CreateGatePassAsync(int unitId, string name, string? mobile, string? purpose, string? whomToMeet,
                                       string? vehicleNo, string? materials, string? imageUrl,
                                       Guid? clientRequestId, CancellationToken ct);
    Task<SpResult> GatePassExitAsync(int gatePassId, CancellationToken ct);
    Task<PagedResult<Row>> GetGatePassesAsync(int? unitId, DateOnly? from, DateOnly? to, bool onlyInside,
                                              string? search, int page, int pageSize, CancellationToken ct);

    // HR lifecycle
    Task<SpResult> LifecycleEventAsync(int empId, string eventType, DateOnly eventDate, string? timing,
                                       string? remark, string? docUrl, CancellationToken ct);
    Task<PagedResult<Row>> LifecycleReportAsync(string? eventType, DateOnly? from, DateOnly? to, int? branchId,
                                                int page, int pageSize, CancellationToken ct);
    Task<SpResult> SaveTrainingAsync(int? unitId, DateOnly dated, string? timing, string? topic, string? remark,
                                     string? photoUrl, IEnumerable<int>? attendees, int? trainingId, CancellationToken ct);
    Task<SpResult> CreateRequestAsync(string requestType, DateOnly? from, DateOnly? to, decimal? amount, string? reason, CancellationToken ct);
    Task<SpResult> ApproveRequestAsync(int requestId, bool approve, string? remark, CancellationToken ct);
    Task<SpResult> CreateSuggestionAsync(string? subject, string description, CancellationToken ct);

    // uniform
    Task<SpResult> StockInAsync(int branchId, int itemId, decimal qty, decimal rate, string? refNo, string? remark, CancellationToken ct);
    Task<SpResult> IssueUniformAsync(int empId, int itemId, decimal qty, decimal? rate, bool recoverInSalary, string? remark, CancellationToken ct);
    Task<SpResult> ReturnUniformAsync(int issueId, decimal qty, string? remark, CancellationToken ct);
    Task<IReadOnlyList<Row>> GetStockAsync(int? branchId, CancellationToken ct);
    Task<PagedResult<Row>> GetUniformLedgerAsync(int? empId, int? branchId, int page, int pageSize, CancellationToken ct);

    // documents
    Task<SpResult> SaveDocumentAsync(string ownerType, int ownerId, string blobUrl, int? docTypeId, string? fileName,
                                     string? mimeType, long? sizeBytes, DateOnly? issueDate, DateOnly? expiryDate,
                                     string? remark, CancellationToken ct);
    Task<PagedResult<Row>> GetExpiringDocumentsAsync(int withinDays, int page, int pageSize, CancellationToken ct);

    // advances
    Task<SpResult> CreateAdvanceAsync(int empId, decimal amount, decimal? installment, string? reason, DateOnly? issueDate, CancellationToken ct);
    Task<SpResult> ApproveAdvanceAsync(int advanceId, bool approve, string? remark, CancellationToken ct);
}

public sealed class WorkflowRepository(IDbExecutor db) : IWorkflowRepository
{
    /// <summary>Supervisor site visits, newest first.</summary>
    public Task<PagedResult<Row>> GetFieldReportsAsync(int? unitId, int? branchId, string? search,
                                                       DateOnly? from, DateOnly? to,
                                                       int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_FieldReport_GetList", p =>
        {
            p.Add(P.Int ("@UnitID",   unitId));
            p.Add(P.Int ("@BranchID", branchId));
            p.Add(P.NVar("@Search",   search, 200));
            p.Add(P.Date("@From",     from));
            p.Add(P.Date("@To",       to));
            p.Add(P.Int ("@PageNo",   page));
            p.Add(P.Int ("@PageSize", pageSize));
        }, Map.Dynamic, ct);

    /// <summary>Leave, advance, transfer and uniform requests. Pending first.</summary>
    public Task<PagedResult<Row>> GetRequestsAsync(int? empId, string? requestType, string? status,
                                                   string? search, DateOnly? from, DateOnly? to,
                                                   int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Request_GetList", p =>
        {
            p.Add(P.Int ("@EmpID",       empId));
            p.Add(P.NVar("@RequestType", requestType, 30));
            p.Add(P.NVar("@Status",      status, 20));
            p.Add(P.NVar("@Search",      search, 200));
            p.Add(P.Date("@From",        from));
            p.Add(P.Date("@To",          to));
            p.Add(P.Int ("@PageNo",      page));
            p.Add(P.Int ("@PageSize",    pageSize));
        }, Map.Dynamic, ct);

    public Task<SpResult> CreateTaskAsync(string heading, int assignedTo, string? description, int? unitId,
                                          DateOnly? start, DateOnly? end, TimeOnly? startTime, TimeOnly? endTime,
                                          int? priorityId, int? repetitionId, string? attachment, bool important,
                                          IEnumerable<string>? checklist, int? parentTaskId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Task_Insert", p =>
        {
            p.Add(P.NVar   ("@Heading",       heading, 200));
            p.Add(P.Int    ("@Assignedto",    assignedTo));
            p.Add(P.NVarMax("@Description",   description));
            p.Add(P.Int    ("@UnitID",        unitId));
            p.Add(P.Date   ("@StartDate",     start));
            p.Add(P.Date   ("@EndDate",       end));
            p.Add(P.Time   ("@StartTime",     startTime));
            p.Add(P.Time   ("@EndTime",       endTime));
            p.Add(P.Int    ("@PriorityID",    priorityId));
            p.Add(P.Int    ("@RepetitionId",  repetitionId));
            p.Add(P.NVar   ("@Attachment",    attachment, 500));
            p.Add(P.Bit    ("@Important",     important));
            p.Add(P.NVarMax("@ChecklistJson", checklist is null ? null
                              : System.Text.Json.JsonSerializer.Serialize(checklist)));
            p.Add(P.Int    ("@ParentTaskID",  parentTaskId));
        }, ct);

    public Task<SpResult> UpdateTaskStatusAsync(int taskId, int statusId, string? remark, string? attachment, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Task_UpdateStatus", p =>
        {
            p.Add(P.Int    ("@TaskID",       taskId));
            p.Add(P.Int    ("@TaskStatusID", statusId));
            p.Add(P.NVarMax("@Remark",       remark));
            p.Add(P.NVar   ("@Attachment",   attachment, 500));
        }, ct);

    public Task<PagedResult<Row>> GetTasksAsync(string mode, int? statusId, int? priorityId, int? unitId,
                                                bool onlyOverdue, string? search, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Task_GetList", p =>
        {
            p.Add(P.NVar("@Mode",         mode, 10));
            p.Add(P.Int ("@TaskStatusID", statusId));
            p.Add(P.Int ("@PriorityID",   priorityId));
            p.Add(P.Int ("@UnitID",       unitId));
            p.Add(P.Bit ("@OnlyOverdue",  onlyOverdue));
            p.Add(P.NVar("@Search",       search, 200));
            p.Add(P.Int ("@PageNo",       page));
            p.Add(P.Int ("@PageSize",     pageSize));
        }, Map.Dynamic, ct);

    public Task<IReadOnlyList<IReadOnlyList<Row>>> GetTaskDetailAsync(int taskId, CancellationToken ct) =>
        Multi("dbo.usp_Task_GetDetail", p => p.Add(P.Int("@TaskID", taskId)), ct);

    public Task<SpResult> MarkTaskReadAsync(int taskId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Task_MarkRead", p => p.Add(P.Int("@TaskID", taskId)), ct);

    public Task<SpResult> ToggleChecklistAsync(int checklistId, bool isDone, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Task_ToggleChecklist", p =>
        {
            p.Add(P.Int("@ChecklistID", checklistId));
            p.Add(P.Bit("@IsDone",      isDone));
        }, ct);

    public Task<SpResult> DeleteTaskAsync(int taskId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Task_Delete", p => p.Add(P.Int("@TaskID", taskId)), ct);

    public Task<SpResult> CreateIncidentAsync(int unitId, int? typeId, DateOnly? date, TimeOnly? time, int? empId,
                                              string? beltNo, string? fullName, byte? severity, string? remark,
                                              string? actionTaken, string? photoUrl, decimal? lat, decimal? lon,
                                              Guid? clientRequestId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Incident_Insert", p =>
        {
            p.Add(P.Int    ("@UnitID",          unitId));
            p.Add(P.Int    ("@IncidentTypeID",  typeId));
            p.Add(P.Date   ("@IncidentDate",    date));
            p.Add(P.Time   ("@IncidentTime",    time));
            p.Add(P.Int    ("@EmpID",           empId));
            p.Add(P.NVar   ("@BeltNo",          beltNo, 30));
            p.Add(P.NVar   ("@FullName",        fullName, 200));
            p.Add(P.TinyInt("@Severity",        severity));
            p.Add(P.NVarMax("@Remark",          remark));
            p.Add(P.NVarMax("@ActionTaken",     actionTaken));
            p.Add(P.NVar   ("@PhotoUrl",        photoUrl, 500));
            p.Add(P.Coord  ("@Latitude",        lat));
            p.Add(P.Coord  ("@Longitude",       lon));
            p.Add(P.Guid   ("@ClientRequestId", clientRequestId));
        }, ct);

    public Task<SpResult> CloseIncidentAsync(int incidentId, string actionTaken, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Incident_Close", p =>
        {
            p.Add(P.Int    ("@IncidentID",  incidentId));
            p.Add(P.NVarMax("@ActionTaken", actionTaken));
        }, ct);

    public Task<SpResult> CreateFieldReportAsync(int unitId, string? contactPerson, string? remark, decimal? lat,
                                                 decimal? lon, string? photoUrl, Guid? clientRequestId,
                                                 string? empRemarksJson, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_FieldReport_Insert", p =>
        {
            p.Add(P.Int    ("@UnitID",          unitId));
            p.Add(P.NVar   ("@ContactPerson",   contactPerson, 150));
            p.Add(P.NVarMax("@Remark",          remark));
            p.Add(P.Coord  ("@Latitude",        lat));
            p.Add(P.Coord  ("@Longitude",       lon));
            p.Add(P.NVar   ("@PhotoUrl",        photoUrl, 500));
            p.Add(P.Guid   ("@ClientRequestId", clientRequestId));
            p.Add(P.NVarMax("@EmpRemarksJson",  empRemarksJson));
        }, ct);

    public Task<IReadOnlyList<IReadOnlyList<Row>>> GetFieldReportAsync(int reportId, CancellationToken ct) =>
        Multi("dbo.usp_FieldReport_GetDetail", p => p.Add(P.Int("@ReportID", reportId)), ct);

    public Task<IReadOnlyList<Row>> GetReportCountsAsync(DateOnly? onDate, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Report_GetCounts", p => p.Add(P.Date("@OnDate", onDate)), Map.Dynamic, ct);

    public Task<SpResult> CreateComplaintAsync(int unitId, string description, int? typeId, int? clientId,
                                               string? photoUrl, Guid? clientRequestId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Complaint_Insert", p =>
        {
            p.Add(P.Int    ("@UnitID",          unitId));
            p.Add(P.NVarMax("@Description",     description));
            p.Add(P.Int    ("@ComplaintTypeID", typeId));
            p.Add(P.Int    ("@ClientID",        clientId));
            p.Add(P.NVar   ("@PhotoUrl",        photoUrl, 500));
            p.Add(P.Guid   ("@ClientRequestId", clientRequestId));
        }, ct);

    public Task<SpResult> UpdateComplaintAsync(int complaintId, string status, string? remark, int? assignedToEmpId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Complaint_UpdateStatus", p =>
        {
            p.Add(P.Int    ("@ComplaintID",     complaintId));
            p.Add(P.NVar   ("@Status",          status, 20));
            p.Add(P.NVarMax("@Remark",          remark));
            p.Add(P.Int    ("@AssignedToEmpID", assignedToEmpId));
        }, ct);

    public Task<PagedResult<Row>> GetComplaintsAsync(int? unitId, int? clientId, string? status, bool? isClosed,
                                                     bool onlySlaBreached, DateOnly? from, DateOnly? to,
                                                     int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Complaint_GetList", p =>
        {
            p.Add(P.Int ("@UnitID",          unitId));
            p.Add(P.Int ("@ClientID",        clientId));
            p.Add(P.NVar("@Status",          status, 20));
            p.Add(P.Bit ("@IsClosed",        isClosed));
            p.Add(P.Bit ("@OnlySlaBreached", onlySlaBreached));
            p.Add(P.Date("@FromDate",        from));
            p.Add(P.Date("@ToDate",          to));
            p.Add(P.Int ("@PageNo",          page));
            p.Add(P.Int ("@PageSize",        pageSize));
        }, Map.Dynamic, ct);

    public Task<SpResult> CreateGatePassAsync(int unitId, string name, string? mobile, string? purpose, string? whomToMeet,
                                              string? vehicleNo, string? materials, string? imageUrl,
                                              Guid? clientRequestId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_GatePass_Insert", p =>
        {
            p.Add(P.Int ("@UnitID",          unitId));
            p.Add(P.NVar("@Name",            name, 200));
            p.Add(P.NVar("@MobileNo",        mobile, 15));
            p.Add(P.NVar("@Purpose",         purpose, 300));
            p.Add(P.NVar("@WhomToMeet",      whomToMeet, 200));
            p.Add(P.NVar("@VehicleNo",       vehicleNo, 30));
            p.Add(P.NVar("@MaterialDetails", materials, 1000));
            p.Add(P.NVar("@VisitorImage",    imageUrl, 500));
            p.Add(P.Guid("@ClientRequestId", clientRequestId));
        }, ct);

    public Task<SpResult> GatePassExitAsync(int gatePassId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_GatePass_Exit", p => p.Add(P.Int("@GatePassID", gatePassId)), ct);

    public Task<PagedResult<Row>> GetGatePassesAsync(int? unitId, DateOnly? from, DateOnly? to, bool onlyInside,
                                                     string? search, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_GatePass_GetList", p =>
        {
            p.Add(P.Int ("@UnitID",     unitId));
            p.Add(P.Date("@FromDate",   from));
            p.Add(P.Date("@ToDate",     to));
            p.Add(P.Bit ("@OnlyInside", onlyInside));
            p.Add(P.NVar("@Search",     search, 200));
            p.Add(P.Int ("@PageNo",     page));
            p.Add(P.Int ("@PageSize",   pageSize));
        }, Map.Dynamic, ct);

    public Task<SpResult> LifecycleEventAsync(int empId, string eventType, DateOnly eventDate, string? timing,
                                              string? remark, string? docUrl, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Hr_LifecycleEvent", p =>
        {
            p.Add(P.Int ("@EmpID",     empId));
            p.Add(P.NVar("@EventType", eventType, 20));
            p.Add(P.Date("@EventDate", eventDate));
            p.Add(P.NVar("@Timing",    timing, 50));
            p.Add(P.NVar("@Remark",    remark, 500));
            p.Add(P.NVar("@DocUrl",    docUrl, 500));
        }, ct);

    public Task<PagedResult<Row>> LifecycleReportAsync(string? eventType, DateOnly? from, DateOnly? to, int? branchId,
                                                       int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Hr_LifecycleReport", p =>
        {
            p.Add(P.NVar("@EventType", eventType, 20));
            p.Add(P.Date("@FromDate",  from));
            p.Add(P.Date("@ToDate",    to));
            p.Add(P.Int ("@BranchID",  branchId));
            p.Add(P.Int ("@PageNo",    page));
            p.Add(P.Int ("@PageSize",  pageSize));
        }, Map.Dynamic, ct);

    public Task<SpResult> SaveTrainingAsync(int? unitId, DateOnly dated, string? timing, string? topic, string? remark,
                                            string? photoUrl, IEnumerable<int>? attendees, int? trainingId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Training_Save", p =>
        {
            p.Add(P.Int    ("@UnitID",         unitId));
            p.Add(P.Date   ("@Dated",          dated));
            p.Add(P.NVar   ("@Timing",         timing, 50));
            p.Add(P.NVar   ("@Topic",          topic, 200));
            p.Add(P.NVar   ("@Remark",         remark, 500));
            p.Add(P.NVar   ("@PhotoUrl",       photoUrl, 500));
            p.Add(P.NVarMax("@AttendeeIdsCsv", attendees is null ? null : string.Join(',', attendees)));
            p.Add(P.Int    ("@TrainingID",     trainingId));
        }, ct);

    public Task<SpResult> CreateRequestAsync(string requestType, DateOnly? from, DateOnly? to, decimal? amount, string? reason, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Request_Insert", p =>
        {
            p.Add(P.NVar ("@RequestType", requestType, 20));
            p.Add(P.Date ("@FromDate",    from));
            p.Add(P.Date ("@ToDate",      to));
            p.Add(P.Money("@Amount",      amount));
            p.Add(P.NVar ("@Reason",      reason, 500));
        }, ct);

    public Task<SpResult> ApproveRequestAsync(int requestId, bool approve, string? remark, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Request_Approve", p =>
        {
            p.Add(P.Int ("@RequestID", requestId));
            p.Add(P.Bit ("@Approve",   approve));
            p.Add(P.NVar("@Remark",    remark, 500));
        }, ct);

    public Task<SpResult> CreateSuggestionAsync(string? subject, string description, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Suggestion_Insert", p =>
        {
            p.Add(P.NVar("@Subject",     subject, 200));
            p.Add(P.NVar("@Description", description, 1000));
        }, ct);

    public Task<SpResult> StockInAsync(int branchId, int itemId, decimal qty, decimal rate, string? refNo, string? remark, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Uniform_StockIn", p =>
        {
            p.Add(P.Int  ("@BranchID", branchId));
            p.Add(P.Int  ("@ItemID",   itemId));
            p.Add(P.Dec  ("@Qty",      qty, 18, 2));
            p.Add(P.Money("@Rate",     rate));
            p.Add(P.NVar ("@RefNo",    refNo, 50));
            p.Add(P.NVar ("@Remark",   remark, 500));
        }, ct);

    public Task<SpResult> IssueUniformAsync(int empId, int itemId, decimal qty, decimal? rate, bool recoverInSalary, string? remark, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Uniform_IssueToEmployee", p =>
        {
            p.Add(P.Int  ("@EmpID",           empId));
            p.Add(P.Int  ("@ItemID",          itemId));
            p.Add(P.Dec  ("@Qty",             qty, 18, 2));
            p.Add(P.Money("@Rate",            rate));
            p.Add(P.Bit  ("@RecoverInSalary", recoverInSalary));
            p.Add(P.NVar ("@Remark",          remark, 500));
        }, ct);

    public Task<SpResult> ReturnUniformAsync(int issueId, decimal qty, string? remark, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Uniform_ReturnFromEmployee", p =>
        {
            p.Add(P.Int ("@IssueID", issueId));
            p.Add(P.Dec ("@Qty",     qty, 18, 2));
            p.Add(P.NVar("@Remark",  remark, 500));
        }, ct);

    public Task<IReadOnlyList<Row>> GetStockAsync(int? branchId, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Uniform_GetStock", p => p.Add(P.Int("@BranchID", branchId)), Map.Dynamic, ct);

    public Task<PagedResult<Row>> GetUniformLedgerAsync(int? empId, int? branchId, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Uniform_GetLedger", p =>
        {
            p.Add(P.Int("@EmpID",    empId));
            p.Add(P.Int("@BranchID", branchId));
            p.Add(P.Int("@PageNo",   page));
            p.Add(P.Int("@PageSize", pageSize));
        }, Map.Dynamic, ct);

    public Task<SpResult> SaveDocumentAsync(string ownerType, int ownerId, string blobUrl, int? docTypeId, string? fileName,
                                            string? mimeType, long? sizeBytes, DateOnly? issueDate, DateOnly? expiryDate,
                                            string? remark, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Document_Save", p =>
        {
            p.Add(P.NVar  ("@OwnerType",        ownerType, 20));
            p.Add(P.Int   ("@OwnerID",          ownerId));
            p.Add(P.NVar  ("@BlobUrl",          blobUrl, 1000));
            p.Add(P.Int   ("@DocTypeID",        docTypeId));
            p.Add(P.NVar  ("@DocumentFilename", fileName, 300));
            p.Add(P.NVar  ("@MimeType",         mimeType, 100));
            p.Add(P.BigInt("@SizeBytes",        sizeBytes));
            p.Add(P.Date  ("@IssueDate",        issueDate));
            p.Add(P.Date  ("@ExpiryDate",       expiryDate));
            p.Add(P.NVar  ("@Remark",           remark, 500));
        }, ct);

    public Task<PagedResult<Row>> GetExpiringDocumentsAsync(int withinDays, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Document_GetExpiring", p =>
        {
            p.Add(P.Int("@WithinDays", withinDays));
            p.Add(P.Int("@PageNo",     page));
            p.Add(P.Int("@PageSize",   pageSize));
        }, Map.Dynamic, ct);

    public Task<SpResult> CreateAdvanceAsync(int empId, decimal amount, decimal? installment, string? reason, DateOnly? issueDate, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Advance_Insert", p =>
        {
            p.Add(P.Int  ("@EmpID",             empId));
            p.Add(P.Money("@Amount",            amount));
            p.Add(P.Money("@InstallmentAmount", installment));
            p.Add(P.NVar ("@Reason",            reason, 500));
            p.Add(P.Date ("@IssueDate",         issueDate));
        }, ct);

    public Task<SpResult> ApproveAdvanceAsync(int advanceId, bool approve, string? remark, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Advance_Approve", p =>
        {
            p.Add(P.Int ("@AdvanceID", advanceId));
            p.Add(P.Bit ("@Approve",   approve));
            p.Add(P.NVar("@Remark",    remark, 500));
        }, ct);

    private Task<IReadOnlyList<IReadOnlyList<Row>>> Multi(
        string procedure, Action<Microsoft.Data.SqlClient.SqlParameterCollection>? parameters, CancellationToken ct) =>
        db.QueryMultipleAsync(procedure, parameters, async (reader, token) =>
        {
            var sets = new List<IReadOnlyList<Row>>();
            do
            {
                var rows = new List<Row>();
                if (reader.HasRows)
                {
                    var map = Map.Dynamic(reader);
                    while (await reader.ReadAsync(token).ConfigureAwait(false)) rows.Add(map(reader));
                }
                sets.Add(rows);
            }
            while (await reader.NextResultAsync(token).ConfigureAwait(false));
            return (IReadOnlyList<IReadOnlyList<Row>>)sets;
        }, ct);
}
