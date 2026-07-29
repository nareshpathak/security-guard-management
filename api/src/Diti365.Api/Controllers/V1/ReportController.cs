using Diti365.Contracts.Common;
using Diti365.Infrastructure.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace Diti365.Api.Controllers.V1;

using Row = IReadOnlyDictionary<string, object?>;

[Route("api/Report")]
public sealed class ReportController(IReportRepository reports) : LegacyControllerBase
{
    [HttpGet("eventRpt")]
    public Task<ActionResult<LegacyEnvelope<Row>>> EventRpt([FromQuery] ReportQuery q) =>
        Run("event", q);

    [HttpGet("incdecRpt")]
    public Task<ActionResult<LegacyEnvelope<Row>>> IncDecRpt([FromQuery] ReportQuery q) =>
        Run("incdec", q);

    [HttpGet("movementRpt")]
    public Task<ActionResult<LegacyEnvelope<Row>>> MovementRpt([FromQuery] ReportQuery q) =>
        Run("movement", q);

    [HttpGet("newcontractRpt")]
    [HttpGet("contractterminationRpt")]
    public Task<ActionResult<LegacyEnvelope<Row>>> ContractRpt([FromQuery] ReportQuery q) =>
        Run("contract", q);

    [HttpGet("resignRpt")]
    public Task<ActionResult<LegacyEnvelope<Row>>> ResignRpt([FromQuery] ReportQuery q) =>
        Run("lifecycle", q);

    [HttpGet("trainingRpt")]
    public Task<ActionResult<LegacyEnvelope<Row>>> TrainingRpt([FromQuery] ReportQuery q) =>
        Run("training", q);

    [HttpGet("incidentRpt")]
    public Task<ActionResult<LegacyEnvelope<Row>>> IncidentRpt([FromQuery] ReportQuery q) =>
        Run("incident", q);

    [HttpGet("getturnoutrpt")]
    public Task<ActionResult<LegacyEnvelope<Row>>> TurnoutRpt([FromQuery] ReportQuery q) =>
        Run("turnout", q);

    private async Task<ActionResult<LegacyEnvelope<Row>>> Run(string key, ReportQuery q)
    {
        var result = await reports.RunAsync(key, new ReportFilter(
            q.From, q.To, q.BranchId, q.UnitId, q.EmpId, q.ClientId, q.Status, q.MonthYear, q.Page, q.PageSize), Ct);
        return OkData(result.Items);
    }
}

public sealed record ReportQuery(
    DateOnly? From = null, DateOnly? To = null, int? BranchId = null, int? UnitId = null,
    int? EmpId = null, int? ClientId = null, string? Status = null, string? MonthYear = null,
    int Page = 1, int PageSize = 50);
