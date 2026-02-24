// <copyright file="ScoresController.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.Api.Controllers;

using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using SheetShow.Core.Entities;
using SheetShow.Core.Interfaces;

/// <summary>CRUD endpoints for sheet music scores.</summary>
[ApiController]
[Route("api/v1/[controller]")]
[Authorize]
[EnableRateLimiting("default")]
public sealed class ScoresController : ControllerBase
{
    private readonly IScoreRepository scores;
    private readonly IFileStorageService storage;

    public ScoresController(IScoreRepository scores, IFileStorageService storage)
    {
        this.scores = scores;
        this.storage = storage;
    }

    private Guid CurrentUserId => Guid.Parse(this.User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    /// <summary>GET /api/v1/scores — list scores, optionally filtered by folder or updated since timestamp.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] Guid? folderId,
        [FromQuery] DateTimeOffset? since,
        CancellationToken ct)
    {
        var scores = await this.scores.GetAllAsync(this.CurrentUserId, folderId, since, ct);
        return this.Ok(scores);
    }

    /// <summary>GET /api/v1/scores/{id} — get a single score with download URL.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id, CancellationToken ct)
    {
        var score = await this.scores.GetByIdAsync(id, this.CurrentUserId, ct);
        if (score is null)
        {
            return this.NotFound();
        }

        var downloadUrl = await this.storage.GenerateDownloadUrlAsync(score.BlobPath, TimeSpan.FromMinutes(15), ct);
        return this.Ok(new { score, blobDownloadUrl = downloadUrl });
    }

    /// <summary>POST /api/v1/scores — create score metadata.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateScoreRequest request, CancellationToken ct)
    {
        var score = new Score
        {
            Id = Guid.NewGuid(),
            UserId = this.CurrentUserId.ToString(),
            Title = request.Title,
            Filename = request.Filename,
            BlobPath = $"{this.CurrentUserId}/{Guid.NewGuid()}/{request.Filename}",
            TotalPages = request.TotalPages,
            FolderId = request.FolderId,
        };

        var created = await this.scores.CreateAsync(score, ct);
        return this.CreatedAtAction(nameof(this.GetById), new { id = created.Id }, created);
    }

    /// <summary>PUT /api/v1/scores/{id} — update score metadata with optimistic concurrency.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateScoreRequest request, CancellationToken ct)
    {
        try
        {
            var score = await this.scores.GetByIdAsync(id, this.CurrentUserId, ct);
            if (score is null)
            {
                return this.NotFound();
            }

            score.Title = request.Title;
            score.FolderId = request.FolderId;
            score.Version = request.ClientVersion;

            var updated = await this.scores.UpdateAsync(score, ct);
            return this.Ok(updated);
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("conflict"))
        {
            return this.Conflict(new { message = ex.Message });
        }
    }

    /// <summary>DELETE /api/v1/scores/{id} — soft-delete a score.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        await this.scores.SoftDeleteAsync(id, this.CurrentUserId, ct);
        return this.NoContent();
    }

    /// <summary>POST /api/v1/scores/{id}/upload-url — get a pre-signed URL to upload the PDF.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPost("{id:guid}/upload-url")]
    [EnableRateLimiting("uploads")]
    public async Task<IActionResult> GetUploadUrl(Guid id, CancellationToken ct)
    {
        var score = await this.scores.GetByIdAsync(id, this.CurrentUserId, ct);
        if (score is null)
        {
            return this.NotFound();
        }

        var url = await this.storage.GenerateUploadUrlAsync(score.BlobPath, TimeSpan.FromMinutes(15), ct);
        return this.Ok(new { uploadUrl = url });
    }

    /// <summary>GET /api/v1/scores/{id}/download-url — get a pre-signed URL to download the PDF.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpGet("{id:guid}/download-url")]
    public async Task<IActionResult> GetDownloadUrl(Guid id, CancellationToken ct)
    {
        var score = await this.scores.GetByIdAsync(id, this.CurrentUserId, ct);
        if (score is null)
        {
            return this.NotFound();
        }

        var url = await this.storage.GenerateDownloadUrlAsync(score.BlobPath, TimeSpan.FromMinutes(15), ct);
        return this.Ok(new { downloadUrl = url });
    }
}

public record CreateScoreRequest(string Title, string Filename, int TotalPages, Guid? FolderId);

public record UpdateScoreRequest(string Title, Guid? FolderId, int ClientVersion);
