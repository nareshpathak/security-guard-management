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
public sealed class OperationsController(ICurrentUser currentUser, IOpsRepository repo)
    : ApiControllerBase(currentUser)
{
    // ------------------------------------------------------------ deployment

    [HttpGet("deployments"), HasPermission(Perm.DeploymentView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Deployments(
        [FromQuery] PagedQuery q, [FromQuery] int? empId, [FromQuery] int? shiftId, [FromQuery] bool onlyActive = true)
    {
        var result = await repo.GetDeploymentsAsync(q.UnitId, empId, q.BranchId, shiftId, onlyActive, q.Search, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpPost("deployments"), HasPermission(Perm.DeploymentEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> Deploy([FromBody] DeployRequest r) =>
        Command(await repo.DeployAsync(r.EmpId, r.UnitId, r.PostId, r.ShiftId, r.FromDate, r.IsReliever,
                                       r.RelieverForEmpId, r.Remark, r.AllowOverStrength, r.OverStrengthReason, Ct));

    [HttpPost("deployments/{id:int}/end"), HasPermission(Perm.DeploymentEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> EndDeployment(int id, [FromBody] EndDeploymentRequest r) =>
        Command(await repo.EndDeploymentAsync(id, r.ToDate, r.Remark, Ct));

    [HttpGet("units/{unitId:int}/employees"), HasPermission(Perm.DeploymentView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> UnitEmployees(int unitId, [FromQuery] int? shiftId) =>
        Data(await repo.GetUnitEmployeesAsync(unitId, shiftId, Ct));

    /// <summary>
    /// Who can fill this vacancy, nearest first by last known GPS. An operations
    /// executive does not want a list of 200 relievers - they want the three who can
    /// reach the site before the shift starts.
    /// </summary>
    [HttpGet("units/{unitId:int}/relievers"), HasPermission(Perm.DeploymentEdit)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Relievers(
        int unitId, [FromQuery] DateOnly? onDate, [FromQuery] int? shiftId) =>
        Data(await repo.GetAvailableRelieversAsync(unitId, onDate, shiftId, Ct));

    [HttpPost("deployments/movement"), HasPermission(Perm.DeploymentEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> Movement([FromBody] MovementRequest r) =>
        Command(await repo.MovementAsync(r.EmpId, r.FromUnitId, r.ToUnitId, r.PostName, r.MovementDate,
                                         r.MovementTime, r.InstructionBy, r.Remark, r.ApplyNow, Ct));

    [HttpPost("deployments/incdec"), HasPermission(Perm.DeploymentEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> IncDec([FromBody] IncDecRequest r) =>
        Command(await repo.IncDecAsync(r.UnitId, r.ChangeType, r.Dated, r.Nop, r.Timing,
                                       r.DesignationId, r.ShiftId, r.Remark, Ct));

    [HttpPost("deployments/incdec/{changeId:int}/approve"), HasPermission(Perm.DeploymentApprove)]
    public async Task<ActionResult<ApiResponse<SpResult>>> IncDecApprove(int changeId, [FromBody] ApproveSimpleRequest r) =>
        Command(await repo.IncDecApproveAsync(changeId, r.Approve, r.Remark, Ct));

    [HttpPost("contracts"), HasPermission(Perm.ClientEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> Contract([FromBody] ContractRequest r) =>
        Command(await repo.ContractAsync(r.ContractType, r.ClientId, r.UnitId, r.Dated, r.Nop,
                                         r.Timing, r.EffectiveFrom, r.EffectiveTo, r.Remark, Ct));

    [HttpPost("contracts/temporary-event"), HasPermission(Perm.ClientEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> TemporaryEvent([FromBody] TemporaryEventRequest r) =>
        Command(await repo.TemporaryEventAsync(r.UnitId, r.ClientId, r.TypeOfService, r.ServiceTypeId,
                                               r.StartDate, r.EndDate, r.StartTime, r.EndTime, r.Nop, r.Rate, r.Remark, Ct));

    // --------------------------------------------------------------- turnout

    /// <summary>
    /// The live turnout board. Units short of contracted strength sort to the top, so
    /// the first thing on screen at 08:00 is the sites that need a person today.
    /// </summary>
    [HttpGet("turnout/live"), HasPermission(Perm.DeploymentView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> LiveTurnout(
        [FromQuery] DateOnly? onDate, [FromQuery] int? branchId, [FromQuery] int? clientId, [FromQuery] int? shiftId) =>
        Data(await repo.GetLiveTurnoutAsync(onDate, branchId, clientId, shiftId, Ct));

    [HttpPost("turnout"), HasPermission(Perm.DeploymentEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SaveTurnout([FromBody] TurnoutRequest r) =>
        Command(await repo.SaveTurnoutAsync(r.UnitId, r.TurnoutDate, r.ShiftId, r.RequiredNos, r.PresentNos,
                                            r.AbsentNos, r.RelieverNos, r.Remark, r.EmpIds, Ct));

    [HttpGet("turnout/vacant-posts"), HasPermission(Perm.DeploymentView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> VacantPosts([FromQuery] int minutesAhead = 60) =>
        Data(await repo.DetectVacantPostsAsync(minutesAhead, Ct));

    // ---------------------------------------------------------------- patrol

    [HttpGet("patrol/checkpoints"), HasPermission(Perm.PatrolView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Checkpoints([FromQuery] PagedQuery q)
    {
        var result = await repo.GetCheckpointsAsync(q.UnitId, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpPost("patrol/checkpoints"), HasPermission(Perm.PatrolEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SaveCheckpoint([FromBody] CheckpointRequest r) =>
        Command(await repo.SaveCheckpointAsync(r.UnitId, r.Name, r.Location, r.LocationId, r.Latitude, r.Longitude,
                                               r.MaxDistanceMeters, r.RequirePhoto, r.Remark, r.QrId, Ct));

    /// <summary>Called before scanning, so the app can show "you must be within X m".</summary>
    [HttpGet("patrol/checkpoints/{qrCode}/distance"), HasPermission(Perm.PatrolScan)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> CheckpointDistance(
        string qrCode, [FromQuery] decimal? lat, [FromQuery] decimal? lon) =>
        Data(await repo.GetCheckpointDistanceAsync(qrCode, lat, lon, Ct));

    /// <summary>
    /// Records a checkpoint scan.
    ///
    /// A scan taken outside the checkpoint radius is stored with IsWithinRange = 0
    /// rather than rejected. Refusing it would leave no record at all, and the
    /// supervisor would see a missed round instead of a guard who scanned from 80 m
    /// away. A visible exception beats missing data.
    /// </summary>
    [HttpPost("patrol/scan"), HasPermission(Perm.PatrolScan)]
    public async Task<ActionResult<ApiResponse<SpResult>>> Scan([FromBody] ScanRequest r) =>
        Command(await repo.ScanAsync(r.QrCode, r.EmpId ?? Me.EmpId, r.Latitude, r.Longitude, r.ImageUrl,
                                     r.Remark, r.Scantime, r.IsMockLocation, r.IsOffline,
                                     r.ClientRequestId, r.DeviceId, r.AppVersion, Ct));

    [HttpGet("patrol/logs"), HasPermission(Perm.PatrolView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> ScanLogs(
        [FromQuery] PagedQuery q, [FromQuery] int? qrId, [FromQuery] int? empId, [FromQuery] bool onlyOutOfRange = false)
    {
        var result = await repo.GetScanLogAsync(q.UnitId, qrId, empId, q.From, q.To, onlyOutOfRange, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpGet("patrol/summary"), HasPermission(Perm.PatrolView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> PatrolSummary(
        [FromQuery] DateOnly? from, [FromQuery] DateOnly? to, [FromQuery] int? unitId) =>
        Data(await repo.GetPatrolSummaryAsync(from, to, unitId, Ct));

    [HttpPost("patrol/rounds"), HasPermission(Perm.PatrolEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SaveRound([FromBody] RoundRequest r) =>
        Command(await repo.SaveRoundAsync(r.UnitId, r.RoundName, r.StartTime, r.EndTime, r.GraceMinutes,
                                          r.DaysOfWeek, r.QrIds, r.RoundId, Ct));

    [HttpGet("patrol/my-progress"), HasPermission(Perm.PatrolScan)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<IReadOnlyList<Row>>>>> MyProgress([FromQuery] int? unitId) =>
        Data(await repo.GetMyPatrolProgressAsync(unitId, Ct));

    [HttpGet("patrol/missed"), HasPermission(Perm.PatrolView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> MissedRounds([FromQuery] DateOnly? onDate) =>
        Data(await repo.DetectMissedRoundsAsync(onDate, Ct));

    // -------------------------------------------------------------- tracking

    [HttpPost("tracking/ping")]
    public async Task<ActionResult<ApiResponse<SpResult>>> Ping([FromBody] PingRequest r) =>
        Command(await repo.TrackAsync(r.Latitude, r.Longitude, r.Accuracy, r.Speed, r.BatteryLevel,
                                      r.LoggedAt, r.Source ?? "FG", r.IsMockLocation, r.DeviceId, Ct));

    /// <summary>
    /// The phone's location outbox in one call.
    ///
    /// A batch containing spoofed pings is still accepted: rejecting the whole
    /// batch would throw away a shift of genuine offline history because of one
    /// bad row, which is exactly wrong for an offline-first client. The flagged
    /// rows are stored, excluded from the live board, and counted in the reply.
    /// </summary>
    [HttpPost("tracking/ping/batch")]
    public async Task<ActionResult<ApiResponse<SpResult>>> PingBatch([FromBody] PingBatchRequest r)
    {
        if (r.Pings is null || r.Pings.Count == 0)
            throw DomainException.Validation("Send at least one ping.");

        if (r.Pings.Count > 500)
            throw DomainException.Validation("Send at most 500 pings per batch.");

        return Command(await repo.TrackBatchAsync(r.Pings, r.DeviceId, Ct));
    }

    [HttpGet("tracking/live"), HasPermission(Perm.TrackingView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> LiveMap([FromQuery] int staleMinutes = 30) =>
        Data(await repo.GetLiveLocationsAsync(staleMinutes, Ct));

    [HttpGet("tracking/users/{userId:int}/trail"), HasPermission(Perm.TrackingView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<IReadOnlyList<Row>>>>> Trail(
        int userId, [FromQuery] DateOnly? date) =>
        Data(await repo.GetTrailAsync(userId, date, Ct));
}

public sealed record DeployRequest(int EmpId, int UnitId, int? PostId = null, int? ShiftId = null,
    DateOnly? FromDate = null, bool IsReliever = false, int? RelieverForEmpId = null, string? Remark = null,
    bool AllowOverStrength = false, string? OverStrengthReason = null);
public sealed record EndDeploymentRequest(DateOnly? ToDate = null, string? Remark = null);
public sealed record MovementRequest(int EmpId, int? FromUnitId, int? ToUnitId, string? PostName,
    DateOnly? MovementDate, TimeOnly? MovementTime, string? InstructionBy, string? Remark, bool ApplyNow = true);
public sealed record IncDecRequest(int UnitId, string ChangeType, DateOnly Dated, int Nop,
    string? Timing = null, int? DesignationId = null, int? ShiftId = null, string? Remark = null);
public sealed record ApproveSimpleRequest(bool Approve, string? Remark = null);
public sealed record ContractRequest(string ContractType, int? ClientId, int? UnitId, DateOnly? Dated, int Nop,
    string? Timing, DateOnly? EffectiveFrom, DateOnly? EffectiveTo, string? Remark);
public sealed record TemporaryEventRequest(int? UnitId, int? ClientId, string? TypeOfService, int? ServiceTypeId,
    DateOnly StartDate, DateOnly? EndDate, TimeOnly? StartTime, TimeOnly? EndTime, int Nop, decimal? Rate, string? Remark);
public sealed record TurnoutRequest(int UnitId, DateOnly TurnoutDate, int? ShiftId, int RequiredNos,
    int PresentNos, int AbsentNos, int RelieverNos, string? Remark, IReadOnlyList<int>? EmpIds);
public sealed record CheckpointRequest(int UnitId, string Name, string? Location = null, int? LocationId = null,
    decimal? Latitude = null, decimal? Longitude = null, int MaxDistanceMeters = 50,
    bool RequirePhoto = false, string? Remark = null, int? QrId = null);
public sealed record ScanRequest(string QrCode, int? EmpId = null, decimal? Latitude = null, decimal? Longitude = null,
    string? ImageUrl = null, string? Remark = null, DateTime? Scantime = null, bool IsMockLocation = false,
    bool IsOffline = false, Guid? ClientRequestId = null, string? DeviceId = null, string? AppVersion = null);
public sealed record RoundRequest(int UnitId, string RoundName, TimeOnly StartTime, TimeOnly EndTime,
    int GraceMinutes = 15, string? DaysOfWeek = null, IReadOnlyList<int>? QrIds = null, int? RoundId = null);
public sealed record PingRequest(decimal Latitude, decimal Longitude, decimal? Accuracy = null, decimal? Speed = null,
    byte? BatteryLevel = null, DateTime? LoggedAt = null, string? Source = "FG",
    bool IsMockLocation = false, string? DeviceId = null);

public sealed record PingBatchRequest(IReadOnlyList<LocationPing> Pings, string? DeviceId = null);
