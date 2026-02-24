// <copyright file="FoldersController.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.Api.Controllers;

using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using SheetShow.Core.Entities;
using SheetShow.Infrastructure.Persistence;

/// <summary>CRUD endpoints for folder organization.</summary>
[ApiController]
[Route("api/v1/[controller]")]
[Authorize]
[EnableRateLimiting("default")]
public sealed class FoldersController : ControllerBase
{
    private readonly ApplicationDbContext db;

    private Guid CurrentUserId => Guid.Parse(this.User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    public FoldersController(ApplicationDbContext db) => this.db = db;

    [HttpGet]
    public async Task<IActionResult> GetAll(CancellationToken ct)
    {
        var folders = await this.db.Folders
            .Where(f => f.UserId == this.CurrentUserId.ToString())
            .ToListAsync(ct);
        return this.Ok(folders);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateFolderRequest request, CancellationToken ct)
    {
        var folder = new Folder
        {
            Id = Guid.NewGuid(),
            UserId = this.CurrentUserId.ToString(),
            Name = request.Name,
            ParentFolderId = request.ParentFolderId,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        };
        this.db.Folders.Add(folder);
        await this.db.SaveChangesAsync(ct);
        return this.CreatedAtAction(nameof(this.GetAll), null, folder);
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateFolderRequest request, CancellationToken ct)
    {
        var folder = await this.db.Folders.FirstOrDefaultAsync(f => f.Id == id && f.UserId == this.CurrentUserId.ToString(), ct);
        if (folder is null)
        {
            return this.NotFound();
        }

        if (request.ClientVersion != folder.Version)
        {
            return this.Conflict(new { message = "Version conflict: the folder has been modified by another client." });
        }

        folder.Name = request.Name;
        folder.ParentFolderId = request.ParentFolderId;
        folder.UpdatedAt = DateTimeOffset.UtcNow;
        folder.Version++;
        await this.db.SaveChangesAsync(ct);
        return this.Ok(folder);
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var folder = await this.db.Folders.FirstOrDefaultAsync(f => f.Id == id && f.UserId == this.CurrentUserId.ToString(), ct);
        if (folder is null)
        {
            return this.NotFound();
        }

        folder.IsDeleted = true;
        folder.DeletedAt = DateTimeOffset.UtcNow;
        folder.UpdatedAt = DateTimeOffset.UtcNow;

        // Move scores inside to root
        var scores = await this.db.Scores.Where(s => s.FolderId == id).ToListAsync(ct);
        foreach (var score in scores)
        {
            score.FolderId = null;
        }

        await this.db.SaveChangesAsync(ct);
        return this.NoContent();
    }
}

public record CreateFolderRequest(string Name, Guid? ParentFolderId);

public record UpdateFolderRequest(string Name, Guid? ParentFolderId, int ClientVersion);
