using Diti365.Domain;
using Microsoft.AspNetCore.Mvc.Filters;

namespace Diti365.Api.Filters;

/// <summary>
/// Rejects any request that tries to supply its own tenant identifier.
///
/// CompanyID comes from the JWT and nowhere else. Without this filter a caller could
/// append ?companyId=2 and a repository that forgot to ignore it would leak another
/// agency's data. Failing the request outright is the only reliable defence, because
/// it does not depend on every one of 150 procedures being called correctly.
///
/// docs/prd/02-api.md §2.3
/// </summary>
public sealed class TenantGuardFilter : IAsyncActionFilter
{
    private static readonly string[] Forbidden =
    [
        "companyid", "company_id", "tenantid", "tenant_id"
    ];

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var user = context.HttpContext.User;
        var isSuperAdmin = user.FindFirst("role_code")?.Value == RoleCodes.SuperAdmin;

        if (!isSuperAdmin)
        {
            foreach (var key in context.HttpContext.Request.Query.Keys)
            {
                if (Forbidden.Contains(key.ToLowerInvariant()))
                    throw new DomainException(ErrorCodes.TenantParamForbidden,
                        $"The parameter '{key}' cannot be supplied by the client. The tenant is taken from the access token.",
                        400);
            }

            foreach (var (key, _) in context.ActionArguments)
            {
                if (Forbidden.Contains(key.ToLowerInvariant()))
                    throw new DomainException(ErrorCodes.TenantParamForbidden,
                        $"The parameter '{key}' cannot be supplied by the client. The tenant is taken from the access token.",
                        400);
            }
        }

        await next().ConfigureAwait(false);
    }
}
