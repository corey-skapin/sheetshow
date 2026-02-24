// <copyright file="SyncService.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.Core.Services;

using SheetShow.Core.Constants;
using SheetShow.Core.Entities;

/// <summary>Server-side sync orchestration: handles pull and push operations.</summary>
public sealed class SyncService
{
    private readonly ConflictDetectionService conflictDetection;

    public SyncService(ConflictDetectionService conflictDetection)
    {
        this.conflictDetection = conflictDetection;
    }

    /// <summary>Process a batch push of operations from a client device.</summary>
    /// <returns></returns>
    public SyncPushResult ProcessPush(IReadOnlyList<SyncOperation> operations, IReadOnlyList<SyncLog> existingLogs)
    {
        var results = new List<SyncOperationResult>();

        foreach (var op in operations.Take(SyncConstants.MaxBatchSize))
        {
            var existingLog = existingLogs.FirstOrDefault(l =>
                l.EntityId == op.EntityId && l.EntityType == op.EntityType);

            var result = this.conflictDetection.Evaluate(op, existingLog);
            results.Add(result);
        }

        return new SyncPushResult(results);
    }
}

public record SyncOperation(
    string OperationId,
    string EntityType,
    Guid EntityId,
    string Operation,
    int ClientVersion,
    string? PayloadJson);

public record SyncOperationResult(
    string OperationId,
    string Status,
    string? ConflictType = null,
    string? ServerPayload = null,
    int? ServerVersion = null);

public record SyncPushResult(IReadOnlyList<SyncOperationResult> Results);
