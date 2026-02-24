// <copyright file="SetList.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.Core.Entities;

/// <summary>A named, ordered set list of scores for performance.</summary>
public class SetList
{
    public Guid Id { get; set; }

    public string UserId { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public int Version { get; set; } = 1;

    public bool IsDeleted { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }

    public ICollection<SetListEntry> Entries { get; set; } = new List<SetListEntry>();
}
