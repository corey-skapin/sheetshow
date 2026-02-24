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

        // clientVersion == serverVersion: the client is aware of the latest server version — accept
        // clientVersion < serverVersion: server has a newer version than the client knew about — conflict
        if (operation.ClientVersion >= existingLog.Version)
        {
            return new SyncOperationResult(operation.OperationId, "accepted");
        }

        return new SyncOperationResult(
            operation.OperationId,
            "conflict",
            ConflictType: "version_mismatch",
            ServerPayload: existingLog.PayloadJson,
            ServerVersion: existingLog.Version);
    }
}
