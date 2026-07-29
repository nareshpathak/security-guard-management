using Diti365.Contracts.Common;
using Diti365.Infrastructure.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace Diti365.Api.Controllers.V1;

using Row = IReadOnlyDictionary<string, object?>;

[Route("api/Sales")]
public sealed class SalesController(ISalesRepository sales) : LegacyControllerBase
{
    [HttpPost("visitEntry")]
    public async Task<ActionResult<LegacyEnvelope<object>>> VisitEntry([FromBody] V1VisitBody b) =>
        FromSp(await sales.VisitEntryAsync(b.CompanyName ?? "", b.ContactPerson, b.ContactNo, b.Location,
            b.Latitude, b.Longitude, b.Purpose, b.Remark, b.VisitDate, b.PhotoUrl, Ct));

    [HttpGet("visitReport")]
    [HttpGet("getVisitLog")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> VisitReport(
        [FromQuery] bool onlyMine = false, [FromQuery] int? empId = null,
        [FromQuery] DateOnly? from = null, [FromQuery] DateOnly? to = null,
        [FromQuery] string? search = null, [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var result = await sales.GetVisitsAsync(onlyMine, empId, from, to, search, page, pageSize, Ct);
        return OkData(result.Items);
    }

    [HttpPost("followupEntry")]
    public async Task<ActionResult<LegacyEnvelope<object>>> FollowupEntry([FromBody] V1FollowBody b) =>
        FromSp(await sales.FollowupEntryAsync(b.CompanyName ?? "", b.SalesVisitId, b.ContactPerson, b.ContactNo,
            b.Location, b.Purpose, b.FollowupDate, b.NextFollowupDate, b.Remark, b.StopFollow, Ct));

    [HttpGet("followReport")]
    [HttpGet("nextfollowReport")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> FollowReport(
        [FromQuery] string bucket = "all", [FromQuery] bool onlyMine = false, [FromQuery] int? empId = null,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var result = await sales.GetFollowUpsAsync(bucket, onlyMine, empId, page, pageSize, Ct);
        return OkData(result.Items);
    }

    [HttpPost("clientRelation")]
    public async Task<ActionResult<LegacyEnvelope<object>>> ClientRelation([FromBody] V1ClientRelBody b) =>
        FromSp(await sales.ClientRelationEntryAsync(b.UnitId, b.ContactPerson, b.Mobile, b.Dated,
            b.Timing, b.Remark, b.Latitude, b.Longitude, b.PhotoUrl, Ct));

    [HttpGet("clientrelationRpt")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> ClientRelationRpt(
        [FromQuery] DateOnly? from, [FromQuery] DateOnly? to, [FromQuery] int? unitId,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var result = await sales.ClientRelationReportAsync(from, to, unitId, page, pageSize, Ct);
        return OkData(result.Items);
    }
}

public sealed record V1VisitBody(
    string? CompanyName = null, string? ContactPerson = null, string? ContactNo = null, string? Location = null,
    decimal? Latitude = null, decimal? Longitude = null, string? Purpose = null, string? Remark = null,
    DateOnly? VisitDate = null, string? PhotoUrl = null);

public sealed record V1FollowBody(
    string? CompanyName = null, int? SalesVisitId = null, string? ContactPerson = null, string? ContactNo = null,
    string? Location = null, string? Purpose = null, DateOnly? FollowupDate = null,
    DateOnly? NextFollowupDate = null, string? Remark = null, bool StopFollow = false);

public sealed record V1ClientRelBody(
    int UnitId, string? ContactPerson = null, string? Mobile = null, DateOnly? Dated = null,
    string? Timing = null, string? Remark = null, decimal? Latitude = null, decimal? Longitude = null,
    string? PhotoUrl = null);
