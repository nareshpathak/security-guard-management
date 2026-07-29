using System.Text.Json;
using Diti365.Domain;
using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.Mvc;

namespace Diti365.Api.Middleware;

/// <summary>
/// Turns every unhandled exception into RFC 7807 problem+json carrying a machine
/// readable code and the trace id. docs/prd/02-api.md §9.
/// </summary>
public sealed class ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public async Task InvokeAsync(HttpContext ctx)
    {
        try
        {
            await next(ctx).ConfigureAwait(false);
        }
        catch (DomainException ex)
        {
            await WriteAsync(ctx, ex.StatusCode, ex.Code, ex.Message, ex.Errors).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (ctx.RequestAborted.IsCancellationRequested)
        {
            // The client went away. Nothing to report.
            ctx.Response.StatusCode = 499;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unhandled exception on {Method} {Path}", ctx.Request.Method, ctx.Request.Path);
            await WriteAsync(ctx, 500, ErrorCodes.Internal,
                "Something went wrong. Quote the trace id when reporting this.", null).ConfigureAwait(false);
        }
    }

    private static async Task WriteAsync(
        HttpContext ctx, int status, string code, string detail,
        IReadOnlyDictionary<string, string[]>? errors)
    {
        if (ctx.Response.HasStarted) return;

        var problem = new ProblemDetails
        {
            Type = $"https://docs.diti365.com/errors/{code}",
            Title = TitleFor(status),
            Status = status,
            Detail = detail,
            Instance = ctx.Request.Path
        };
        problem.Extensions["code"] = code;
        problem.Extensions["traceId"] = ctx.TraceIdentifier;
        if (errors is not null) problem.Extensions["errors"] = errors;

        ctx.Response.Clear();
        ctx.Response.StatusCode = status;
        ctx.Response.ContentType = "application/problem+json";
        await ctx.Response.WriteAsync(JsonSerializer.Serialize(problem, Json)).ConfigureAwait(false);
    }

    private static string TitleFor(int status) => status switch
    {
        400 => "Bad request",
        401 => "Not authenticated",
        402 => "Subscription required",
        403 => "Not permitted",
        404 => "Not found",
        409 => "Conflict",
        422 => "Request rejected",
        423 => "Locked",
        429 => "Too many requests",
        _   => "Server error"
    };
}
