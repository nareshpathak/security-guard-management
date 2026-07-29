using Diti365.Contracts.Common;
using Diti365.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Diti365.Api.Controllers.V1;

/// <summary>
/// Base for legacy APK routes. Returns the exact envelope
/// { Success, Status, Id, Message, Data[] } that Diti365.apk v4.8 deserialises.
/// </summary>
[ApiController]
[Authorize]
[Produces("application/json")]
public abstract class LegacyControllerBase : ControllerBase
{
    protected CancellationToken Ct => HttpContext.RequestAborted;
    protected string? ClientIp => HttpContext.Connection.RemoteIpAddress?.ToString();

    protected ActionResult<LegacyEnvelope<T>> OkData<T>(IReadOnlyList<T> data, string message = "OK", int id = 0) =>
        Ok(LegacyEnvelope<T>.Ok(data, message, id));

    protected ActionResult<LegacyEnvelope<object>> OkEmpty(string message = "OK", int id = 0) =>
        Ok(LegacyEnvelope<object>.Ok(message, id));

    protected ActionResult<LegacyEnvelope<object>> FromSp(SpResult result)
    {
        if (!result.Success)
            return Ok(LegacyEnvelope<object>.Fail(result.Message, result.Status == 0 ? 400 : result.Status));

        return Ok(LegacyEnvelope<object>.Ok(result.Message, result.Id));
    }

    protected ActionResult<LegacyEnvelope<T>> FromSpFailOrData<T>(SpResult result, IReadOnlyList<T> data)
    {
        if (!result.Success)
            return Ok(LegacyEnvelope<T>.Fail(result.Message, result.Status == 0 ? 400 : result.Status));

        return Ok(LegacyEnvelope<T>.Ok(data, result.Message, result.Id));
    }

    protected static DomainException Bad(string message) =>
        new(ErrorCodes.ValidationFailed, message, 422);
}
