using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace SheetShow.Infrastructure.Identity;

/// <summary>Generates and validates JWT access tokens and opaque refresh tokens.</summary>
public sealed class JwtTokenService
{
    private readonly IConfiguration _config;
    private readonly UserManager<AppUser> _userManager;

    public JwtTokenService(IConfiguration config, UserManager<AppUser> userManager)
    {
        _config = config;
        _userManager = userManager;
    }

    /// <summary>Generate a short-lived JWT access token for the given user.</summary>
    public string GenerateAccessToken(AppUser user)
    {
        var secret = _config["Jwt:SecretKey"] ?? throw new InvalidOperationException("JWT secret not configured.");
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id),
            new Claim(ClaimTypes.Email, user.Email ?? string.Empty),
            new Claim("displayName", user.DisplayName)
        };

        var expiry = DateTime.UtcNow.AddMinutes(
            _config.GetValue<int>("Jwt:AccessTokenExpiryMinutes", 15));

        var token = new JwtSecurityToken(
            issuer: _config["Jwt:Issuer"],
            audience: _config["Jwt:Audience"],
            claims: claims,
            expires: expiry,
            signingCredentials: creds);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    /// <summary>Generate a cryptographically secure opaque refresh token.</summary>
    public static string GenerateRefreshToken()
    {
        var bytes = new byte[64];
        RandomNumberGenerator.Fill(bytes);
        return Convert.ToBase64String(bytes);
    }
}
