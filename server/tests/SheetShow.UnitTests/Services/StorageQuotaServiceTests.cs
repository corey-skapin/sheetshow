// <copyright file="StorageQuotaServiceTests.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.UnitTests.Services;

using FluentAssertions;
using SheetShow.Core.Services;
using Xunit;

public sealed class StorageQuotaServiceTests
{
    private readonly StorageQuotaService sut = new();

    // ─── ExceedsQuota ───────────────────────────────────────────────────────────

    [Fact]
    public void ExceedsQuota_WhenUnderLimit_ReturnsFalse()
    {
        this.sut.ExceedsQuota(currentUsed: 100, quotaBytes: 1000, fileBytes: 800)
            .Should().BeFalse();
    }

    [Fact]
    public void ExceedsQuota_WhenExactlyAtLimit_ReturnsFalse()
    {
        // currentUsed + fileBytes == quotaBytes → NOT exceeding
        this.sut.ExceedsQuota(currentUsed: 200, quotaBytes: 1000, fileBytes: 800)
            .Should().BeFalse();
    }

    [Fact]
    public void ExceedsQuota_WhenOverLimit_ReturnsTrue()
    {
        this.sut.ExceedsQuota(currentUsed: 200, quotaBytes: 1000, fileBytes: 801)
            .Should().BeTrue();
    }

    [Fact]
    public void ExceedsQuota_ZeroUsed_WhenFileFitsExactly_ReturnsFalse()
    {
        this.sut.ExceedsQuota(currentUsed: 0, quotaBytes: 500, fileBytes: 500)
            .Should().BeFalse();
    }

    [Fact]
    public void ExceedsQuota_ZeroUsed_WhenFileExceedsQuota_ReturnsTrue()
    {
        this.sut.ExceedsQuota(currentUsed: 0, quotaBytes: 500, fileBytes: 501)
            .Should().BeTrue();
    }

    // ─── AddUsage ───────────────────────────────────────────────────────────────

    [Fact]
    public void AddUsage_ReturnsSumOfCurrentAndFile()
    {
        this.sut.AddUsage(currentUsed: 300, fileBytes: 200)
            .Should().Be(500);
    }

    [Fact]
    public void AddUsage_ZeroCurrentUsed_ReturnsFileBytes()
    {
        this.sut.AddUsage(currentUsed: 0, fileBytes: 1024)
            .Should().Be(1024);
    }

    [Fact]
    public void AddUsage_ZeroFileBytes_ReturnsCurrentUsed()
    {
        this.sut.AddUsage(currentUsed: 512, fileBytes: 0)
            .Should().Be(512);
    }

    // ─── RemoveUsage ────────────────────────────────────────────────────────────

    [Fact]
    public void RemoveUsage_WhenFileSmallerThanUsed_ReturnsDifference()
    {
        this.sut.RemoveUsage(currentUsed: 1000, fileBytes: 300)
            .Should().Be(700);
    }

    [Fact]
    public void RemoveUsage_WhenFileEqualsUsed_ReturnsZero()
    {
        this.sut.RemoveUsage(currentUsed: 500, fileBytes: 500)
            .Should().Be(0);
    }

    [Fact]
    public void RemoveUsage_WhenFileLargerThanUsed_ClampsToZero()
    {
        this.sut.RemoveUsage(currentUsed: 100, fileBytes: 200)
            .Should().Be(0);
    }

    [Fact]
    public void RemoveUsage_ZeroCurrentUsed_ReturnsZero()
    {
        this.sut.RemoveUsage(currentUsed: 0, fileBytes: 100)
            .Should().Be(0);
    }
}
