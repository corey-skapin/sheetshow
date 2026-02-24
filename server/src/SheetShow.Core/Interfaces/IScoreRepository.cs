// <copyright file="IScoreRepository.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.Core.Interfaces;

using SheetShow.Core.Entities;

/// <summary>Repository abstraction for Score entities.</summary>
public interface IScoreRepository
{
    /// <summary>Get all non-deleted scores for a user, optionally filtered by folder and since a timestamp.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    Task<IReadOnlyList<Score>> GetAllAsync(
        Guid userId,
        Guid? folderId = null,
        DateTimeOffset? since = null,
        CancellationToken cancellationToken = default);

    /// <summary>Get a score by ID with ownership check.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    Task<Score?> GetByIdAsync(Guid id, Guid userId, CancellationToken cancellationToken = default);

    /// <summary>Create a new score record.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    Task<Score> CreateAsync(Score score, CancellationToken cancellationToken = default);

    /// <summary>Update a score, incrementing Version and enforcing optimistic concurrency.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    Task<Score> UpdateAsync(Score score, CancellationToken cancellationToken = default);

    /// <summary>Soft-delete a score by setting IsDeleted=true and DeletedAt=now.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    Task SoftDeleteAsync(Guid id, Guid userId, CancellationToken cancellationToken = default);
}
