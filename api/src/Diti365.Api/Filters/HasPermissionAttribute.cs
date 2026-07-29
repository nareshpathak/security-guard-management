using Diti365.Application.Abstractions;
using Diti365.Domain;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Extensions.DependencyInjection;

namespace Diti365.Api.Filters;

/// <summary>
/// Server-side permission check, backed by sec.RolePermission.
///
/// The web and mobile clients also hide UI the user cannot use, but that is presentation
/// only. This attribute is the actual boundary.
/// </summary>
[AttributeUsage(AttributeTargets.Method | AttributeTargets.Class, AllowMultiple = true)]
public sealed class HasPermissionAttribute(string permission) : Attribute, IAsyncActionFilter
{
    public string Permission { get; } = permission;

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var current = context.HttpContext.RequestServices.GetRequiredService<ICurrentUser>();

        if (!current.IsAuthenticated)
        {
            context.Result = new UnauthorizedResult();
            return;
        }

        if (!current.Has(Permission))
            throw new DomainException(ErrorCodes.PermissionDenied,
                $"Your role does not have the '{Permission}' permission.", 403);

        await next().ConfigureAwait(false);
    }
}
