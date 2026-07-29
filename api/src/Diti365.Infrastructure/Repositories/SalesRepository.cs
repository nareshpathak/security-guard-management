using Diti365.Contracts.Common;
using Diti365.Infrastructure.Data;

namespace Diti365.Infrastructure.Repositories;

using Row = IReadOnlyDictionary<string, object?>;

public interface ISalesRepository
{
    Task<SpResult> VisitEntryAsync(string companyName, string? contactPerson, string? contactNo, string? location,
                                   decimal? lat, decimal? lon, string? purpose, string? remark,
                                   DateOnly? visitDate, string? photoUrl, CancellationToken ct);
    Task<SpResult> FollowupEntryAsync(string companyName, int? salesVisitId, string? contactPerson, string? contactNo,
                                      string? location, string? purpose, DateOnly? followupDate,
                                      DateOnly? nextFollowupDate, string? remark, bool stopFollow, CancellationToken ct);
    Task<PagedResult<Row>> GetVisitsAsync(bool onlyMine, int? empId, DateOnly? from, DateOnly? to,
                                          string? search, int page, int pageSize, CancellationToken ct);
    Task<PagedResult<Row>> GetFollowUpsAsync(string bucket, bool onlyMine, int? empId, int page, int pageSize, CancellationToken ct);
    Task<IReadOnlyList<IReadOnlyList<Row>>> GetPipelineAsync(DateOnly? from, DateOnly? to, CancellationToken ct);
    Task<SpResult> ClientRelationEntryAsync(int unitId, string? contactPerson, string? mobile, DateOnly? dated,
                                            string? timing, string? remark, decimal? lat, decimal? lon,
                                            string? photoUrl, CancellationToken ct);
    Task<PagedResult<Row>> ClientRelationReportAsync(DateOnly? from, DateOnly? to, int? unitId, int page, int pageSize, CancellationToken ct);
}

public sealed class SalesRepository(IDbExecutor db) : ISalesRepository
{
    public Task<SpResult> VisitEntryAsync(string companyName, string? contactPerson, string? contactNo, string? location,
                                          decimal? lat, decimal? lon, string? purpose, string? remark,
                                          DateOnly? visitDate, string? photoUrl, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Sales_VisitEntry", p =>
        {
            p.Add(P.NVar ("@CompanyName",   companyName, 200));
            p.Add(P.NVar ("@ContactPerson", contactPerson, 150));
            p.Add(P.NVar ("@ContactNo",     contactNo, 15));
            p.Add(P.NVar ("@Location",      location, 300));
            p.Add(P.Coord("@Latitude",      lat));
            p.Add(P.Coord("@Longitude",     lon));
            p.Add(P.NVar ("@Purpose",       purpose, 300));
            p.Add(P.NVar ("@Remark",        remark, 1000));
            p.Add(P.Date ("@VisitDate",     visitDate));
            p.Add(P.NVar ("@PhotoUrl",      photoUrl, 500));
        }, ct);

    public Task<SpResult> FollowupEntryAsync(string companyName, int? salesVisitId, string? contactPerson, string? contactNo,
                                             string? location, string? purpose, DateOnly? followupDate,
                                             DateOnly? nextFollowupDate, string? remark, bool stopFollow, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Sales_FollowupEntry", p =>
        {
            p.Add(P.NVar("@CompanyName",      companyName, 200));
            p.Add(P.Int ("@SalesVisitID",     salesVisitId));
            p.Add(P.NVar("@ContactPerson",    contactPerson, 150));
            p.Add(P.NVar("@ContactNo",        contactNo, 15));
            p.Add(P.NVar("@Location",         location, 300));
            p.Add(P.NVar("@Purpose",          purpose, 300));
            p.Add(P.Date("@FollowupDate",     followupDate));
            p.Add(P.Date("@NextFollowupDate", nextFollowupDate));
            p.Add(P.NVar("@Remark",           remark, 1000));
            p.Add(P.Bit ("@StopFollow",       stopFollow));
        }, ct);

    public Task<PagedResult<Row>> GetVisitsAsync(bool onlyMine, int? empId, DateOnly? from, DateOnly? to,
                                                 string? search, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Sales_GetVisitReport", p =>
        {
            p.Add(P.Bit ("@OnlyMine", onlyMine));
            p.Add(P.Int ("@EmpID",    empId));
            p.Add(P.Date("@FromDate", from));
            p.Add(P.Date("@ToDate",   to));
            p.Add(P.NVar("@Search",   search, 200));
            p.Add(P.Int ("@PageNo",   page));
            p.Add(P.Int ("@PageSize", pageSize));
        }, Map.Dynamic, ct);

    public Task<PagedResult<Row>> GetFollowUpsAsync(string bucket, bool onlyMine, int? empId, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Sales_GetFollowUps", p =>
        {
            p.Add(P.NVar("@Bucket",   bucket, 20));
            p.Add(P.Bit ("@OnlyMine", onlyMine));
            p.Add(P.Int ("@EmpID",    empId));
            p.Add(P.Int ("@PageNo",   page));
            p.Add(P.Int ("@PageSize", pageSize));
        }, Map.Dynamic, ct);

    public Task<IReadOnlyList<IReadOnlyList<Row>>> GetPipelineAsync(DateOnly? from, DateOnly? to, CancellationToken ct) =>
        db.QueryMultipleAsync("dbo.usp_Sales_GetPipeline", p =>
        {
            p.Add(P.Date("@FromDate", from));
            p.Add(P.Date("@ToDate",   to));
        }, async (reader, token) =>
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

    public Task<SpResult> ClientRelationEntryAsync(int unitId, string? contactPerson, string? mobile, DateOnly? dated,
                                                   string? timing, string? remark, decimal? lat, decimal? lon,
                                                   string? photoUrl, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Sales_ClientRelationEntry", p =>
        {
            p.Add(P.Int  ("@UnitID",        unitId));
            p.Add(P.NVar ("@ContactPerson", contactPerson, 150));
            p.Add(P.NVar ("@MobileNo",      mobile, 15));
            p.Add(P.Date ("@Dated",         dated));
            p.Add(P.NVar ("@Timing",        timing, 50));
            p.Add(P.NVar ("@Remark",        remark, 1000));
            p.Add(P.Coord("@Latitude",      lat));
            p.Add(P.Coord("@Longitude",     lon));
            p.Add(P.NVar ("@PhotoUrl",      photoUrl, 500));
        }, ct);

    public Task<PagedResult<Row>> ClientRelationReportAsync(DateOnly? from, DateOnly? to, int? unitId, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Sales_ClientRelationReport", p =>
        {
            p.Add(P.Date("@FromDate", from));
            p.Add(P.Date("@ToDate",   to));
            p.Add(P.Int ("@UnitID",   unitId));
            p.Add(P.Int ("@PageNo",   page));
            p.Add(P.Int ("@PageSize", pageSize));
        }, Map.Dynamic, ct);
}
