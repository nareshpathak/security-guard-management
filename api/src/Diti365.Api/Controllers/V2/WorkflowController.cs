using Diti365.Api.Controllers;
using Diti365.Api.Filters;
using Diti365.Application.Abstractions;
using Diti365.Application.Security;
using Diti365.Contracts.Common;
using Diti365.Domain;
using Diti365.Infrastructure.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace Diti365.Api.Controllers.V2;

using Row = IReadOnlyDictionary<string, object?>;

[Route("api/v2")]
public sealed class WorkflowController(ICurrentUser currentUser, IWorkflowRepository repo)
    : ApiControllerBase(currentUser)
{
    // ------------------------------------------------------------------ tasks

    [HttpGet("tasks"), HasPermission(Perm.TaskView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Tasks(
        [FromQuery] PagedQuery q, [FromQuery] string mode = "to",
        [FromQuery] int? statusId = null, [FromQuery] int? priorityId = null, [FromQuery] bool onlyOverdue = false)
    {
        var result = await repo.GetTasksAsync(mode, statusId, priorityId, q.UnitId, onlyOverdue, q.Search, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpGet("tasks/{id:int}"), HasPermission(Perm.TaskView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<IReadOnlyList<Row>>>>> Task(int id) =>
        Data(await repo.GetTaskDetailAsync(id, Ct));

    [HttpPost("tasks"), HasPermission(Perm.TaskEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> CreateTask([FromBody] TaskRequest r) =>
        Command(await repo.CreateTaskAsync(r.Heading, r.AssignedTo, r.Description, r.UnitId, r.StartDate, r.EndDate,
                                           r.StartTime, r.EndTime, r.PriorityId, r.RepetitionId, r.Attachment,
                                           r.Important, r.Checklist, r.ParentTaskId, Ct));

    /// <summary>Closing a recurring task spawns its next occurrence inside the same transaction.</summary>
    [HttpPost("tasks/{id:int}/status"), HasPermission(Perm.TaskView)]
    public async Task<ActionResult<ApiResponse<SpResult>>> UpdateTaskStatus(int id, [FromBody] TaskStatusRequest r) =>
        Command(await repo.UpdateTaskStatusAsync(id, r.TaskStatusId, r.Remark, r.Attachment, Ct));

    [HttpPost("tasks/{id:int}/read"), HasPermission(Perm.TaskView)]
    public async Task<ActionResult<ApiResponse<SpResult>>> MarkRead(int id) =>
        Command(await repo.MarkTaskReadAsync(id, Ct));

    [HttpPost("tasks/checklist/{checklistId:int}"), HasPermission(Perm.TaskView)]
    public async Task<ActionResult<ApiResponse<SpResult>>> ToggleChecklist(int checklistId, [FromBody] ToggleRequest r) =>
        Command(await repo.ToggleChecklistAsync(checklistId, r.IsDone, Ct));

    [HttpDelete("tasks/{id:int}"), HasPermission(Perm.TaskEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> DeleteTask(int id) =>
        Command(await repo.DeleteTaskAsync(id, Ct));

    // -------------------------------------------------- incidents and reports

    [HttpPost("incidents"), HasPermission(Perm.IncidentEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> CreateIncident([FromBody] IncidentRequest r) =>
        Command(await repo.CreateIncidentAsync(r.UnitId, r.IncidentTypeId, r.IncidentDate, r.IncidentTime, r.EmpId,
                                               r.BeltNo, r.FullName, r.Severity, r.Remark, r.ActionTaken,
                                               r.PhotoUrl, r.Latitude, r.Longitude, r.ClientRequestId, Ct));

    [HttpPost("incidents/{id:int}/close"), HasPermission(Perm.IncidentEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> CloseIncident(int id, [FromBody] CloseIncidentRequest r) =>
        Command(await repo.CloseIncidentAsync(id, r.ActionTaken, Ct));

    [HttpPost("field-reports"), HasPermission(Perm.IncidentEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> CreateFieldReport([FromBody] FieldReportRequest r) =>
        Command(await repo.CreateFieldReportAsync(r.UnitId, r.ContactPerson, r.Remark, r.Latitude, r.Longitude,
                                                  r.PhotoUrl, r.ClientRequestId,
                                                  r.EmpRemarks is null ? null
                                                      : System.Text.Json.JsonSerializer.Serialize(r.EmpRemarks), Ct));

    [HttpGet("field-reports"), HasPermission(Perm.IncidentView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> FieldReports([FromQuery] PagedQuery q)
    {
        var result = await repo.GetFieldReportsAsync(q.UnitId, q.BranchId, q.Search, q.From, q.To,
                                                     q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpGet("field-reports/{id:int}"), HasPermission(Perm.IncidentView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<IReadOnlyList<Row>>>>> FieldReport(int id) =>
        Data(await repo.GetFieldReportAsync(id, Ct));

    /// <summary>
    /// Daily counters for the supervisor home screen.
    /// Deliberately NOT at reports/counts - that would collide with the generic
    /// reports/{reportKey} route and give an ambiguous-match exception at runtime.
    /// </summary>
    [HttpGet("field-reports/counts")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> ReportCounts([FromQuery] DateOnly? onDate) =>
        Data(await repo.GetReportCountsAsync(onDate, Ct));

    // ------------------------------------------------------------- complaints

    [HttpGet("complaints"), HasPermission(Perm.ComplaintView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Complaints(
        [FromQuery] PagedQuery q, [FromQuery] int? clientId, [FromQuery] bool? isClosed,
        [FromQuery] bool onlySlaBreached = false)
    {
        var result = await repo.GetComplaintsAsync(q.UnitId, clientId, q.Status, isClosed,
                                                   onlySlaBreached, q.From, q.To, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpPost("complaints"), HasPermission(Perm.ComplaintEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> CreateComplaint([FromBody] ComplaintRequest r) =>
        Command(await repo.CreateComplaintAsync(r.UnitId, r.Description, r.ComplaintTypeId, r.ClientId,
                                                r.PhotoUrl, r.ClientRequestId, Ct));

    [HttpPost("complaints/{id:int}/status"), HasPermission(Perm.ComplaintEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> UpdateComplaint(int id, [FromBody] ComplaintStatusRequest r) =>
        Command(await repo.UpdateComplaintAsync(id, r.Status, r.Remark, r.AssignedToEmpId, Ct));

    // -------------------------------------------------------------- gate pass

    [HttpGet("gate-passes"), HasPermission(Perm.GatePassEdit)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> GatePasses(
        [FromQuery] PagedQuery q, [FromQuery] bool onlyInside = false)
    {
        var result = await repo.GetGatePassesAsync(q.UnitId, q.From, q.To, onlyInside, q.Search, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpPost("gate-passes"), HasPermission(Perm.GatePassEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> CreateGatePass([FromBody] GatePassRequest r) =>
        Command(await repo.CreateGatePassAsync(r.UnitId, r.Name, r.MobileNo, r.Purpose, r.WhomToMeet,
                                               r.VehicleNo, r.MaterialDetails, r.VisitorImage, r.ClientRequestId, Ct));

    [HttpPost("gate-passes/{id:int}/exit"), HasPermission(Perm.GatePassEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> GatePassExit(int id) =>
        Command(await repo.GatePassExitAsync(id, Ct));

    // ------------------------------------------------------------ HR and misc

    [HttpPost("hr/lifecycle"), HasPermission(Perm.HrEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> Lifecycle([FromBody] LifecycleRequest r) =>
        Command(await repo.LifecycleEventAsync(r.EmpId, r.EventType, r.EventDate, r.Timing, r.Remark, r.DocUrl, Ct));

    [HttpGet("hr/lifecycle"), HasPermission(Perm.HrView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> LifecycleReport(
        [FromQuery] PagedQuery q, [FromQuery] string? eventType)
    {
        var result = await repo.LifecycleReportAsync(eventType, q.From, q.To, q.BranchId, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpPost("hr/trainings"), HasPermission(Perm.HrEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SaveTraining([FromBody] TrainingRequest r) =>
        Command(await repo.SaveTrainingAsync(r.UnitId, r.Dated, r.Timing, r.Topic, r.Remark,
                                             r.PhotoUrl, r.AttendeeIds, r.TrainingId, Ct));

    [HttpPost("hr/requests")]
    public async Task<ActionResult<ApiResponse<SpResult>>> CreateRequest([FromBody] EmployeeRequestInput r) =>
        Command(await repo.CreateRequestAsync(r.RequestType, r.FromDate, r.ToDate, r.Amount, r.Reason, Ct));

    /// <summary>
    /// Leave, advance, transfer and uniform requests.
    ///
    /// Without the approve permission the caller only ever sees their own -
    /// asking for someone else's is a 403, and omitting the filter silently
    /// narrows to self rather than returning an empty list, which would look
    /// like a bug to a guard checking on his own leave.
    /// </summary>
    [HttpGet("hr/requests")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Requests(
        [FromQuery] PagedQuery q, [FromQuery] int? empId, [FromQuery] string? requestType)
    {
        if (!Me.Has(Perm.RequestApprove) && !Me.Has(Perm.HrView))
        {
            if (empId is not null && empId != Me.EmpId)
                throw DomainException.Forbidden("You may only view your own requests.");
            empId = Me.EmpId;
        }

        var result = await repo.GetRequestsAsync(empId, requestType, q.Status, q.Search, q.From, q.To,
                                                 q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpPost("hr/requests/{id:int}/approve"), HasPermission(Perm.RequestApprove)]
    public async Task<ActionResult<ApiResponse<SpResult>>> ApproveRequest(int id, [FromBody] ApproveSimpleRequest r) =>
        Command(await repo.ApproveRequestAsync(id, r.Approve, r.Remark, Ct));

    [HttpPost("hr/suggestions")]
    public async Task<ActionResult<ApiResponse<SpResult>>> CreateSuggestion([FromBody] SuggestionRequest r) =>
        Command(await repo.CreateSuggestionAsync(r.Subject, r.Description, Ct));

    // -------------------------------------------------------------- inventory

    [HttpGet("uniform/stock"), HasPermission(Perm.InventoryView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Stock([FromQuery] int? branchId) =>
        Data(await repo.GetStockAsync(branchId, Ct));

    [HttpPost("uniform/stock-in"), HasPermission(Perm.InventoryEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> StockIn([FromBody] StockInRequest r) =>
        Command(await repo.StockInAsync(r.BranchId, r.ItemId, r.Qty, r.Rate, r.RefNo, r.Remark, Ct));

    [HttpPost("uniform/issue"), HasPermission(Perm.InventoryEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> IssueUniform([FromBody] IssueUniformRequest r) =>
        Command(await repo.IssueUniformAsync(r.EmpId, r.ItemId, r.Qty, r.Rate, r.RecoverInSalary, r.Remark, Ct));

    [HttpPost("uniform/return"), HasPermission(Perm.InventoryEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> ReturnUniform([FromBody] ReturnUniformRequest r) =>
        Command(await repo.ReturnUniformAsync(r.IssueId, r.Qty, r.Remark, Ct));

    [HttpGet("uniform/ledger"), HasPermission(Perm.InventoryView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> UniformLedger(
        [FromQuery] PagedQuery q, [FromQuery] int? empId)
    {
        var result = await repo.GetUniformLedgerAsync(empId, q.BranchId, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    // -------------------------------------------------------------- documents

    [HttpPost("documents"), HasPermission(Perm.EmployeeEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SaveDocument([FromBody] DocumentRequest r) =>
        Command(await repo.SaveDocumentAsync(r.OwnerType, r.OwnerId, r.BlobUrl, r.DocTypeId, r.FileName,
                                             r.MimeType, r.SizeBytes, r.IssueDate, r.ExpiryDate, r.Remark, Ct));

    [HttpGet("documents/expiring"), HasPermission(Perm.EmployeeView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> ExpiringDocuments(
        [FromQuery] PagedQuery q, [FromQuery] int withinDays = 30)
    {
        var result = await repo.GetExpiringDocumentsAsync(withinDays, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    // --------------------------------------------------------------- advances

    [HttpPost("advances"), HasPermission(Perm.PayrollEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> CreateAdvance([FromBody] AdvanceRequest r) =>
        Command(await repo.CreateAdvanceAsync(r.EmpId, r.Amount, r.InstallmentAmount, r.Reason, r.IssueDate, Ct));

    [HttpPost("advances/{id:int}/approve"), HasPermission(Perm.PayrollApprove)]
    public async Task<ActionResult<ApiResponse<SpResult>>> ApproveAdvance(int id, [FromBody] ApproveSimpleRequest r) =>
        Command(await repo.ApproveAdvanceAsync(id, r.Approve, r.Remark, Ct));
}

public sealed record TaskRequest(string Heading, int AssignedTo, string? Description = null, int? UnitId = null,
    DateOnly? StartDate = null, DateOnly? EndDate = null, TimeOnly? StartTime = null, TimeOnly? EndTime = null,
    int? PriorityId = null, int? RepetitionId = null, string? Attachment = null, bool Important = false,
    IReadOnlyList<string>? Checklist = null, int? ParentTaskId = null);
public sealed record TaskStatusRequest(int TaskStatusId, string? Remark = null, string? Attachment = null);
public sealed record ToggleRequest(bool IsDone);
public sealed record IncidentRequest(int UnitId, int? IncidentTypeId = null, DateOnly? IncidentDate = null,
    TimeOnly? IncidentTime = null, int? EmpId = null, string? BeltNo = null, string? FullName = null,
    byte? Severity = null, string? Remark = null, string? ActionTaken = null, string? PhotoUrl = null,
    decimal? Latitude = null, decimal? Longitude = null, Guid? ClientRequestId = null);
public sealed record CloseIncidentRequest(string ActionTaken);
public sealed record EmpRemark(int EmpId, string? Remark);
public sealed record FieldReportRequest(int UnitId, string? ContactPerson = null, string? Remark = null,
    decimal? Latitude = null, decimal? Longitude = null, string? PhotoUrl = null,
    Guid? ClientRequestId = null, IReadOnlyList<EmpRemark>? EmpRemarks = null);
public sealed record ComplaintRequest(int UnitId, string Description, int? ComplaintTypeId = null,
    int? ClientId = null, string? PhotoUrl = null, Guid? ClientRequestId = null);
public sealed record ComplaintStatusRequest(string Status, string? Remark = null, int? AssignedToEmpId = null);
public sealed record GatePassRequest(int UnitId, string Name, string? MobileNo = null, string? Purpose = null,
    string? WhomToMeet = null, string? VehicleNo = null, string? MaterialDetails = null,
    string? VisitorImage = null, Guid? ClientRequestId = null);
public sealed record LifecycleRequest(int EmpId, string EventType, DateOnly EventDate,
    string? Timing = null, string? Remark = null, string? DocUrl = null);
public sealed record TrainingRequest(DateOnly Dated, int? UnitId = null, string? Timing = null, string? Topic = null,
    string? Remark = null, string? PhotoUrl = null, IReadOnlyList<int>? AttendeeIds = null, int? TrainingId = null);
public sealed record EmployeeRequestInput(string RequestType, DateOnly? FromDate = null, DateOnly? ToDate = null,
    decimal? Amount = null, string? Reason = null);
public sealed record SuggestionRequest(string Description, string? Subject = null);
public sealed record StockInRequest(int BranchId, int ItemId, decimal Qty, decimal Rate = 0,
    string? RefNo = null, string? Remark = null);
public sealed record IssueUniformRequest(int EmpId, int ItemId, decimal Qty, decimal? Rate = null,
    bool RecoverInSalary = false, string? Remark = null);
public sealed record ReturnUniformRequest(int IssueId, decimal Qty, string? Remark = null);
public sealed record DocumentRequest(string OwnerType, int OwnerId, string BlobUrl, int? DocTypeId = null,
    string? FileName = null, string? MimeType = null, long? SizeBytes = null,
    DateOnly? IssueDate = null, DateOnly? ExpiryDate = null, string? Remark = null);
public sealed record AdvanceRequest(int EmpId, decimal Amount, decimal? InstallmentAmount = null,
    string? Reason = null, DateOnly? IssueDate = null);
