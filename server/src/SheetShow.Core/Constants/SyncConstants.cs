namespace SheetShow.Core.Constants;

/// <summary>Sync engine constants.</summary>
public static class SyncConstants
{
    /// <summary>Maximum number of operations in a single sync batch.</summary>
    public const int MaxBatchSize = 100;

    /// <summary>Maximum number of retry attempts for a failed sync operation.</summary>
    public const int MaxRetries = 10;

    /// <summary>Maximum size (bytes) for inline annotation storage.</summary>
    public const int AnnotationInlineSizeLimit = 65_536;
}
