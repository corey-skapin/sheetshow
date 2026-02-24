using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using SheetShow.Core.Entities;
using SheetShow.Infrastructure.Persistence;
using System.Security.Claims;

namespace SheetShow.Api.Controllers;

/// <summary>CRUD endpoints for folder organization.</summary>
[ApiController]
[Route("api/v1/[controller]")]
[Authorize]
[EnableRateLimiting("default")]
public sealed class FoldersController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private Guid CurrentUserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    public FoldersController(ApplicationDbContext db) => _db = db;

    [HttpGet]
    public async Task<IActionResult> GetAll(CancellationToken ct)
    {
        var folders = await _db.Folders
            .Where(f => f.UserId == CurrentUserId.ToString())
            .ToListAsync(ct);
        return Ok(folders);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateFolderRequest request, CancellationToken ct)
    {
        var folder = new Folder
        {
            Id = Guid.NewGuid(),
            UserId = CurrentUserId.ToString(),
            Name = request.Name,
            ParentFolderId = request.ParentFolderId,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        };
        _db.Folders.Add(folder);
        await _db.SaveChangesAsync(ct);
        return CreatedAtAction(nameof(GetAll), null, folder);
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateFolderRequest request, CancellationToken ct)
    {
        var folder = await _db.Folders.FirstOrDefaultAsync(f => f.Id == id && f.UserId == CurrentUserId.ToString(), ct);
        if (folder is null) return NotFound();

        folder.Name = request.Name;
        folder.ParentFolderId = request.ParentFolderId;
        folder.UpdatedAt = DateTimeOffset.UtcNow;
        folder.Version++;
        await _db.SaveChangesAsync(ct);
        return Ok(folder);
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var folder = await _db.Folders.FirstOrDefaultAsync(f => f.Id == id && f.UserId == CurrentUserId.ToString(), ct);
        if (folder is null) return NotFound();

        folder.IsDeleted = true;
        folder.DeletedAt = DateTimeOffset.UtcNow;
        folder.UpdatedAt = DateTimeOffset.UtcNow;

        // Move scores inside to root
        var scores = await _db.Scores.Where(s => s.FolderId == id).ToListAsync(ct);
        foreach (var score in scores) score.FolderId = null;

        await _db.SaveChangesAsync(ct);
        return NoContent();
    }
}

public record CreateFolderRequest(string Name, Guid? ParentFolderId);
public record UpdateFolderRequest(string Name, Guid? ParentFolderId, int ClientVersion);
