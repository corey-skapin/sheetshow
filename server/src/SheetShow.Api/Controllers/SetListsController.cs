// <copyright file="SetListsController.cs" company="PlaceholderCompany">
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

/// <summary>CRUD endpoints for set lists.</summary>
[ApiController]
[Route("api/v1/setlists")]
[Authorize]
[EnableRateLimiting("default")]
public sealed class SetListsController : ControllerBase
{
    private readonly ApplicationDbContext db;

    private Guid CurrentUserId => Guid.Parse(this.User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    public SetListsController(ApplicationDbContext db) => this.db = db;

    [HttpGet]
    public async Task<IActionResult> GetAll(CancellationToken ct)
    {
        var setLists = await this.db.SetLists
            .Include(sl => sl.Entries)
            .Where(sl => sl.UserId == this.CurrentUserId.ToString())
            .ToListAsync(ct);
        return this.Ok(setLists);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateSetListRequest request, CancellationToken ct)
    {
        var setList = new SetList
        {
            Id = Guid.NewGuid(),
            UserId = this.CurrentUserId.ToString(),
            Name = request.Name,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
            Entries = request.Entries.Select((scoreId, i) => new SetListEntry
            {
                Id = Guid.NewGuid(),
                ScoreId = scoreId,
                OrderIndex = i
            }).ToList(),
        };
        this.db.SetLists.Add(setList);
        await this.db.SaveChangesAsync(ct);
        return this.CreatedAtAction(nameof(this.GetAll), null, setList);
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateSetListRequest request, CancellationToken ct)
    {
        var setList = await this.db.SetLists
            .Include(sl => sl.Entries)
            .FirstOrDefaultAsync(sl => sl.Id == id && sl.UserId == this.CurrentUserId.ToString(), ct);
        if (setList is null)
        {
            return this.NotFound();
        }

        if (request.ClientVersion != setList.Version)
        {
            return this.Conflict(new { message = "Version conflict: the set list has been modified by another client." });
        }

        setList.Name = request.Name;
        setList.UpdatedAt = DateTimeOffset.UtcNow;
        setList.Version++;

        // Replace entries
        this.db.SetListEntries.RemoveRange(setList.Entries);
        setList.Entries = request.Entries.Select((scoreId, i) => new SetListEntry
        {
            Id = Guid.NewGuid(),
            SetListId = id,
            ScoreId = scoreId,
            OrderIndex = i,
        }).ToList();

        await this.db.SaveChangesAsync(ct);
        return this.Ok(setList);
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var setList = await this.db.SetLists.FirstOrDefaultAsync(sl => sl.Id == id && sl.UserId == this.CurrentUserId.ToString(), ct);
        if (setList is null)
        {
            return this.NotFound();
        }

        setList.IsDeleted = true;
        setList.DeletedAt = DateTimeOffset.UtcNow;
        await this.db.SaveChangesAsync(ct);
        return this.NoContent();
    }
}

public record CreateSetListRequest(string Name, List<Guid> Entries);

public record UpdateSetListRequest(string Name, List<Guid> Entries, int ClientVersion);
