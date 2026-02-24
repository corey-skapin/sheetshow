namespace SheetShow.Core.Entities;

/// <summary>An ordered entry in a set list referencing a score.</summary>
public class SetListEntry
{
    public Guid Id { get; set; }
    public Guid SetListId { get; set; }
    public Guid ScoreId { get; set; }
    public int OrderIndex { get; set; }
}
