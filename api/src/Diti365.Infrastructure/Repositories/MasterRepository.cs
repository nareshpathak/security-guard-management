using Diti365.Contracts.Common;
using Diti365.Infrastructure.Data;

namespace Diti365.Infrastructure.Repositories;

using Row = IReadOnlyDictionary<string, object?>;

public interface IMasterRepository
{
    Task<IReadOnlyList<Row>> GetMasterCatalogAsync(CancellationToken ct);
    Task<PagedResult<Row>> GetMasterEntriesAsync(string masterKey, string? search, int? parentId, bool includeInactive, int page, int pageSize, CancellationToken ct);
    Task<SpResult> SaveMasterEntryAsync(string masterKey, int? id, string name, string? code, int? sortOrder, int? parentId, bool isActive, CancellationToken ct);
    Task<SpResult> SetMasterStatusAsync(string masterKey, int id, bool? isActive, bool cancel, CancellationToken ct);
    Task<IReadOnlyList<Row>> GetStatesAsync(int? countryId, CancellationToken ct);
    Task<IReadOnlyList<Row>> GetCitiesAsync(int? stateId, int? districtId, string? search, CancellationToken ct);
    Task<IReadOnlyList<Row>> GetDistrictsAsync(int stateId, CancellationToken ct);
    Task<IReadOnlyList<Row>> GetDesignationsAsync(CancellationToken ct);
    Task<IReadOnlyList<Row>> GetQualificationsAsync(CancellationToken ct);
    Task<IReadOnlyList<Row>> GetComplaintTypesAsync(CancellationToken ct);
    Task<IReadOnlyList<LookupItem>> GetTypeAsync(string typeName, CancellationToken ct);
    Task<IReadOnlyList<LookupItem>> GetSubDropdownAsync(string typeName, int parentId, CancellationToken ct);

    /// <summary>Thirteen result sets in one round trip - the mobile cold-start call.</summary>
    Task<IReadOnlyList<IReadOnlyList<Row>>> GetBootstrapAsync(CancellationToken ct);

    Task<PagedResult<Row>> GetUsersAsync(int? branchId, int? roleId, string? search, int page, int pageSize,
                                         string sortBy, string sortDir, CancellationToken ct);
    Task<Row?> GetProfileAsync(CancellationToken ct);
    Task<PagedResult<Row>> GetCompaniesAsync(string? search, int page, int pageSize, CancellationToken ct);
    Task<IReadOnlyList<Row>> GetCompanyLogDetailAsync(int companyId, DateOnly? from, DateOnly? to, CancellationToken ct);
}

public sealed class MasterRepository(IDbExecutor db) : IMasterRepository
{
    /// <summary>Which reference lists this user may manage, and how each behaves.</summary>
    public Task<IReadOnlyList<Row>> GetMasterCatalogAsync(CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Master_GetCatalog", null, Map.Dynamic, ct);

    public Task<PagedResult<Row>> GetMasterEntriesAsync(string masterKey, string? search, int? parentId,
                                                        bool includeInactive, int page, int pageSize,
                                                        CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Master_GetEntries", p =>
        {
            p.Add(P.NVar("@MasterKey",       masterKey, 50));
            p.Add(P.NVar("@Search",          search, 200));
            p.Add(P.Int ("@ParentID",        parentId));
            p.Add(P.Bit ("@IncludeInactive", includeInactive));
            p.Add(P.Int ("@PageNo",          page));
            p.Add(P.Int ("@PageSize",        pageSize));
        }, Map.Dynamic, ct);

    public Task<SpResult> SaveMasterEntryAsync(string masterKey, int? id, string name, string? code,
                                               int? sortOrder, int? parentId, bool isActive,
                                               CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Master_Save", p =>
        {
            p.Add(P.NVar("@MasterKey", masterKey, 50));
            p.Add(P.Int ("@Id",        id));
            p.Add(P.NVar("@Name",      name, 200));
            p.Add(P.NVar("@Code",      code, 50));
            p.Add(P.Int ("@SortOrder", sortOrder));
            p.Add(P.Int ("@ParentID",  parentId));
            p.Add(P.Bit ("@IsActive",  isActive));
        }, ct);

    public Task<SpResult> SetMasterStatusAsync(string masterKey, int id, bool? isActive, bool cancel,
                                               CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Master_SetStatus", p =>
        {
            p.Add(P.NVar("@MasterKey", masterKey, 50));
            p.Add(P.Int ("@Id",        id));
            p.Add(P.Bit ("@IsActive",  isActive));
            p.Add(P.Bit ("@Cancel",    cancel));
        }, ct);

    public Task<IReadOnlyList<Row>> GetStatesAsync(int? countryId, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Master_GetStates", p => p.Add(P.Int("@CountryID", countryId)), Map.Dynamic, ct);

    public Task<IReadOnlyList<Row>> GetCitiesAsync(int? stateId, int? districtId, string? search, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Master_GetCity", p =>
        {
            p.Add(P.Int ("@StateID",    stateId));
            p.Add(P.Int ("@DistrictID", districtId));
            p.Add(P.NVar("@Search",     search, 100));
        }, Map.Dynamic, ct);

    public Task<IReadOnlyList<Row>> GetDistrictsAsync(int stateId, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Master_GetDistrict", p => p.Add(P.Int("@StateID", stateId)), Map.Dynamic, ct);

    public Task<IReadOnlyList<Row>> GetDesignationsAsync(CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Master_GetDesignation", null, Map.Dynamic, ct);

    public Task<IReadOnlyList<Row>> GetQualificationsAsync(CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Master_GetQualification", null, Map.Dynamic, ct);

    public Task<IReadOnlyList<Row>> GetComplaintTypesAsync(CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Master_GetComplaintType", null, Map.Dynamic, ct);

    public Task<IReadOnlyList<LookupItem>> GetTypeAsync(string typeName, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Master_GetType", p => p.Add(P.NVar("@TypeName", typeName, 50)), Map.Lookup, ct);

    public Task<IReadOnlyList<LookupItem>> GetSubDropdownAsync(string typeName, int parentId, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Master_GetSubDropdown", p =>
        {
            p.Add(P.NVar("@TypeName", typeName, 50));
            p.Add(P.Int ("@ParentID", parentId));
        }, Map.Lookup, ct);

    public Task<IReadOnlyList<IReadOnlyList<Row>>> GetBootstrapAsync(CancellationToken ct) =>
        db.QueryMultipleAsync("dbo.usp_Master_GetBootstrap", null, async (reader, token) =>
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

    public Task<PagedResult<Row>> GetUsersAsync(int? branchId, int? roleId, string? search, int page, int pageSize,
                                                string sortBy, string sortDir, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_User_GetList", p =>
        {
            p.Add(P.Int ("@BranchID", branchId));
            p.Add(P.Int ("@RoleID",   roleId));
            p.Add(P.NVar("@Search",   search, 200));
            p.Add(P.Int ("@PageNo",   page));
            p.Add(P.Int ("@PageSize", pageSize));
            p.Add(P.NVar("@SortBy",   sortBy, 50));
            p.Add(P.NVar("@SortDir",  sortDir, 4));
        }, Map.Dynamic, ct);

    public Task<Row?> GetProfileAsync(CancellationToken ct) =>
        db.QuerySingleAsync("dbo.usp_User_GetProfile", null, Map.Dynamic, ct);

    public Task<PagedResult<Row>> GetCompaniesAsync(string? search, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Company_GetLog", p =>
        {
            p.Add(P.NVar("@Search",   search, 200));
            p.Add(P.Int ("@PageNo",   page));
            p.Add(P.Int ("@PageSize", pageSize));
        }, Map.Dynamic, ct);

    public Task<IReadOnlyList<Row>> GetCompanyLogDetailAsync(int companyId, DateOnly? from, DateOnly? to, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Company_GetLogDetail", p =>
        {
            p.Add(P.Int ("@CompanyID", companyId));
            p.Add(P.Date("@FromDate",  from));
            p.Add(P.Date("@ToDate",    to));
        }, Map.Dynamic, ct);
}
