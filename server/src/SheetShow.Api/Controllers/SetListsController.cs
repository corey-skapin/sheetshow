using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using SheetShow.Core.Entities;
using SheetShow.Infrastructure.Persistence;
using System.Security.Claims;

namespace SheetShow.Api.Controllers;

/// <summary>CRUD endpoints for set lists.</summary>
[ApiController]
[Route("api/v1/setlists")]
[Authorize]
[EnableRateLimiting("default")]
public sealed class SetListsController : ControllerBase
{
    private readonly ApplicationDbContext _db;
    private Guid CurrentUserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    public SetListsController(ApplicationDbContext db) => _db = db;

    [HttpGet]
    public async Task<IActionResult> GetAll(CancellationToken ct)
    {
        var setLists = await _db.SetLists
            .Include(sl => sl.Entries)
            .Where(sl => sl.UserId == CurrentUserId.ToString())
            .ToListAsync(ct);
        return Ok(setLists);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateSetListRequest request, CancellationToken ct)
    {
        var setList = new SetList
        {
            Id = Guid.NewGuid(),
            UserId = CurrentUserId.ToString(),
            Name = request.Name,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
            Entries = request.Entries.Select((scoreId, i) => new SetListEntry
            {
                Id = Guid.NewGuid(),
                ScoreId = scoreId,
                OrderIndex = i
            }).ToList()
        };
        _db.SetLists.Add(setList);
        await _db.SaveChangesAsync(ct);
        return CreatedAtAction(nameof(GetAll), null, setList);
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateSetListRequest request, CancellationToken ct)
    {
        var setList = await _db.SetLists
            .Include(sl => sl.Entries)
            .FirstOrDefaultAsync(sl => sl.Id == id && sl.UserId == CurrentUserId.ToString(), ct);
        if (setList is null) return NotFound();

        setList.Name = request.Name;
        setList.UpdatedAt = DateTimeOffset.UtcNow;
        setList.Version++;

        // Replace entries
        _db.SetListEntries.RemoveRange(setList.Entries);
        setList.Entries = request.Entries.Select((scoreId, i) => new SetListEntry
        {
            Id = Guid.NewGuid(),
            SetListId = id,
            ScoreId = scoreId,
            OrderIndex = i
        }).ToList();

        await _db.SaveChangesAsync(ct);
        return Ok(setList);
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var setList = await _db.SetLists.FirstOrDefaultAsync(sl => sl.Id == id && sl.UserId == CurrentUserId.ToString(), ct);
        if (setList is null) return NotFound();

        setList.IsDeleted = true;
        setList.DeletedAt = DateTimeOffset.UtcNow;
        await _db.SaveChangesAsync(ct);
        return NoContent();
    }
}

public record CreateSetListRequest(string Name, List<Guid> Entries);
public record UpdateSetListRequest(string Name, List<Guid> Entries, int ClientVersion);
