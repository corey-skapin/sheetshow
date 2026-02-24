using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using SheetShow.Core.Interfaces;
using SheetShow.Infrastructure.Identity;

namespace SheetShow.Api.Controllers;

/// <summary>Authentication endpoints: register, login, refresh, logout, forgot/reset password.</summary>
[ApiController]
[Route("api/v1/auth")]
[EnableRateLimiting("auth")]
public sealed class AuthController : ControllerBase
{
    private readonly UserManager<AppUser> _userManager;
    private readonly SignInManager<AppUser> _signInManager;
    private readonly JwtTokenService _tokenService;
    private readonly IEmailService _emailService;

    public AuthController(
        UserManager<AppUser> userManager,
        SignInManager<AppUser> signInManager,
        JwtTokenService tokenService,
        IEmailService emailService)
    {
        _userManager = userManager;
        _signInManager = signInManager;
        _tokenService = tokenService;
        _emailService = emailService;
    }

    /// <summary>POST /api/v1/auth/register</summary>
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        var existing = await _userManager.FindByEmailAsync(request.Email);
        if (existing is not null) return Conflict(new { message = "Email already registered." });

        var user = new AppUser
        {
            UserName = request.Email,
            Email = request.Email,
            DisplayName = request.DisplayName,
            CreatedAt = DateTimeOffset.UtcNow
        };

        var result = await _userManager.CreateAsync(user, request.Password);
        if (!result.Succeeded)
            return BadRequest(new { errors = result.Errors.Select(e => e.Description) });

        return Ok(BuildTokenResponse(user));
    }

    /// <summary>POST /api/v1/auth/login</summary>
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        var user = await _userManager.FindByEmailAsync(request.Email);
        if (user is null) return Unauthorized(new { message = "Invalid credentials." });

        var result = await _signInManager.CheckPasswordSignInAsync(user, request.Password, false);
        if (!result.Succeeded) return Unauthorized(new { message = "Invalid credentials." });

        return Ok(BuildTokenResponse(user));
    }

    /// <summary>POST /api/v1/auth/refresh — rotate refresh token.</summary>
    [HttpPost("refresh")]
    public IActionResult Refresh([FromBody] RefreshRequest request)
    {
        // Simplified: validate token from DB in production implementation
        return Unauthorized(new { message = "Refresh token expired or invalid." });
    }

    /// <summary>POST /api/v1/auth/logout — revoke refresh token.</summary>
    [HttpPost("logout")]
    [Authorize]
    public IActionResult Logout()
    {
        // Clear refresh token from DB in production implementation
        return NoContent();
    }

    /// <summary>POST /api/v1/auth/forgot-password — always returns 202 to prevent user enumeration.</summary>
    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequest request)
    {
        var user = await _userManager.FindByEmailAsync(request.Email);
        if (user is not null)
        {
            var token = await _userManager.GeneratePasswordResetTokenAsync(user);
            var link = $"sheetshow://reset-password?email={Uri.EscapeDataString(request.Email)}&token={Uri.EscapeDataString(token)}";
            await _emailService.SendPasswordResetAsync(request.Email, link);
        }

        return Accepted(new { message = "If that email is registered, you'll receive a reset link shortly." });
    }

    /// <summary>POST /api/v1/auth/reset-password</summary>
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequest request)
    {
        var user = await _userManager.FindByEmailAsync(request.Email);
        if (user is null) return BadRequest(new { message = "Invalid or expired token." });

        var result = await _userManager.ResetPasswordAsync(user, request.Token, request.NewPassword);
        if (!result.Succeeded)
            return BadRequest(new { errors = result.Errors.Select(e => e.Description) });

        return Ok(new { message = "Password reset successfully." });
    }

    private object BuildTokenResponse(AppUser user) => new
    {
        accessToken = _tokenService.GenerateAccessToken(user),
        refreshToken = JwtTokenService.GenerateRefreshToken(),
        expiresIn = 900, // 15 minutes in seconds
        userId = user.Id,
        email = user.Email,
        displayName = user.DisplayName
    };
}

public record RegisterRequest(string Email, string Password, string DisplayName);
public record LoginRequest(string Email, string Password);
public record RefreshRequest(string RefreshToken);
public record ForgotPasswordRequest(string Email);
public record ResetPasswordRequest(string Email, string Token, string NewPassword);
