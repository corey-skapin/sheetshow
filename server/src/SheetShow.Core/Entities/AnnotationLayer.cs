namespace SheetShow.Core.Entities;

/// <summary>Ink annotation layer for a single page of a score.</summary>
public class AnnotationLayer
{
    public Guid Id { get; set; }
    public Guid ScoreId { get; set; }
    public string UserId { get; set; } = string.Empty;
    public int PageNumber { get; set; }
    public string StrokesJson { get; set; } = "[]";
    public int Version { get; set; } = 1;
    public DateTimeOffset UpdatedAt { get; set; }
}
