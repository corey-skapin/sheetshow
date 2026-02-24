using Microsoft.EntityFrameworkCore;
using SheetShow.Core.Entities;
using SheetShow.Core.Interfaces;

namespace SheetShow.Infrastructure.Persistence.Repositories;

/// <summary>EF Core implementation of IScoreRepository.</summary>
public sealed class ScoreRepository : IScoreRepository
{
    private readonly ApplicationDbContext _db;

    public ScoreRepository(ApplicationDbContext db)
    {
        _db = db;
    }

    /// <inheritdoc/>
    public async Task<IReadOnlyList<Score>> GetAllAsync(
        Guid userId,
        Guid? folderId = null,
        DateTimeOffset? since = null,
        CancellationToken cancellationToken = default)
    {
        var query = _db.Scores
            .Include(s => s.Tags)
            .Where(s => s.UserId == userId.ToString());

        if (folderId.HasValue)
            query = query.Where(s => s.FolderId == folderId.Value);

        if (since.HasValue)
            query = query.Where(s => s.UpdatedAt >= since.Value);

        return await query.OrderBy(s => s.Title).ToListAsync(cancellationToken);
    }

    /// <inheritdoc/>
    public async Task<Score?> GetByIdAsync(Guid id, Guid userId, CancellationToken cancellationToken = default)
    {
        return await _db.Scores
            .Include(s => s.Tags)
            .FirstOrDefaultAsync(s => s.Id == id && s.UserId == userId.ToString(), cancellationToken);
    }

    /// <inheritdoc/>
    public async Task<Score> CreateAsync(Score score, CancellationToken cancellationToken = default)
    {
        score.CreatedAt = DateTimeOffset.UtcNow;
        score.UpdatedAt = DateTimeOffset.UtcNow;
        score.Version = 1;
        _db.Scores.Add(score);
        await _db.SaveChangesAsync(cancellationToken);
        return score;
    }

    /// <inheritdoc/>
    public async Task<Score> UpdateAsync(Score score, CancellationToken cancellationToken = default)
    {
        var existing = await _db.Scores.FindAsync(new object[] { score.Id }, cancellationToken)
            ?? throw new KeyNotFoundException($"Score {score.Id} not found.");

        if (existing.Version != score.Version)
            throw new InvalidOperationException($"Version conflict: client={score.Version}, server={existing.Version}");

        existing.Title = score.Title;
        existing.FolderId = score.FolderId;
        existing.UpdatedAt = DateTimeOffset.UtcNow;
        existing.Version++;

        await _db.SaveChangesAsync(cancellationToken);
        return existing;
    }

    /// <inheritdoc/>
    public async Task SoftDeleteAsync(Guid id, Guid userId, CancellationToken cancellationToken = default)
    {
        var score = await _db.Scores.FindAsync(new object[] { id }, cancellationToken)
            ?? throw new KeyNotFoundException($"Score {id} not found.");

        if (score.UserId != userId.ToString())
            throw new UnauthorizedAccessException("Score does not belong to this user.");

        score.IsDeleted = true;
        score.DeletedAt = DateTimeOffset.UtcNow;
        score.UpdatedAt = DateTimeOffset.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);
    }
}
