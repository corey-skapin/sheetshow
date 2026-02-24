using Azure.Storage.Blobs;
using Azure.Storage.Sas;
using SheetShow.Core.Interfaces;

namespace SheetShow.Infrastructure.Azure;

/// <summary>Azure Blob Storage implementation of IFileStorageService.</summary>
public sealed class AzureBlobStorageService : IFileStorageService
{
    private readonly BlobServiceClient _blobServiceClient;
    private const string ContainerName = "scores";

    public AzureBlobStorageService(BlobServiceClient blobServiceClient)
    {
        _blobServiceClient = blobServiceClient;
    }

    /// <inheritdoc/>
    public async Task<string> GenerateUploadUrlAsync(
        string blobPath,
        TimeSpan expiry,
        CancellationToken cancellationToken = default)
    {
        var container = _blobServiceClient.GetBlobContainerClient(ContainerName);
        await container.CreateIfNotExistsAsync(cancellationToken: cancellationToken);

        var blobClient = container.GetBlobClient(blobPath);
        var sasBuilder = new BlobSasBuilder
        {
            BlobContainerName = ContainerName,
            BlobName = blobPath,
            Resource = "b",
            ExpiresOn = DateTimeOffset.UtcNow.Add(expiry)
        };
        sasBuilder.SetPermissions(BlobSasPermissions.Write | BlobSasPermissions.Create);

        return blobClient.GenerateSasUri(sasBuilder).ToString();
    }

    /// <inheritdoc/>
    public async Task<string> GenerateDownloadUrlAsync(
        string blobPath,
        TimeSpan expiry,
        CancellationToken cancellationToken = default)
    {
        var container = _blobServiceClient.GetBlobContainerClient(ContainerName);
        await container.CreateIfNotExistsAsync(cancellationToken: cancellationToken);

        var blobClient = container.GetBlobClient(blobPath);
        var sasBuilder = new BlobSasBuilder
        {
            BlobContainerName = ContainerName,
            BlobName = blobPath,
            Resource = "b",
            ExpiresOn = DateTimeOffset.UtcNow.Add(expiry)
        };
        sasBuilder.SetPermissions(BlobSasPermissions.Read);

        return blobClient.GenerateSasUri(sasBuilder).ToString();
    }

    /// <inheritdoc/>
    public async Task DeleteAsync(string blobPath, CancellationToken cancellationToken = default)
    {
        var container = _blobServiceClient.GetBlobContainerClient(ContainerName);
        var blobClient = container.GetBlobClient(blobPath);
        await blobClient.DeleteIfExistsAsync(cancellationToken: cancellationToken);
    }
}
