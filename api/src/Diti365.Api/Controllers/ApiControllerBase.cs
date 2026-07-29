using Diti365.Application.Abstractions;
using Diti365.Contracts.Common;
using Diti365.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Diti365.Api.Controllers;

[ApiController]
[Authorize]
[Produces("application/json")]
public abstract class ApiControllerBase(ICurrentUser currentUser) : ControllerBase
{
    protected ICurrentUser Me { get; } = currentUser;

    protected CancellationToken Ct => HttpContext.RequestAborted;

    protected string? ClientIp => HttpContext.Connection.RemoteIpAddress?.ToString();

    /// <summary>Wraps a paged repository result in the v2 envelope.</summary>
    protected ActionResult<ApiResponse<IReadOnlyList<T>>> Paged<T>(PagedResult<T> result, PagedQuery q) =>
        Ok(ApiResponse<IReadOnlyList<T>>.Ok(result.Items, new ApiMeta
        {
            Page = q.Page, PageSize = q.PageSize, Total = result.Total,
            SortBy = q.SortBy, SortDir = q.SortDir
        }));

    protected ActionResult<ApiResponse<T>> Data<T>(T data) => Ok(ApiResponse<T>.Ok(data));

    /// <summary>
    /// Turns a command procedure's envelope into an HTTP result. A procedure that
    /// reports failure without throwing still becomes a proper error response rather
    /// than a 200 with Success=false, which the v2 clients would silently ignore.
    /// </summary>
    protected ActionResult<ApiResponse<SpResult>> Command(SpResult result)
    {
        if (!result.Success)
            throw new DomainException(
                result.Status == 404 ? ErrorCodes.NotFound : ErrorCodes.ValidationFailed,
                result.Message,
                result.Status is >= 400 and < 600 ? result.Status : 422);

        return Ok(ApiResponse<SpResult>.Ok(result));
    }
}
