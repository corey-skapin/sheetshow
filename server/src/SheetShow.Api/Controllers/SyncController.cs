// <copyright file="SyncController.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.Api.Controllers;

using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using SheetShow.Core.Constants;
using SheetShow.Core.Entities;
using SheetShow.Core.Services;
using SheetShow.Infrastructure.Persistence;

/// <summary>Sync push and pull endpoints for offline-first client synchronisation.</summary>
[ApiController]
[Route("api/v1/sync")]
[Authorize]
[EnableRateLimiting("default")]
public sealed class SyncController : ControllerBase
{
    private readonly ApplicationDbContext db;
    private readonly SyncService syncService;

    private string CurrentUserId => this.User.FindFirstValue(ClaimTypes.NameIdentifier)!;

    public SyncController(ApplicationDbContext db, SyncService syncService)
    {
        this.db = db;
        this.syncService = syncService;
    }

    /// <summary>POST /api/v1/sync/pull — fetch changes since a given timestamp.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPost("pull")]
    public async Task<IActionResult> Pull([FromBody] SyncPullRequest request, CancellationToken ct)
    {
        var since = request.Since ?? DateTimeOffset.MinValue;

        var changes = await this.db.SyncLogs
            .Where(l =>
                l.UserId == this.CurrentUserId &&
                l.DeviceId != request.DeviceId &&
                l.AppliedAt > since)
            .OrderBy(l => l.AppliedAt)
            .Take(SyncConstants.MaxBatchSize)
            .ToListAsync(ct);

        var hasMore = changes.Count == SyncConstants.MaxBatchSize;

        return this.Ok(new
        {
            changes = changes.Select(l => new
            {
                l.EntityType,
                l.EntityId,
                l.Operation,
                l.PayloadJson,
                l.AppliedAt,
            }),
            hasMore,
            serverTime = DateTimeOffset.UtcNow,
        });
    }

    /// <summary>POST /api/v1/sync/push — push a batch of local operations to the server.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPost("push")]
    public async Task<IActionResult> Push([FromBody] SyncPushRequest request, CancellationToken ct)
    {
        var existingLogs = await this.db.SyncLogs
            .Where(l => l.UserId == this.CurrentUserId)
            .ToListAsync(ct);

        var result = this.syncService.ProcessPush(request.Operations, existingLogs);

        // Persist accepted operations to sync_log
        foreach (var (op, res) in request.Operations.Zip(result.Results))
        {
            if (res.Status == "accepted")
            {
                this.db.SyncLogs.Add(new SyncLog
                {
                    Id = Guid.NewGuid(),
                    UserId = this.CurrentUserId,
                    DeviceId = request.DeviceId,
                    EntityType = op.EntityType,
                    EntityId = op.EntityId,
                    Operation = op.Operation,
                    PayloadJson = op.PayloadJson,
                    AppliedAt = DateTimeOffset.UtcNow,
                });
            }
        }

        await this.db.SaveChangesAsync(ct);

        return this.Ok(result);
    }
}

public record SyncPullRequest(string DeviceId, DateTimeOffset? Since, IReadOnlyList<string>? EntityTypes);

public record SyncPushRequest(string DeviceId, IReadOnlyList<SyncOperation> Operations);
