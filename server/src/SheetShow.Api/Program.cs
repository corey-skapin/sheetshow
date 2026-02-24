// <copyright file="Program.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

using System.Text;
using System.Threading.RateLimiting;
using Azure.Storage.Blobs;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Serilog;
using SheetShow.Api.Middleware;
using SheetShow.Core.Interfaces;
using SheetShow.Core.Services;
using SheetShow.Infrastructure.Azure;
using SheetShow.Infrastructure.Email;
using SheetShow.Infrastructure.Identity;
using SheetShow.Infrastructure.Persistence;
using SheetShow.Infrastructure.Persistence.Repositories;

var builder = WebApplication.CreateBuilder(args);

// Serilog
builder.Host.UseSerilog((ctx, cfg) => cfg.ReadFrom.Configuration(ctx.Configuration));

// Database
builder.Services.AddDbContext<ApplicationDbContext>(opts =>
    opts.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// ASP.NET Core Identity
builder.Services.AddIdentity<AppUser, IdentityRole>(opts =>
{
    opts.Password.RequireDigit = true;
    opts.Password.RequiredLength = 8;
    opts.User.RequireUniqueEmail = true;
})
.AddEntityFrameworkStores<ApplicationDbContext>()
.AddDefaultTokenProviders();

// JWT Bearer authentication
var jwtSecret = builder.Configuration["Jwt:SecretKey"]
    ?? throw new InvalidOperationException("Jwt:SecretKey is required.");
builder.Services.AddAuthentication(opts =>
{
    opts.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    opts.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(opts =>
{
    opts.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
        ValidateIssuer = true,
        ValidIssuer = builder.Configuration["Jwt:Issuer"],
        ValidateAudience = true,
        ValidAudience = builder.Configuration["Jwt:Audience"],
        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero,
    };
});
builder.Services.AddAuthorization();

// Application services
builder.Services.AddScoped<IScoreRepository, ScoreRepository>();
builder.Services.AddScoped<IEmailService, SmtpEmailService>();
builder.Services.AddScoped<ConflictDetectionService>();
builder.Services.AddScoped<SyncService>();
builder.Services.AddScoped<JwtTokenService>();

// Azure Blob Storage
var blobConnectionString = builder.Configuration.GetConnectionString("AzureBlobStorage");
if (!string.IsNullOrEmpty(blobConnectionString))
{
    builder.Services.AddSingleton(_ => new BlobServiceClient(blobConnectionString));
    builder.Services.AddScoped<IFileStorageService, AzureBlobStorageService>();
}

// Rate limiting
builder.Services.AddRateLimiter(opts =>
{
    var rl = builder.Configuration.GetSection("RateLimiting");

    opts.AddFixedWindowLimiter("auth", o =>
    {
        o.Window = TimeSpan.FromSeconds(rl.GetValue<int>("AuthWindowSeconds", 60));
        o.PermitLimit = rl.GetValue<int>("AuthMaxRequests", 10);
        o.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        o.QueueLimit = 0;
    });

    opts.AddFixedWindowLimiter("uploads", o =>
    {
        o.Window = TimeSpan.FromSeconds(rl.GetValue<int>("UploadWindowSeconds", 60));
        o.PermitLimit = rl.GetValue<int>("UploadMaxRequests", 30);
        o.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        o.QueueLimit = 0;
    });

    opts.AddFixedWindowLimiter("default", o =>
    {
        o.Window = TimeSpan.FromSeconds(rl.GetValue<int>("DefaultWindowSeconds", 60));
        o.PermitLimit = rl.GetValue<int>("DefaultMaxRequests", 300);
        o.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        o.QueueLimit = 0;
    });

    opts.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
});

// CORS — allow any localhost origin (http or https) regardless of port, for local dev
builder.Services.AddCors(opts =>
    opts.AddDefaultPolicy(policy =>
        policy.SetIsOriginAllowed(origin =>
                Uri.TryCreate(origin, UriKind.Absolute, out var uri) &&
                (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps) &&
                uri.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase))
              .AllowAnyHeader()
              .AllowAnyMethod()));

// Controllers + Swagger
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "SheetShow API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "Bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = "Enter your JWT Bearer token",
    });
});

var app = builder.Build();

// Middleware pipeline
app.UseMiddleware<RequestLoggingMiddleware>();
app.UseMiddleware<GlobalExceptionMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();

// For WebApplicationFactory in integration tests
public partial class Program
{
}
