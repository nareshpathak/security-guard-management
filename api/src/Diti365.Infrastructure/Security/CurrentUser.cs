using System.Security.Claims;
using Diti365.Application.Abstractions;
using Diti365.Domain;
using Microsoft.AspNetCore.Http;

namespace Diti365.Infrastructure.Security;

public static class DitiClaims
{
    public const string CompanyId = "company_id";
    public const string BranchId  = "branch_id";
    public const string BranchIds = "branch_ids";
    public const string EmpId     = "emp_id";
    public const string ClientId  = "client_id";
    public const string RoleCode  = "role_code";
    public const string LoginType = "login_type";
    public const string DeviceId  = "device_id";
    public const string Perms     = "perms";
}

public sealed class CurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    private ClaimsPrincipal? Principal => accessor.HttpContext?.User;

    public bool IsAuthenticated => Principal?.Identity?.IsAuthenticated == true;

    public int UserId => GetInt(ClaimTypes.NameIdentifier) ?? GetInt("sub") ?? 0;

    public int? CompanyId => GetInt(DitiClaims.CompanyId);
    public int? BranchId  => GetInt(DitiClaims.BranchId);
    public int? EmpId     => GetInt(DitiClaims.EmpId);
    public int? ClientId  => GetInt(DitiClaims.ClientId);
    public int? LoginType => GetInt(DitiClaims.LoginType);

    public string RoleCode  => Principal?.FindFirst(DitiClaims.RoleCode)?.Value ?? string.Empty;
    public string? DeviceId => Principal?.FindFirst(DitiClaims.DeviceId)?.Value;

    public IReadOnlyCollection<int> BranchIds =>
        (Principal?.FindFirst(DitiClaims.BranchIds)?.Value ?? string.Empty)
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(x => int.TryParse(x, out var v) ? v : 0)
            .Where(x => x > 0)
            .ToArray();

    public IReadOnlyCollection<string> Permissions =>
        Principal?.FindAll(DitiClaims.Perms).Select(c => c.Value).ToArray() ?? [];

    public bool IsSuperAdmin => RoleCode == RoleCodes.SuperAdmin;

    public bool Has(string permissionCode) =>
        IsSuperAdmin || Permissions.Contains(permissionCode, StringComparer.Ordinal);

    public int RequireCompanyId() =>
        CompanyId ?? throw DomainException.Forbidden(
            "This request needs a tenant context. A platform administrator must impersonate a company first.");

    public int RequireEmpId() =>
        EmpId ?? throw DomainException.Forbidden("This login is not linked to an employee record.");

    private int? GetInt(string claimType)
    {
        var raw = Principal?.FindFirst(claimType)?.Value;
        return int.TryParse(raw, out var value) ? value : null;
    }
}
