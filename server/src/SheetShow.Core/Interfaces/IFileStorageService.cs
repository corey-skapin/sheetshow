// <copyright file="IFileStorageService.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.Core.Interfaces;

/// <summary>Abstraction over file/blob storage (Azure Blob Storage, S3, etc.).</summary>
public interface IFileStorageService
{
    /// <summary>Generate a pre-signed URL for uploading a file.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    Task<string> GenerateUploadUrlAsync(string blobPath, TimeSpan expiry, CancellationToken cancellationToken = default);

    /// <summary>Generate a pre-signed URL for downloading a file.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    Task<string> GenerateDownloadUrlAsync(string blobPath, TimeSpan expiry, CancellationToken cancellationToken = default);

    /// <summary>Soft-delete a blob (marks for lifecycle expiry).</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    Task DeleteAsync(string blobPath, CancellationToken cancellationToken = default);
}
