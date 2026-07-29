using System.Diagnostics;
using Diti365.Application.Abstractions;
using Microsoft.Extensions.Logging;

namespace Diti365.Api.Middleware;

/// <summary>
/// Structured request log with the tenant and user attached, so a support question
/// ("what did this agency see at 09:14?") is answerable from the logs alone.
/// </summary>
public sealed class RequestLoggingMiddleware(RequestDelegate next, ILogger<RequestLoggingMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext ctx, ICurrentUser current)
    {
        var sw = Stopwatch.StartNew();
        try
        {
            await next(ctx).ConfigureAwait(false);
        }
        finally
        {
            sw.Stop();
            var level = ctx.Response.StatusCode >= 500 ? LogLevel.Error
                      : ctx.Response.StatusCode >= 400 ? LogLevel.Warning
                      : sw.ElapsedMilliseconds > 1000  ? LogLevel.Warning
                      : LogLevel.Information;

            logger.Log(level,
                "{Method} {Path} -> {StatusCode} in {ElapsedMs} ms (company {CompanyId}, user {UserId}, trace {TraceId})",
                ctx.Request.Method, ctx.Request.Path, ctx.Response.StatusCode, sw.ElapsedMilliseconds,
                current.CompanyId, current.UserId, ctx.TraceIdentifier);
        }
    }
}
