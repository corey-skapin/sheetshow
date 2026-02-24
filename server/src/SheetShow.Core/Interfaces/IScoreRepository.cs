using SheetShow.Core.Entities;

namespace SheetShow.Core.Interfaces;

/// <summary>Repository abstraction for Score entities.</summary>
public interface IScoreRepository
{
    /// <summary>Get all non-deleted scores for a user, optionally filtered by folder and since a timestamp.</summary>
    Task<IReadOnlyList<Score>> GetAllAsync(
        Guid userId,
        Guid? folderId = null,
        DateTimeOffset? since = null,
        CancellationToken cancellationToken = default);

    /// <summary>Get a score by ID with ownership check.</summary>
    Task<Score?> GetByIdAsync(Guid id, Guid userId, CancellationToken cancellationToken = default);

    /// <summary>Create a new score record.</summary>
    Task<Score> CreateAsync(Score score, CancellationToken cancellationToken = default);

    /// <summary>Update a score, incrementing Version and enforcing optimistic concurrency.</summary>
    Task<Score> UpdateAsync(Score score, CancellationToken cancellationToken = default);

    /// <summary>Soft-delete a score by setting IsDeleted=true and DeletedAt=now.</summary>
    Task SoftDeleteAsync(Guid id, Guid userId, CancellationToken cancellationToken = default);
}
