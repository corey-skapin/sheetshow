using SheetShow.Core.Constants;

namespace SheetShow.Core.Services;

/// <summary>Manages per-user storage quota checks and usage tracking.</summary>
public sealed class StorageQuotaService
{
    /// <summary>Check whether adding the specified bytes would exceed quota.</summary>
    public bool ExceedsQuota(long currentUsed, long quotaBytes, long fileBytes)
    {
        return currentUsed + fileBytes > quotaBytes;
    }

    /// <summary>Calculate the new used bytes after adding a file.</summary>
    public long AddUsage(long currentUsed, long fileBytes)
    {
        return currentUsed + fileBytes;
    }

    /// <summary>Calculate the new used bytes after removing a file.</summary>
    public long RemoveUsage(long currentUsed, long fileBytes)
    {
        return Math.Max(0, currentUsed - fileBytes);
    }
}
