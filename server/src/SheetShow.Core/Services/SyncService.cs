using SheetShow.Core.Entities;
using SheetShow.Core.Constants;

namespace SheetShow.Core.Services;

/// <summary>Server-side sync orchestration: handles pull and push operations.</summary>
public sealed class SyncService
{
    private readonly ConflictDetectionService _conflictDetection;

    public SyncService(ConflictDetectionService conflictDetection)
    {
        _conflictDetection = conflictDetection;
    }

    /// <summary>Process a batch push of operations from a client device.</summary>
    public SyncPushResult ProcessPush(IReadOnlyList<SyncOperation> operations, IReadOnlyList<SyncLog> existingLogs)
    {
        var results = new List<SyncOperationResult>();

        foreach (var op in operations.Take(SyncConstants.MaxBatchSize))
        {
            var existingLog = existingLogs.FirstOrDefault(l =>
                l.EntityId == op.EntityId && l.EntityType == op.EntityType);

            var result = _conflictDetection.Evaluate(op, existingLog);
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
