using Microsoft.AspNetCore.Mvc;
using System.Net;
using System.Text.Json;

namespace SheetShow.Api.Middleware;

/// <summary>Catches all unhandled exceptions and maps them to RFC 7807 ProblemDetails responses.</summary>
public sealed class GlobalExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionMiddleware> _logger;

    public GlobalExceptionMiddleware(RequestDelegate next, ILogger<GlobalExceptionMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled exception for {Method} {Path}", context.Request.Method, context.Request.Path);
            await WriteProblemDetailsAsync(context, ex);
        }
    }

    private static async Task WriteProblemDetailsAsync(HttpContext context, Exception exception)
    {
        var (status, title, type) = exception switch
        {
            UnauthorizedAccessException => (HttpStatusCode.Unauthorized, "Unauthorized", "https://httpstatuses.com/401"),
            ArgumentException or InvalidOperationException => (HttpStatusCode.BadRequest, "Bad Request", "https://httpstatuses.com/400"),
            KeyNotFoundException => (HttpStatusCode.NotFound, "Not Found", "https://httpstatuses.com/404"),
            _ => (HttpStatusCode.InternalServerError, "Internal Server Error", "https://httpstatuses.com/500")
        };

        var problem = new ProblemDetails
        {
            Type = type,
            Title = title,
            Status = (int)status,
            Detail = exception.Message,
            Extensions = { ["traceId"] = context.TraceIdentifier }
        };

        context.Response.StatusCode = (int)status;
        context.Response.ContentType = "application/problem+json";
        await context.Response.WriteAsync(JsonSerializer.Serialize(problem));
    }
}
