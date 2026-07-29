using Diti365.Api.Controllers;
using Diti365.Api.Filters;
using Diti365.Application.Abstractions;
using Diti365.Application.Security;
using Diti365.Contracts.Common;
using Diti365.Infrastructure.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace Diti365.Api.Controllers.V2;

using Row = IReadOnlyDictionary<string, object?>;

[Route("api/v2/masters")]
public sealed class MastersController(ICurrentUser currentUser, IMasterRepository repo)
    : ApiControllerBase(currentUser)
{
    /// <summary>
    /// Every lookup the app needs at cold start, in one call. The mobile client caches
    /// this in SQLite and revalidates with an ETag, so a launch costs one request
    /// rather than thirteen.
    /// </summary>
    [HttpGet("bootstrap")]
    [ResponseCache(Duration = 300, Location = ResponseCacheLocation.Client)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<IReadOnlyList<Row>>>>> Bootstrap() =>
        Data(await repo.GetBootstrapAsync(Ct));

    [HttpGet("states")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> States([FromQuery] int? countryId) =>
        Data(await repo.GetStatesAsync(countryId, Ct));

    [HttpGet("districts/{stateId:int}")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Districts(int stateId) =>
        Data(await repo.GetDistrictsAsync(stateId, Ct));

    [HttpGet("cities")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Cities(
        [FromQuery] int? stateId, [FromQuery] int? districtId, [FromQuery] string? search) =>
        Data(await repo.GetCitiesAsync(stateId, districtId, search, Ct));

    [HttpGet("designations")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Designations() =>
        Data(await repo.GetDesignationsAsync(Ct));

    [HttpGet("qualifications")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Qualifications() =>
        Data(await repo.GetQualificationsAsync(Ct));

    [HttpGet("complaint-types")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> ComplaintTypes() =>
        Data(await repo.GetComplaintTypesAsync(Ct));

    /// <summary>Generic lookup: shift, grade, category, uniformitem, priority, taskstatus, bank, branch...</summary>
    [HttpGet("lookup/{typeName}")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<LookupItem>>>> Lookup(string typeName) =>
        Data(await repo.GetTypeAsync(typeName, Ct));

    /// <summary>Dependent lookup: district by state, city by state, unit by client, post by unit...</summary>
    [HttpGet("lookup/{typeName}/{parentId:int}")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<LookupItem>>>> SubLookup(string typeName, int parentId) =>
        Data(await repo.GetSubDropdownAsync(typeName, parentId, Ct));

    [HttpGet("/api/v2/users")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Users(
        [FromQuery] PagedQuery q, [FromQuery] int? roleId)
    {
        var result = await repo.GetUsersAsync(q.BranchId, roleId, q.Search, q.Page, q.PageSize,
                                              q.SortBy ?? "UserName", q.SortDir ?? "asc", Ct);
        return Paged(result, q);
    }

    // ------------------------------------------------------------ management

    /// <summary>
    /// The reference lists this user may manage.
    ///
    /// Platform data - states, banks, login types - is listed for everyone so an
    /// agency admin can see what things are called, but comes back with
    /// CanEdit = false unless they are the platform administrator.
    /// </summary>
    [HttpGet("catalog"), HasPermission(Perm.MasterView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Catalog() =>
        Data(await repo.GetMasterCatalogAsync(Ct));

    [HttpGet("entries/{masterKey}"), HasPermission(Perm.MasterView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Entries(
        string masterKey, [FromQuery] PagedQuery q, [FromQuery] int? parentId,
        [FromQuery] bool includeInactive = false)
    {
        var result = await repo.GetMasterEntriesAsync(masterKey, q.Search, parentId, includeInactive,
                                                      q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpPost("entries/{masterKey}"), HasPermission(Perm.MasterEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SaveEntry(
        string masterKey, [FromBody] MasterEntryRequest r) =>
        Command(await repo.SaveMasterEntryAsync(masterKey, r.Id, r.Name, r.Code, r.SortOrder,
                                                r.ParentId, r.IsActive, Ct));

    [HttpPost("entries/{masterKey}/{id:int}/status"), HasPermission(Perm.MasterEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SetStatus(
        string masterKey, int id, [FromBody] MasterStatusRequest r) =>
        Command(await repo.SetMasterStatusAsync(masterKey, id, r.IsActive, false, Ct));

    /// <summary>
    /// Removes an entry, but only if nothing points at it.
    ///
    /// The procedure counts every foreign key referencing the row first. A
    /// designation that disappears from under 300 employees is not a deletion,
    /// it is a corruption - so that case comes back as a 409 telling the user to
    /// deactivate instead.
    /// </summary>
    [HttpDelete("entries/{masterKey}/{id:int}"), HasPermission(Perm.MasterEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> DeleteEntry(string masterKey, int id) =>
        Command(await repo.SetMasterStatusAsync(masterKey, id, null, true, Ct));
}

public sealed record MasterEntryRequest(
    string Name, int? Id = null, string? Code = null, int? SortOrder = null,
    int? ParentId = null, bool IsActive = true);

public sealed record MasterStatusRequest(bool IsActive);
