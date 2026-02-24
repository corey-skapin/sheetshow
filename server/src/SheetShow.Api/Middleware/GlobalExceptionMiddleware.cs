// <copyright file="GlobalExceptionMiddleware.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.Api.Middleware;

using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;

/// <summary>Catches all unhandled exceptions and maps them to RFC 7807 ProblemDetails responses.</summary>
public sealed class GlobalExceptionMiddleware
{
    private readonly RequestDelegate next;
    private readonly ILogger<GlobalExceptionMiddleware> logger;

    public GlobalExceptionMiddleware(RequestDelegate next, ILogger<GlobalExceptionMiddleware> logger)
    {
        this.next = next;
        this.logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await this.next(context);
        }
        catch (Exception ex)
        {
            this.logger.LogError(ex, "Unhandled exception for {Method} {Path}", context.Request.Method, context.Request.Path);
            await WriteProblemDetailsAsync(context, ex);
        }
    }

    private static async Task WriteProblemDetailsAsync(HttpContext context, Exception exception)
    {
        var (status, title, type) = exception switch
        {
            UnauthorizedAccessException => (HttpStatusCode.Forbidden, "Forbidden", "https://httpstatuses.com/403"),
            ArgumentException or InvalidOperationException => (HttpStatusCode.BadRequest, "Bad Request", "https://httpstatuses.com/400"),
            KeyNotFoundException => (HttpStatusCode.NotFound, "Not Found", "https://httpstatuses.com/404"),
            _ => (HttpStatusCode.InternalServerError, "Internal Server Error", "https://httpstatuses.com/500"),
        };

        var isServerError = status == HttpStatusCode.InternalServerError;
        var detail = isServerError ? "An unexpected error occurred. Please try again later." : exception.Message;

        var problem = new ProblemDetails
        {
            Type = type,
            Title = title,
            Status = (int)status,
            Detail = detail,
            Extensions = { ["traceId"] = context.TraceIdentifier },
        };

        context.Response.StatusCode = (int)status;
        context.Response.ContentType = "application/problem+json";
        await context.Response.WriteAsync(JsonSerializer.Serialize(problem));
    }
}
