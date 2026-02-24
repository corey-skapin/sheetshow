namespace SheetShow.Core.Constants;

/// <summary>JWT token expiry constants.</summary>
public static class TokenExpiry
{
    /// <summary>Access token lifetime in minutes.</summary>
    public const int AccessTokenMinutes = 15;

    /// <summary>Refresh token lifetime in days.</summary>
    public const int RefreshTokenDays = 90;
}
