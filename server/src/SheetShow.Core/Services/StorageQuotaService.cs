// <copyright file="StorageQuotaService.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.Core.Services;

using SheetShow.Core.Constants;

/// <summary>Manages per-user storage quota checks and usage tracking.</summary>
public sealed class StorageQuotaService
{
    /// <summary>Check whether adding the specified bytes would exceed quota.</summary>
    /// <returns></returns>
    public bool ExceedsQuota(long currentUsed, long quotaBytes, long fileBytes)
    {
        return currentUsed + fileBytes > quotaBytes;
    }

    /// <summary>Calculate the new used bytes after adding a file.</summary>
    /// <returns></returns>
    public long AddUsage(long currentUsed, long fileBytes)
    {
        return currentUsed + fileBytes;
    }

    /// <summary>Calculate the new used bytes after removing a file.</summary>
    /// <returns></returns>
    public long RemoveUsage(long currentUsed, long fileBytes)
    {
        return Math.Max(0, currentUsed - fileBytes);
    }
}
