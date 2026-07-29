using Diti365.Contracts.Common;
using Diti365.Domain;
using Diti365.Infrastructure.Data;
using Microsoft.Data.SqlClient;

namespace Diti365.Infrastructure.Repositories;

using Row = IReadOnlyDictionary<string, object?>;

public interface IReportRepository
{
    /// <summary>Runs one of the whitelisted report procedures with the standard filter set.</summary>
    Task<PagedResult<Row>> RunAsync(string reportKey, ReportFilter filter, CancellationToken ct);

    /// <summary>Role dashboard: several widget result sets in one round trip.</summary>
    Task<IReadOnlyList<IReadOnlyList<Row>>> DashboardAsync(string procedure,
        Action<SqlParameterCollection>? extra, CancellationToken ct);

    IReadOnlyCollection<string> AvailableReports { get; }
}

public sealed record ReportFilter(
    DateOnly? From = null, DateOnly? To = null,
    int? BranchId = null, int? UnitId = null, int? EmpId = null, int? ClientId = null,
    string? Status = null, string? MonthYear = null,
    int Page = 1, int PageSize = 50);

public sealed class ReportRepository(IDbExecutor db) : IReportRepository
{
    /// <summary>
    /// An allow-list, not string concatenation. The report key selects a procedure by
    /// exact match; an unknown key is rejected rather than passed to the database.
    /// </summary>
    private static readonly Dictionary<string, string> Procedures = new(StringComparer.OrdinalIgnoreCase)
    {
        ["event"]                = "dbo.usp_Report_Event",
        ["incdec"]               = "dbo.usp_Report_IncDec",
        ["movement"]             = "dbo.usp_Report_Movement",
        ["contract"]             = "dbo.usp_Report_Contract",
        ["turnout"]              = "dbo.usp_Turnout_GetReport",
        ["incident"]             = "dbo.usp_Incident_GetReport",
        ["training"]             = "dbo.usp_Training_GetReport",
        ["lifecycle"]            = "dbo.usp_Hr_LifecycleReport",
        ["complaint"]            = "dbo.usp_Complaint_GetList",
        ["gatepass"]             = "dbo.usp_GatePass_GetList",
        ["salesvisit"]           = "dbo.usp_Sales_GetVisitReport",
        ["followup"]             = "dbo.usp_Sales_GetFollowUps",
        ["clientrelation"]       = "dbo.usp_Sales_ClientRelationReport",
        ["uniformledger"]        = "dbo.usp_Uniform_GetLedger",
        ["patrolscans"]          = "dbo.usp_Qr_GetScanLog",
        ["attendance"]           = "dbo.usp_Attendance_Get",
        ["attendancesummary"]    = "dbo.usp_Attendance_GetSummary",
        ["deployment"]           = "dbo.usp_Deployment_GetList",
        ["invoice"]              = "dbo.usp_Invoice_GetList",
        ["recruitment"]          = "dbo.usp_Recruit_GetList",
        ["loginlog"]             = "dbo.usp_User_GetLoginLog"
    };

    public IReadOnlyCollection<string> AvailableReports => Procedures.Keys;

    public Task<PagedResult<Row>> RunAsync(string reportKey, ReportFilter f, CancellationToken ct)
    {
        if (!Procedures.TryGetValue(reportKey, out var procedure))
            throw DomainException.NotFound($"Report '{reportKey}'");

        return db.QueryPagedAsync(procedure, p =>
        {
            // Permissive by design: the executor drops whatever the procedure does not
            // declare, so one filter vocabulary serves all twenty-one reports.
            p.Add(P.Date("@FromDate",  f.From));
            p.Add(P.Date("@ToDate",    f.To));
            p.Add(P.Int ("@BranchID",  f.BranchId));
            p.Add(P.Int ("@UnitID",    f.UnitId));
            p.Add(P.Int ("@EmpID",     f.EmpId));
            p.Add(P.Int ("@ClientID",  f.ClientId));
            p.Add(P.NVar("@Status",    f.Status, 20));
            p.Add(P.Char("@MonthYear", f.MonthYear, 7));
            p.Add(P.Int("@PageNo",   f.Page));
            p.Add(P.Int("@PageSize", f.PageSize));
        }, Map.Dynamic, ct);
    }

    public Task<IReadOnlyList<IReadOnlyList<Row>>> DashboardAsync(
        string procedure, Action<SqlParameterCollection>? extra, CancellationToken ct) =>
        db.QueryMultipleAsync(procedure, extra, async (reader, token) =>
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
