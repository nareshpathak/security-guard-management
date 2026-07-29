using Diti365.Api.Controllers;
using Diti365.Api.Filters;
using Diti365.Application.Abstractions;
using Diti365.Application.Security;
using Diti365.Contracts.Attendance;
using Diti365.Contracts.Common;
using Diti365.Domain;
using Diti365.Infrastructure.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace Diti365.Api.Controllers.V2;

[Route("api/v2/attendance")]
public sealed class AttendanceController(ICurrentUser currentUser, IAttendanceRepository repo)
    : ApiControllerBase(currentUser)
{
    /// <summary>
    /// Punch in. A guard punches for himself; a supervisor may supply EmpId, which
    /// needs the edit permission rather than the punch permission.
    /// </summary>
    [HttpPost("punch-in"), HasPermission(Perm.AttendancePunch)]
    [ProducesResponseType<ApiResponse<PunchResult>>(200)]
    [ProducesResponseType(409), ProducesResponseType(422)]
    public async Task<ActionResult<ApiResponse<PunchResult>>> PunchIn([FromBody] PunchRequest request)
    {
        var empId = ResolveEmpId(request);
        var result = await repo.PunchInAsync(empId, request, Ct);
        return Data(new PunchResult(result.Id, result.Message, null));
    }

    [HttpPost("punch-out"), HasPermission(Perm.AttendancePunch)]
    public async Task<ActionResult<ApiResponse<PunchResult>>> PunchOut([FromBody] PunchRequest request)
    {
        var empId = ResolveEmpId(request);
        var result = await repo.PunchOutAsync(empId, request, Ct);
        return Data(new PunchResult(result.Id, result.Message, null));
    }

    /// <summary>
    /// Drains the mobile offline outbox in one round trip.
    ///
    /// A rejected punch does not fail the batch: each row comes back with its own
    /// outcome so the phone can clear what was accepted and keep only the genuine
    /// failures. Replays are idempotent on ClientRequestId, so a retry after a dropped
    /// response never double-counts a day.
    /// </summary>
    [HttpPost("sync"), HasPermission(Perm.AttendancePunch)]
    [ProducesResponseType<ApiResponse<IReadOnlyList<SyncOutcome>>>(200)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<SyncOutcome>>>> Sync(
        [FromBody] IReadOnlyList<OfflinePunch> punches)
    {
        if (punches.Count == 0) return Data<IReadOnlyList<SyncOutcome>>([]);
        if (punches.Count > 500)
            throw new DomainException(ErrorCodes.ValidationFailed,
                "Send at most 500 queued punches per sync.", 422);

        return Data(await repo.SyncBatchAsync(punches, Ct));
    }

    [HttpPost("bulk"), HasPermission(Perm.AttendanceEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> BulkMark(
        [FromBody] BulkMarkRequest request) =>
        Command(await repo.BulkMarkAsync(request.UnitId, request.Date, request.ShiftId,
                                         request.EmpIds, request.Status, request.Remark, Ct));

    [HttpGet, HasPermission(Perm.AttendanceView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<AttendanceRow>>>> Get(
        [FromQuery] PagedQuery q, [FromQuery] int? empId)
    {
        var result = await repo.GetAsync(q.UnitId, empId, q.From, q.To, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    /// <summary>The guard's own month. No unit scoping needed - it is his own data.</summary>
    [HttpGet("me")]
    public async Task<ActionResult<ApiResponse<SelfAttendanceResponse>>> Mine([FromQuery] string? monthYear) =>
        Data(await repo.GetSelfAsync(Me.RequireEmpId(),
             monthYear ?? DateTime.UtcNow.ToString("yyyy-MM"), Ct));

    [HttpGet("pending-approval"), HasPermission(Perm.AttendanceApprove)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<ApprovalRow>>>> PendingApproval([FromQuery] PagedQuery q)
    {
        var result = await repo.GetForApprovalAsync(q.UnitId, q.From, q.To, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpPost("approve"), HasPermission(Perm.AttendanceApprove)]
    public async Task<ActionResult<ApiResponse<SpResult>>> Approve([FromBody] ApproveRequest request) =>
        Command(await repo.ApproveAsync(request.AttendanceIds, request.Approve, request.RejectReason, Ct));

    [HttpGet("summary"), HasPermission(Perm.AttendanceView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<AttendanceSummaryRow>>>> Summary(
        [FromQuery] PagedQuery q, [FromQuery] string? monthYear)
    {
        var result = await repo.GetSummaryAsync(monthYear ?? DateTime.UtcNow.ToString("yyyy-MM"),
                                                q.UnitId, q.BranchId, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpGet("counts")]
    public async Task<ActionResult<ApiResponse<AttendanceCounts>>> Counts(
        [FromQuery] int? empId, [FromQuery] DateOnly? onDate) =>
        Data(await repo.GetCountsAsync(empId, onDate, Ct));

    /// <summary>
    /// A guard may only punch for himself. Supplying someone else's EmpId is a
    /// supervisor action and needs the edit permission.
    /// </summary>
    private int ResolveEmpId(PunchRequest request)
    {
        if (request.EmpId is null || request.EmpId == Me.EmpId)
            return Me.RequireEmpId();

        if (!Me.Has(Perm.AttendanceEdit))
            throw DomainException.Forbidden("You may only punch your own attendance.");

        return request.EmpId.Value;
    }
}

public sealed record BulkMarkRequest(
    int UnitId, DateOnly Date, int ShiftId, IReadOnlyList<int> EmpIds,
    string Status = "P", string? Remark = null);
