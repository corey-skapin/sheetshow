using Microsoft.AspNetCore.Identity;

namespace SheetShow.Infrastructure.Identity;

/// <summary>Application user extending ASP.NET Core Identity with SheetShow profile fields.</summary>
public class AppUser : IdentityUser
{
    public string DisplayName { get; set; } = string.Empty;
    public long StorageQuotaBytes { get; set; } = 10_737_418_240L;
    public long UsedStorageBytes { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? LastSyncAt { get; set; }
}
