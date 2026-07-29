using Diti365.Api.Controllers;
using Diti365.Application.Abstractions;
using Diti365.Contracts.Common;
using Diti365.Infrastructure.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace Diti365.Api.Controllers.V2;

using Row = IReadOnlyDictionary<string, object?>;

[Route("api/v2/me")]
public sealed class MeController(
    ICurrentUser currentUser,
    IMasterRepository masters,
    IReportRepository reports) : ApiControllerBase(currentUser)
{
    [HttpGet]
    public ActionResult<ApiResponse<object>> Get() => Data<object>(new
    {
        Me.UserId, Me.CompanyId, Me.BranchId, Me.EmpId, Me.ClientId,
        Me.RoleCode, Me.LoginType, Me.DeviceId, Me.BranchIds
    });

    [HttpGet("permissions")]
    public ActionResult<ApiResponse<IReadOnlyCollection<string>>> Permissions() => Data(Me.Permissions);

    [HttpGet("profile")]
    public async Task<ActionResult<ApiResponse<Row?>>> Profile() =>
        Data(await masters.GetProfileAsync(Ct));

    /// <summary>The role dashboard: several widget result sets in a single round trip.</summary>
    [HttpGet("dashboard")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<IReadOnlyList<Row>>>>> Dashboard()
    {
        Me.RequireCompanyId();
        var sets = await reports.DashboardAsync("dbo.usp_Dashboard_Get", null, Ct);
        return Data(sets);
    }
}
