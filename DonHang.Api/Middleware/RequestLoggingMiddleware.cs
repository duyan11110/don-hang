using System.Diagnostics;

namespace DonHang.Api.Middleware;

// lesson: backend.l1.middleware-pipeline
// Reused as-is by backend.l1.structured-logging (validation-errors-logging)
// and by backend.l1.protecting-an-endpoint, which reads what it logs about a
// rejected request. One piece of pipeline, not one demo per lesson.
public sealed class RequestLoggingMiddleware(RequestDelegate next, ILogger<RequestLoggingMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        var stopwatch = Stopwatch.StartNew();
        await next(context);
        stopwatch.Stop();

        logger.LogInformation(
            "{Method} {Path} responded {StatusCode} in {ElapsedMs}ms",
            context.Request.Method,
            context.Request.Path,
            context.Response.StatusCode,
            stopwatch.ElapsedMilliseconds);
    }
}
