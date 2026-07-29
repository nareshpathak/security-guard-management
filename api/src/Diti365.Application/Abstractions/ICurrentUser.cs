namespace Diti365.Application.Abstractions;

/// <summary>
/// The authenticated caller, read from JWT claims.
///
/// This is the only source of CompanyId in the entire solution. The value never comes
/// from a route, query string or request body - TenantGuardFilter rejects any request
/// that tries. See docs/prd/02-api.md §2.3.
/// </summary>
public interface ICurrentUser
{
    bool IsAuthenticated { get; }
    int UserId { get; }
    int? CompanyId { get; }
    int? BranchId { get; }
    int? EmpId { get; }
    int? ClientId { get; }
    string RoleCode { get; }
    int? LoginType { get; }
    string? DeviceId { get; }
    IReadOnlyCollection<int> BranchIds { get; }
    IReadOnlyCollection<string> Permissions { get; }

    bool IsSuperAdmin { get; }
    bool Has(string permissionCode);

    /// <summary>Throws when the caller has no tenant. Use before any tenant-scoped call.</summary>
    int RequireCompanyId();

    /// <summary>Throws when the caller is not linked to an employee record.</summary>
    int RequireEmpId();
}
