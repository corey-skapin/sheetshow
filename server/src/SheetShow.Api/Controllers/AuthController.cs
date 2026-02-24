// <copyright file="AuthController.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using SheetShow.Core.Interfaces;
using SheetShow.Infrastructure.Identity;

/// <summary>Authentication endpoints: register, login, refresh, logout, forgot/reset password.</summary>
[ApiController]
[Route("api/v1/auth")]
[EnableRateLimiting("auth")]
public sealed class AuthController : ControllerBase
{
    private readonly UserManager<AppUser> userManager;
    private readonly SignInManager<AppUser> signInManager;
    private readonly JwtTokenService tokenService;
    private readonly IEmailService emailService;

    public AuthController(
        UserManager<AppUser> userManager,
        SignInManager<AppUser> signInManager,
        JwtTokenService tokenService,
        IEmailService emailService)
    {
        this.userManager = userManager;
        this.signInManager = signInManager;
        this.tokenService = tokenService;
        this.emailService = emailService;
    }

    /// <summary>POST /api/v1/auth/register.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        var existing = await this.userManager.FindByEmailAsync(request.Email);
        if (existing is not null)
        {
            return this.Conflict(new { message = "Email already registered." });
        }

        var user = new AppUser
        {
            UserName = request.Email,
            Email = request.Email,
            DisplayName = request.DisplayName,
            CreatedAt = DateTimeOffset.UtcNow,
        };

        var result = await this.userManager.CreateAsync(user, request.Password);
        if (!result.Succeeded)
        {
            return this.BadRequest(new { errors = result.Errors.Select(e => e.Description) });
        }

        return this.Ok(this.BuildTokenResponse(user));
    }

    /// <summary>POST /api/v1/auth/login.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        var user = await this.userManager.FindByEmailAsync(request.Email);
        if (user is null)
        {
            return this.Unauthorized(new { message = "Invalid credentials." });
        }

        var result = await this.signInManager.CheckPasswordSignInAsync(user, request.Password, false);
        if (!result.Succeeded)
        {
            return this.Unauthorized(new { message = "Invalid credentials." });
        }

        return this.Ok(this.BuildTokenResponse(user));
    }

    /// <summary>POST /api/v1/auth/refresh — rotate refresh token.</summary>
    /// <returns></returns>
    [HttpPost("refresh")]
    public IActionResult Refresh([FromBody] RefreshRequest request)
    {
        // Simplified: validate token from DB in production implementation
        return this.Unauthorized(new { message = "Refresh token expired or invalid." });
    }

    /// <summary>POST /api/v1/auth/logout — revoke refresh token.</summary>
    /// <returns></returns>
    [HttpPost("logout")]
    [Authorize]
    public IActionResult Logout()
    {
        // Clear refresh token from DB in production implementation
        return this.NoContent();
    }

    /// <summary>POST /api/v1/auth/forgot-password — always returns 202 to prevent user enumeration.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequest request)
    {
        var user = await this.userManager.FindByEmailAsync(request.Email);
        if (user is not null)
        {
            var token = await this.userManager.GeneratePasswordResetTokenAsync(user);
            var link = $"sheetshow://reset-password?email={Uri.EscapeDataString(request.Email)}&token={Uri.EscapeDataString(token)}";
            await this.emailService.SendPasswordResetAsync(request.Email, link);
        }

        return this.Accepted(new { message = "If that email is registered, you'll receive a reset link shortly." });
    }

    /// <summary>POST /api/v1/auth/reset-password.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequest request)
    {
        var user = await this.userManager.FindByEmailAsync(request.Email);
        if (user is null)
        {
            return this.BadRequest(new { message = "Invalid or expired token." });
        }

        var result = await this.userManager.ResetPasswordAsync(user, request.Token, request.NewPassword);
        if (!result.Succeeded)
        {
            return this.BadRequest(new { errors = result.Errors.Select(e => e.Description) });
        }

        return this.Ok(new { message = "Password reset successfully." });
    }

    private object BuildTokenResponse(AppUser user) => new
    {
        accessToken = this.tokenService.GenerateAccessToken(user),
        refreshToken = JwtTokenService.GenerateRefreshToken(),
        expiresIn = 900, // 15 minutes in seconds
        userId = user.Id,
        email = user.Email,
        displayName = user.DisplayName,
    };
}

public record RegisterRequest(string Email, string Password, string DisplayName);

public record LoginRequest(string Email, string Password);

public record RefreshRequest(string RefreshToken);

public record ForgotPasswordRequest(string Email);

public record ResetPasswordRequest(string Email, string Token, string NewPassword);
