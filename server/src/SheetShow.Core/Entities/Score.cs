namespace SheetShow.Core.Entities;

/// <summary>Represents a PDF sheet music score owned by a user.</summary>
public class Score
{
    public Guid Id { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Filename { get; set; } = string.Empty;
    public string BlobPath { get; set; } = string.Empty;
    public int TotalPages { get; set; }
    public Guid? FolderId { get; set; }
    public int Version { get; set; } = 1;
    public bool IsDeleted { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

    public ICollection<ScoreTag> Tags { get; set; } = new List<ScoreTag>();
}
