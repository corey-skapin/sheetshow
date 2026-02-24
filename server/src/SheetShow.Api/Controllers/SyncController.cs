using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using SheetShow.Core.Constants;
using SheetShow.Core.Entities;
using SheetShow.Core.Services;
using SheetShow.Infrastructure.Persistence;
using System.Security.Claims;

namespace SheetShow.Api.Controllers;

/// <summary>Sync push and pull endpoints for offline-first client synchronisation.</summary>
[ApiController]
[Route("api/v1/sync")]
[Authorize]
[EnableRateLimiting("default")]
public sealed class SyncController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private readonly SyncService _syncService;
    private string CurrentUserId => User.FindFirstValue(ClaimTypes.NameIdentifier)!;

    public SyncController(ApplicationDbContext db, SyncService syncService)
    {
        _db = db;
        _syncService = syncService;
    }

    /// <summary>POST /api/v1/sync/pull — fetch changes since a given timestamp.</summary>
    [HttpPost("pull")]
    public async Task<IActionResult> Pull([FromBody] SyncPullRequest request, CancellationToken ct)
    {
        var since = request.Since ?? DateTimeOffset.MinValue;

        var changes = await _db.SyncLogs
            .Where(l =>
                l.UserId == CurrentUserId &&
                l.DeviceId != request.DeviceId &&
                l.AppliedAt > since)
            .OrderBy(l => l.AppliedAt)
            .Take(SyncConstants.MaxBatchSize)
            .ToListAsync(ct);

        var hasMore = changes.Count == SyncConstants.MaxBatchSize;

        return Ok(new
        {
            changes = changes.Select(l => new
            {
                l.EntityType,
                l.EntityId,
                l.Operation,
                l.PayloadJson,
                l.AppliedAt
            }),
            hasMore,
            serverTime = DateTimeOffset.UtcNow
        });
    }

    /// <summary>POST /api/v1/sync/push — push a batch of local operations to the server.</summary>
    [HttpPost("push")]
    public async Task<IActionResult> Push([FromBody] SyncPushRequest request, CancellationToken ct)
    {
        var existingLogs = await _db.SyncLogs
            .Where(l => l.UserId == CurrentUserId)
            .ToListAsync(ct);

        var result = _syncService.ProcessPush(request.Operations, existingLogs);

        // Persist accepted operations to sync_log
        foreach (var (op, res) in request.Operations.Zip(result.Results))
        {
            if (res.Status == "accepted")
            {
                _db.SyncLogs.Add(new SyncLog
                {
                    Id = Guid.NewGuid(),
                    UserId = CurrentUserId,
                    DeviceId = request.DeviceId,
                    EntityType = op.EntityType,
                    EntityId = op.EntityId,
                    Operation = op.Operation,
                    PayloadJson = op.PayloadJson,
                    AppliedAt = DateTimeOffset.UtcNow
                });
            }
        }
        await _db.SaveChangesAsync(ct);

        return Ok(result);
    }
}

public record SyncPullRequest(string DeviceId, DateTimeOffset? Since, IReadOnlyList<string>? EntityTypes);
public record SyncPushRequest(string DeviceId, IReadOnlyList<SyncOperation> Operations);
