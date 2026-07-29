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
public sealed class ReportsController(
    ICurrentUser currentUser,
    IReportRepository repo,
    IMasterRepository masters) : ApiControllerBase(currentUser)
{
    [HttpGet("reports"), HasPermission(Perm.ReportView)]
    public ActionResult<ApiResponse<IReadOnlyCollection<string>>> Available() => Data(repo.AvailableReports);

    /// <summary>
    /// One shell for every report. The key selects a procedure from an allow-list; an
    /// unknown key is a 404 rather than anything reaching the database.
    /// </summary>
    [HttpGet("reports/{reportKey}"), HasPermission(Perm.ReportView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Run(
        string reportKey, [FromQuery] PagedQuery q, [FromQuery] int? empId,
        [FromQuery] int? clientId, [FromQuery] string? monthYear)
    {
        var filter = new ReportFilter(q.From, q.To, q.BranchId, q.UnitId, empId, clientId,
                                      q.Status, monthYear, q.Page, q.PageSize);
        var result = await repo.RunAsync(reportKey, filter, Ct);
        return Paged(result, q);
    }

    /// <summary>
    /// CSV export. Exporting is a separate permission from viewing, because taking a
    /// spreadsheet of employee data off the platform is a different act from looking
    /// at a screen.
    /// </summary>
    [HttpGet("reports/{reportKey}/export"), HasPermission(Perm.ReportExport)]
    public async Task<IActionResult> Export(
        string reportKey, [FromQuery] PagedQuery q, [FromQuery] int? empId,
        [FromQuery] int? clientId, [FromQuery] string? monthYear)
    {
        // Export pulls a larger page but is still bounded; an unbounded export is how
        // a report endpoint becomes an outage.
        var filter = new ReportFilter(q.From, q.To, q.BranchId, q.UnitId, empId, clientId,
                                      q.Status, monthYear, 1, 5000);
        var result = await repo.RunAsync(reportKey, filter, Ct);

        if (result.Items.Count == 0) return NoContent();

        var csv = new System.Text.StringBuilder();
        var columns = result.Items[0].Keys.ToArray();
        csv.AppendLine(string.Join(',', columns.Select(Escape)));

        foreach (var row in result.Items)
            csv.AppendLine(string.Join(',', columns.Select(c => Escape(row[c]?.ToString()))));

        var name = $"{reportKey}-{DateTime.UtcNow:yyyyMMdd-HHmm}.csv";
        return File(System.Text.Encoding.UTF8.GetBytes(csv.ToString()), "text/csv", name);

        static string Escape(string? value)
        {
            if (string.IsNullOrEmpty(value)) return string.Empty;
            // A leading =, +, - or @ makes Excel treat the cell as a formula. Prefix it.
            var v = value.Length > 0 && value[0] is '=' or '+' or '-' or '@' ? "'" + value : value;
            return v.Contains(',') || v.Contains('"') || v.Contains('\n')
                ? $"\"{v.Replace("\"", "\"\"")}\""
                : v;
        }
    }

    // ------------------------------------------------------------ dashboards

    [HttpGet("dashboard/platform")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<IReadOnlyList<Row>>>>> Platform()
    {
        if (!Me.IsSuperAdmin) throw DomainException.Forbidden("Platform analytics are restricted to the platform operator.");
        return Data(await repo.DashboardAsync("dbo.usp_Dashboard_Platform", null, Ct));
    }

    /// <summary>
    /// The client portal dashboard. Deliberately narrow: guards on duty, patrol proof
    /// and invoices. It never exposes salary, Aadhaar, addresses or other clients.
    /// </summary>
    [HttpGet("dashboard/client")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<IReadOnlyList<Row>>>>> ClientDashboard()
    {
        if (Me.ClientId is null) throw DomainException.Forbidden("This login is not linked to a client.");
        return Data(await repo.DashboardAsync("dbo.usp_Dashboard_Client", null, Ct));
    }

    [HttpGet("companies")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Companies([FromQuery] PagedQuery q)
    {
        if (!Me.IsSuperAdmin) throw DomainException.Forbidden("Tenant administration is restricted to the platform operator.");
        var result = await masters.GetCompaniesAsync(q.Search, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpGet("companies/{companyId:int}/logins")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> CompanyLogins(
        int companyId, [FromQuery] DateOnly? from, [FromQuery] DateOnly? to)
    {
        if (!Me.IsSuperAdmin) throw DomainException.Forbidden("Tenant administration is restricted to the platform operator.");
        return Data(await masters.GetCompanyLogDetailAsync(companyId, from, to, Ct));
    }
}
