using Diti365.Api.Controllers;
using Diti365.Api.Filters;
using Diti365.Application.Abstractions;
using Diti365.Application.Security;
using Diti365.Contracts.Common;
using Diti365.Infrastructure.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace Diti365.Api.Controllers.V2;

using Row = IReadOnlyDictionary<string, object?>;

[Route("api/v2/sales")]
public sealed class SalesController(ICurrentUser currentUser, ISalesRepository repo)
    : ApiControllerBase(currentUser)
{
    [HttpGet("visits"), HasPermission(Perm.SalesView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Visits(
        [FromQuery] PagedQuery q, [FromQuery] bool onlyMine = true, [FromQuery] int? empId = null)
    {
        var result = await repo.GetVisitsAsync(onlyMine, empId, q.From, q.To, q.Search, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpPost("visits"), HasPermission(Perm.SalesEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> Visit([FromBody] VisitRequest r) =>
        Command(await repo.VisitEntryAsync(r.CompanyName, r.ContactPerson, r.ContactNo, r.Location,
                                           r.Latitude, r.Longitude, r.Purpose, r.Remark, r.VisitDate, r.PhotoUrl, Ct));

    /// <summary>Buckets: due, overdue, upcoming, all. Overdue is what a sales rep opens first.</summary>
    [HttpGet("follow-ups"), HasPermission(Perm.SalesView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> FollowUps(
        [FromQuery] PagedQuery q, [FromQuery] string bucket = "due",
        [FromQuery] bool onlyMine = true, [FromQuery] int? empId = null)
    {
        var result = await repo.GetFollowUpsAsync(bucket, onlyMine, empId, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpPost("follow-ups"), HasPermission(Perm.SalesEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> FollowUp([FromBody] FollowUpRequest r) =>
        Command(await repo.FollowupEntryAsync(r.CompanyName, r.SalesVisitId, r.ContactPerson, r.ContactNo,
                                              r.Location, r.Purpose, r.FollowupDate, r.NextFollowupDate,
                                              r.Remark, r.StopFollow, Ct));

    [HttpGet("pipeline"), HasPermission(Perm.SalesView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<IReadOnlyList<Row>>>>> Pipeline(
        [FromQuery] DateOnly? from, [FromQuery] DateOnly? to) =>
        Data(await repo.GetPipelineAsync(from, to, Ct));

    [HttpPost("client-relations"), HasPermission(Perm.SalesEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> ClientRelation([FromBody] ClientRelationRequest r) =>
        Command(await repo.ClientRelationEntryAsync(r.UnitId, r.ContactPerson, r.MobileNo, r.Dated,
                                                    r.Timing, r.Remark, r.Latitude, r.Longitude, r.PhotoUrl, Ct));

    [HttpGet("client-relations"), HasPermission(Perm.SalesView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> ClientRelations([FromQuery] PagedQuery q)
    {
        var result = await repo.ClientRelationReportAsync(q.From, q.To, q.UnitId, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }
}

public sealed record VisitRequest(string CompanyName, string? ContactPerson = null, string? ContactNo = null,
    string? Location = null, decimal? Latitude = null, decimal? Longitude = null, string? Purpose = null,
    string? Remark = null, DateOnly? VisitDate = null, string? PhotoUrl = null);
public sealed record FollowUpRequest(string CompanyName, int? SalesVisitId = null, string? ContactPerson = null,
    string? ContactNo = null, string? Location = null, string? Purpose = null, DateOnly? FollowupDate = null,
    DateOnly? NextFollowupDate = null, string? Remark = null, bool StopFollow = false);
public sealed record ClientRelationRequest(int UnitId, string? ContactPerson = null, string? MobileNo = null,
    DateOnly? Dated = null, string? Timing = null, string? Remark = null,
    decimal? Latitude = null, decimal? Longitude = null, string? PhotoUrl = null);
