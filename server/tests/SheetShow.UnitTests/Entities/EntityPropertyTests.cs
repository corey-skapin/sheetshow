// <copyright file="EntityPropertyTests.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.UnitTests.Entities;

using FluentAssertions;
using SheetShow.Core.Entities;
using Xunit;

/// <summary>Ensures all entity property setters/getters work as expected.</summary>
public sealed class EntityPropertyTests
{
    [Fact]
    public void Score_Properties_CanBeSetAndRead()
    {
        var now = DateTimeOffset.UtcNow;
        var id = Guid.NewGuid();
        var folderId = Guid.NewGuid();

        var score = new Score
        {
            Id = id,
            UserId = "user-1",
            Title = "Bach Cello Suite No.1",
            Filename = "bach.pdf",
            BlobPath = "users/user-1/bach.pdf",
            TotalPages = 12,
            FolderId = folderId,
            Version = 3,
            IsDeleted = false,
            CreatedAt = now,
            UpdatedAt = now,
            Tags = new List<ScoreTag>(),
        };

        score.Id.Should().Be(id);
        score.UserId.Should().Be("user-1");
        score.Title.Should().Be("Bach Cello Suite No.1");
        score.Filename.Should().Be("bach.pdf");
        score.BlobPath.Should().Be("users/user-1/bach.pdf");
        score.TotalPages.Should().Be(12);
        score.FolderId.Should().Be(folderId);
        score.Version.Should().Be(3);
        score.IsDeleted.Should().BeFalse();
        score.DeletedAt.Should().BeNull();
        score.CreatedAt.Should().Be(now);
        score.UpdatedAt.Should().Be(now);
        score.Tags.Should().BeEmpty();
    }

    [Fact]
    public void Score_SoftDelete_SetsDeletedFields()
    {
        var score = new Score();
        var deletedAt = DateTimeOffset.UtcNow;

        score.IsDeleted = true;
        score.DeletedAt = deletedAt;

        score.IsDeleted.Should().BeTrue();
        score.DeletedAt.Should().Be(deletedAt);
    }

    [Fact]
    public void Folder_Properties_CanBeSetAndRead()
    {
        var now = DateTimeOffset.UtcNow;
        var id = Guid.NewGuid();
        var parentId = Guid.NewGuid();

        var folder = new Folder
        {
            Id = id,
            UserId = "user-1",
            Name = "Beethoven",
            ParentFolderId = parentId,
            Version = 2,
            IsDeleted = false,
            CreatedAt = now,
            UpdatedAt = now,
        };

        folder.Id.Should().Be(id);
        folder.UserId.Should().Be("user-1");
        folder.Name.Should().Be("Beethoven");
        folder.ParentFolderId.Should().Be(parentId);
        folder.Version.Should().Be(2);
        folder.IsDeleted.Should().BeFalse();
        folder.DeletedAt.Should().BeNull();
        folder.CreatedAt.Should().Be(now);
        folder.UpdatedAt.Should().Be(now);
    }

    [Fact]
    public void Folder_SoftDelete_SetsDeletedFields()
    {
        var folder = new Folder();
        var deletedAt = DateTimeOffset.UtcNow;

        folder.IsDeleted = true;
        folder.DeletedAt = deletedAt;

        folder.IsDeleted.Should().BeTrue();
        folder.DeletedAt.Should().Be(deletedAt);
    }

    [Fact]
    public void SetList_Properties_CanBeSetAndRead()
    {
        var now = DateTimeOffset.UtcNow;
        var id = Guid.NewGuid();

        var setList = new SetList
        {
            Id = id,
            UserId = "user-1",
            Name = "Concert 2026",
            Version = 1,
            IsDeleted = false,
            CreatedAt = now,
            UpdatedAt = now,
            Entries = new List<SetListEntry>(),
        };

        setList.Id.Should().Be(id);
        setList.UserId.Should().Be("user-1");
        setList.Name.Should().Be("Concert 2026");
        setList.Version.Should().Be(1);
        setList.IsDeleted.Should().BeFalse();
        setList.DeletedAt.Should().BeNull();
        setList.CreatedAt.Should().Be(now);
        setList.UpdatedAt.Should().Be(now);
        setList.Entries.Should().BeEmpty();
    }

    [Fact]
    public void SetList_SoftDelete_SetsDeletedFields()
    {
        var setList = new SetList();
        var deletedAt = DateTimeOffset.UtcNow;

        setList.IsDeleted = true;
        setList.DeletedAt = deletedAt;

        setList.IsDeleted.Should().BeTrue();
        setList.DeletedAt.Should().Be(deletedAt);
    }

    [Fact]
    public void SetListEntry_Properties_CanBeSetAndRead()
    {
        var id = Guid.NewGuid();
        var setListId = Guid.NewGuid();
        var scoreId = Guid.NewGuid();

        var entry = new SetListEntry
        {
            Id = id,
            SetListId = setListId,
            ScoreId = scoreId,
            OrderIndex = 3,
        };

        entry.Id.Should().Be(id);
        entry.SetListId.Should().Be(setListId);
        entry.ScoreId.Should().Be(scoreId);
        entry.OrderIndex.Should().Be(3);
    }

    [Fact]
    public void AnnotationLayer_Properties_CanBeSetAndRead()
    {
        var now = DateTimeOffset.UtcNow;
        var id = Guid.NewGuid();
        var scoreId = Guid.NewGuid();

        var layer = new AnnotationLayer
        {
            Id = id,
            ScoreId = scoreId,
            UserId = "user-1",
            PageNumber = 5,
            StrokesJson = "[{\"id\":\"s1\"}]",
            Version = 2,
            UpdatedAt = now,
        };

        layer.Id.Should().Be(id);
        layer.ScoreId.Should().Be(scoreId);
        layer.UserId.Should().Be("user-1");
        layer.PageNumber.Should().Be(5);
        layer.StrokesJson.Should().Be("[{\"id\":\"s1\"}]");
        layer.Version.Should().Be(2);
        layer.UpdatedAt.Should().Be(now);
    }

    [Fact]
    public void ScoreTag_Properties_CanBeSetAndRead()
    {
        var scoreId = Guid.NewGuid();

        var tag = new ScoreTag
        {
            ScoreId = scoreId,
            UserId = "user-1",
            Tag = "baroque",
        };

        tag.ScoreId.Should().Be(scoreId);
        tag.UserId.Should().Be("user-1");
        tag.Tag.Should().Be("baroque");
    }

    [Fact]
    public void Score_DefaultValues_AreCorrect()
    {
        var score = new Score();

        score.Version.Should().Be(1);
        score.IsDeleted.Should().BeFalse();
        score.Tags.Should().NotBeNull();
        score.UserId.Should().Be(string.Empty);
        score.Title.Should().Be(string.Empty);
        score.Filename.Should().Be(string.Empty);
        score.BlobPath.Should().Be(string.Empty);
    }

    [Fact]
    public void SetList_DefaultValues_AreCorrect()
    {
        var setList = new SetList();

        setList.Version.Should().Be(1);
        setList.IsDeleted.Should().BeFalse();
        setList.Entries.Should().NotBeNull();
        setList.UserId.Should().Be(string.Empty);
        setList.Name.Should().Be(string.Empty);
    }

    [Fact]
    public void AnnotationLayer_DefaultValues_AreCorrect()
    {
        var layer = new AnnotationLayer();

        layer.Version.Should().Be(1);
        layer.StrokesJson.Should().Be("[]");
        layer.UserId.Should().Be(string.Empty);
    }

    [Fact]
    public void Folder_DefaultValues_AreCorrect()
    {
        var folder = new Folder();

        folder.Version.Should().Be(1);
        folder.IsDeleted.Should().BeFalse();
        folder.ParentFolderId.Should().BeNull();
        folder.Name.Should().Be(string.Empty);
        folder.UserId.Should().Be(string.Empty);
    }
}
