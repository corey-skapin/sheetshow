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

        // clientVersion == 0 means the client has not yet incorporated any server-side changes
        // for this entity. If the server already has a log entry, the client is behind → conflict.
        if (operation.ClientVersion == 0)
        {
            return new SyncOperationResult(
                operation.OperationId,
                "conflict",
                ConflictType: "version_mismatch",
                ServerPayload: existingLog.PayloadJson);
        }

        // Client has synced at least once — accept the operation
        return new SyncOperationResult(operation.OperationId, "accepted");
    }
}
