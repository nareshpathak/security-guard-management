using Diti365.Contracts.Auth;
using Diti365.Contracts.Common;
using Diti365.Infrastructure.Repositories;
using Diti365.Infrastructure.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace Diti365.Api.Controllers.V1;

using Row = IReadOnlyDictionary<string, object?>;

/// <summary>Legacy UsersController — routes kept for Diti365.apk v4.8.</summary>
[Route("api/Users")]
public sealed class UsersController(
    IAuthService auth,
    IAuthRepository authRepo,
    IMasterRepository masters) : LegacyControllerBase
{
    [HttpPost("login"), AllowAnonymous, EnableRateLimiting("auth")]
    public async Task<ActionResult<LegacyEnvelope<LoginResponse>>> Login([FromBody] LoginRequest request)
    {
        var result = await auth.LoginAsync(request, ClientIp, Ct);
        return OkData(new[] { result }, "Login successful");
    }

    [HttpPost("checknum"), AllowAnonymous, EnableRateLimiting("auth")]
    public async Task<ActionResult<LegacyEnvelope<object>>> CheckNum([FromBody] MobileBody body) =>
        FromSp(await authRepo.CheckMobileAsync(body.MobileNo ?? body.Mobile ?? string.Empty, Ct));

    [HttpPost("changepass")]
    public async Task<ActionResult<LegacyEnvelope<object>>> ChangePass([FromBody] ChangePasswordRequest body)
    {
        await auth.ChangePasswordAsync(
            int.TryParse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value, out var uid) ? uid : 0,
            User.Identity?.Name ?? string.Empty, body, Ct);
        return OkEmpty("Password changed");
    }

    [HttpPost("checkdeviceid")]
    public async Task<ActionResult<LegacyEnvelope<object>>> CheckDevice([FromBody] DeviceVerifyRequest body)
    {
        var userId = int.TryParse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value, out var uid) ? uid : 0;
        return FromSp(await authRepo.CheckDeviceAsync(userId, body.DeviceId, Ct));
    }

    [HttpPost("checkexpire")]
    public async Task<ActionResult<LegacyEnvelope<object>>> CheckExpire()
    {
        var companyClaim = User.FindFirst("company_id")?.Value;
        if (!int.TryParse(companyClaim, out var companyId))
            return Ok(LegacyEnvelope<object>.Fail("No company context", 400));
        return FromSp(await authRepo.CheckExpiryAsync(companyId, Ct));
    }

    [HttpPost("updatetoken")]
    public async Task<ActionResult<LegacyEnvelope<object>>> UpdateToken([FromBody] UpdateTokenRequest body)
    {
        var userId = int.TryParse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value, out var uid) ? uid : 0;
        return FromSp(await authRepo.UpdateFcmTokenAsync(userId, body.FcmToken, body.Platform, Ct));
    }

    [HttpGet("getrights")]
    public async Task<ActionResult<LegacyEnvelope<PermissionGrant>>> GetRights()
    {
        var userId = int.TryParse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value, out var uid) ? uid : 0;
        var companyId = int.TryParse(User.FindFirst("company_id")?.Value, out var cid) ? cid : 0;
        var perms = await authRepo.GetPermissionsAsync(companyId, userId, Ct);
        return OkData(perms);
    }

    [HttpGet("getprofile")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetProfile()
    {
        var profile = await masters.GetProfileAsync(Ct);
        return profile is null
            ? Ok(LegacyEnvelope<Row>.Fail("Profile not found", 404))
            : OkData(new[] { profile });
    }

    [HttpGet("getuserlists")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetUserLists(
        [FromQuery] int? branchId, [FromQuery] int? roleId, [FromQuery] string? search,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var result = await masters.GetUsersAsync(branchId, roleId, search, page, pageSize, "UserName", "asc", Ct);
        return OkData(result.Items);
    }

    [HttpGet("getLoginLog")]
    public ActionResult<LegacyEnvelope<object>> GetLoginLog() =>
        OkEmpty("Use api/v2/reports/loginlog");

    [HttpGet("getCompanylog")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetCompanyLog(
        [FromQuery] string? search, [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var result = await masters.GetCompaniesAsync(search, page, pageSize, Ct);
        return OkData(result.Items);
    }

    [HttpGet("getCompanylogdetail")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetCompanyLogDetail(
        [FromQuery] int companyId, [FromQuery] DateOnly? from, [FromQuery] DateOnly? to)
    {
        var rows = await masters.GetCompanyLogDetailAsync(companyId, from, to, Ct);
        return OkData(rows);
    }

    [HttpGet("getstates")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetStates([FromQuery] int? countryId) =>
        OkData(await masters.GetStatesAsync(countryId, Ct));

    [HttpGet("getcity")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetCity(
        [FromQuery] int? stateId, [FromQuery] int? districtId, [FromQuery] string? search) =>
        OkData(await masters.GetCitiesAsync(stateId, districtId, search, Ct));

    [HttpGet("getdesignation")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetDesignation() =>
        OkData(await masters.GetDesignationsAsync(Ct));

    [HttpGet("getqualification")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetQualification() =>
        OkData(await masters.GetQualificationsAsync(Ct));

    [HttpGet("getcomplaintype")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetComplainType() =>
        OkData(await masters.GetComplaintTypesAsync(Ct));

    [HttpGet("gettype")]
    public async Task<ActionResult<LegacyEnvelope<LookupItem>>> GetType([FromQuery] string typeName) =>
        OkData(await masters.GetTypeAsync(typeName, Ct));

    [HttpGet("getsubdropdown")]
    public async Task<ActionResult<LegacyEnvelope<LookupItem>>> GetSubDropdown(
        [FromQuery] string typeName, [FromQuery] int parentId) =>
        OkData(await masters.GetSubDropdownAsync(typeName, parentId, Ct));

    [HttpGet("getlist")]
    public async Task<ActionResult<LegacyEnvelope<object>>> GetList()
    {
        var bootstrap = await masters.GetBootstrapAsync(Ct);
        return OkData<object>(new object[] { bootstrap });
    }
}

public sealed record MobileBody(string? MobileNo = null, string? Mobile = null);
