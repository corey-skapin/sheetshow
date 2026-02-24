namespace SheetShow.Core.Entities;

/// <summary>Audit log entry for sync operations applied to the server.</summary>
public class SyncLog
{
    public Guid Id { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string DeviceId { get; set; } = string.Empty;
    public string EntityType { get; set; } = string.Empty;
    public Guid EntityId { get; set; }
    public string Operation { get; set; } = string.Empty;
    public string? PayloadJson { get; set; }
    public DateTimeOffset AppliedAt { get; set; }
}
