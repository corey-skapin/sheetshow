using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using SheetShow.Core.Entities;
using SheetShow.Core.Interfaces;
using System.Security.Claims;

namespace SheetShow.Api.Controllers;

/// <summary>CRUD endpoints for sheet music scores.</summary>
[ApiController]
[Route("api/v1/[controller]")]
[Authorize]
[EnableRateLimiting("default")]
public sealed class ScoresController : ControllerBase
{
    private readonly IScoreRepository _scores;
    private readonly IFileStorageService _storage;

    public ScoresController(IScoreRepository scores, IFileStorageService storage)
    {
        _scores = scores;
        _storage = storage;
    }

    private Guid CurrentUserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    /// <summary>GET /api/v1/scores — list scores, optionally filtered by folder or updated since timestamp.</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] Guid? folderId,
        [FromQuery] DateTimeOffset? since,
        CancellationToken ct)
    {
        var scores = await _scores.GetAllAsync(CurrentUserId, folderId, since, ct);
        return Ok(scores);
    }

    /// <summary>GET /api/v1/scores/{id} — get a single score with download URL.</summary>
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id, CancellationToken ct)
    {
        var score = await _scores.GetByIdAsync(id, CurrentUserId, ct);
        if (score is null) return NotFound();

        var downloadUrl = await _storage.GenerateDownloadUrlAsync(score.BlobPath, TimeSpan.FromMinutes(15), ct);
        return Ok(new { score, blobDownloadUrl = downloadUrl });
    }

    /// <summary>POST /api/v1/scores — create score metadata.</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateScoreRequest request, CancellationToken ct)
    {
        var score = new Score
        {
            Id = Guid.NewGuid(),
            UserId = CurrentUserId.ToString(),
            Title = request.Title,
            Filename = request.Filename,
            BlobPath = $"{CurrentUserId}/{Guid.NewGuid()}/{request.Filename}",
            TotalPages = request.TotalPages,
            FolderId = request.FolderId
        };

        var created = await _scores.CreateAsync(score, ct);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    /// <summary>PUT /api/v1/scores/{id} — update score metadata with optimistic concurrency.</summary>
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateScoreRequest request, CancellationToken ct)
    {
        try
        {
            var score = await _scores.GetByIdAsync(id, CurrentUserId, ct);
            if (score is null) return NotFound();

            score.Title = request.Title;
            score.FolderId = request.FolderId;
            score.Version = request.ClientVersion;

            var updated = await _scores.UpdateAsync(score, ct);
            return Ok(updated);
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("conflict"))
        {
            return Conflict(new { message = ex.Message });
        }
    }

    /// <summary>DELETE /api/v1/scores/{id} — soft-delete a score.</summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        await _scores.SoftDeleteAsync(id, CurrentUserId, ct);
        return NoContent();
    }

    /// <summary>POST /api/v1/scores/{id}/upload-url — get a pre-signed URL to upload the PDF.</summary>
    [HttpPost("{id:guid}/upload-url")]
    [EnableRateLimiting("uploads")]
    public async Task<IActionResult> GetUploadUrl(Guid id, CancellationToken ct)
    {
        var score = await _scores.GetByIdAsync(id, CurrentUserId, ct);
        if (score is null) return NotFound();

        var url = await _storage.GenerateUploadUrlAsync(score.BlobPath, TimeSpan.FromMinutes(15), ct);
        return Ok(new { uploadUrl = url });
    }

    /// <summary>GET /api/v1/scores/{id}/download-url — get a pre-signed URL to download the PDF.</summary>
    [HttpGet("{id:guid}/download-url")]
    public async Task<IActionResult> GetDownloadUrl(Guid id, CancellationToken ct)
    {
        var score = await _scores.GetByIdAsync(id, CurrentUserId, ct);
        if (score is null) return NotFound();

        var url = await _storage.GenerateDownloadUrlAsync(score.BlobPath, TimeSpan.FromMinutes(15), ct);
        return Ok(new { downloadUrl = url });
    }
}

public record CreateScoreRequest(string Title, string Filename, int TotalPages, Guid? FolderId);
public record UpdateScoreRequest(string Title, Guid? FolderId, int ClientVersion);
