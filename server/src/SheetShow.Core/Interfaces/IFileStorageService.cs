namespace SheetShow.Core.Interfaces;

/// <summary>Abstraction over file/blob storage (Azure Blob Storage, S3, etc.).</summary>
public interface IFileStorageService
{
    /// <summary>Generate a pre-signed URL for uploading a file.</summary>
    Task<string> GenerateUploadUrlAsync(string blobPath, TimeSpan expiry, CancellationToken cancellationToken = default);

    /// <summary>Generate a pre-signed URL for downloading a file.</summary>
    Task<string> GenerateDownloadUrlAsync(string blobPath, TimeSpan expiry, CancellationToken cancellationToken = default);

    /// <summary>Soft-delete a blob (marks for lifecycle expiry).</summary>
    Task DeleteAsync(string blobPath, CancellationToken cancellationToken = default);
}
