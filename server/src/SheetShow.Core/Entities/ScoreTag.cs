// <copyright file="ScoreTag.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.Core.Entities;

/// <summary>Tag associated with a score.</summary>
public class ScoreTag
{
    public Guid ScoreId { get; set; }

    public string UserId { get; set; } = string.Empty;

    public string Tag { get; set; } = string.Empty;
}
