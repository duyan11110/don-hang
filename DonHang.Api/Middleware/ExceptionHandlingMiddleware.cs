using DonHang.Domain;
using Microsoft.AspNetCore.Mvc;

namespace DonHang.Api.Middleware;

// lesson: backend.l1.exception-handling-middleware
// Turns an uncaught exception into one RFC 9457 problem+json response instead
// of the default HTML error page, and logs it once before it leaves the app.
public sealed class ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
{
    // lesson: backend.l2.problem-types
    // Every `type` Đơn Hàng sends starts with this, followed by one code per
    // kind of problem. A client compares `type`, never `title` or `detail`.
    private const string ProblemTypeBase = "https://donhang.local/problems/";

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (KeyNotFoundException ex)
        {
            logger.LogWarning(ex, "request for a resource that does not exist");
            await WriteProblemAsync(context, StatusCodes.Status404NotFound, "Not found", ex.Message);
        }
        catch (ArgumentException ex)
        {
            logger.LogWarning(ex, "request rejected as invalid");
            await WriteProblemAsync(context, StatusCodes.Status400BadRequest, "Invalid request", ex.Message);
        }
        // lesson: design.l2.domain-model
        // The domain says which rule was broken (ex.Code); only here does that become HTTP.
        catch (OrderStatusException ex)
        {
            logger.LogWarning(ex, "order {OrderId} cannot change status: {Code}", ex.OrderId, ex.Code);
            await WriteProblemAsync(context, StatusCodes.Status409Conflict, "Order status does not allow this", ex.Message,
                type: ProblemTypeBase + ex.Code, orderId: ex.OrderId);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "unhandled exception");
            await WriteProblemAsync(context, StatusCodes.Status500InternalServerError, "Server error", "something went wrong");
        }
    }

    // lesson: backend.l2.problem-types
    // `type` left null is sent as nothing at all, which a client reads as
    // "about:blank". The order id is an extension member: an extra field a
    // client that does not know it simply ignores.
    private static async Task WriteProblemAsync(
        HttpContext context, int statusCode, string title, string detail, string? type = null, int? orderId = null)
    {
        context.Response.StatusCode = statusCode;
        var problem = new ProblemDetails
        {
            Type = type,
            Status = statusCode,
            Title = title,
            Detail = detail,
        };
        if (orderId is not null) problem.Extensions["orderId"] = orderId;
        await context.Response.WriteAsJsonAsync(problem, options: null, contentType: "application/problem+json");
    }
}
