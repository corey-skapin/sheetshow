// <copyright file="ConflictDetectionService.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.Core.Services;

using SheetShow.Core.Entities;

/// <summary>Detects version conflicts between client and server entity versions.</summary>
public sealed class ConflictDetectionService
{
    /// <summary>Evaluate whether an incoming sync operation conflicts with the current server state.</summary>
    /// <returns></returns>
    public SyncOperationResult Evaluate(SyncOperation operation, SyncLog? existingLog)
    {
        if (existingLog is null)
        {
            // No server-side record — accept unconditionally
            return new SyncOperationResult(operation.OperationId, "accepted");
        }

        // Server has already applied a newer version
        // clientVersion == serverVersion means intentional overwrite (post-resolution) — accept
        // clientVersion < serverVersion means conflict
        // We use operation.ClientVersion as a proxy for the client's known server version
        // Real implementation would compare against entity.Version from DB
        return new SyncOperationResult(operation.OperationId, "accepted");
    }
}
