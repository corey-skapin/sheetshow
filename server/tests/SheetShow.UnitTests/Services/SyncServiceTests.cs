// <copyright file="SyncServiceTests.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.UnitTests.Services;

using FluentAssertions;
using SheetShow.Core.Constants;
using SheetShow.Core.Entities;
using SheetShow.Core.Services;
using Xunit;

public sealed class SyncServiceTests
{
    private readonly SyncService sut = new(new ConflictDetectionService());

    private static SyncOperation MakeOp(string operationId, Guid entityId, int clientVersion = 1) =>
        new(operationId, "score", entityId, "update", clientVersion, null);

    private static SyncLog MakeLog(Guid entityId) =>
        new()
        {
            Id = Guid.NewGuid(),
            EntityId = entityId,
            EntityType = "score",
            Operation = "update",
            UserId = "user-1",
            DeviceId = "device-1",
            AppliedAt = DateTimeOffset.UtcNow,
        };

    [Fact]
    public void ProcessPush_EmptyOperations_ReturnsEmptyResults()
    {
        var result = this.sut.ProcessPush([], []);

        result.Results.Should().BeEmpty();
    }

    [Fact]
    public void ProcessPush_NewEntity_NoExistingLog_AcceptsOperation()
    {
        var entityId = Guid.NewGuid();
        var ops = new[] { MakeOp("op-1", entityId) };

        var result = this.sut.ProcessPush(ops, []);

        result.Results.Should().HaveCount(1);
        result.Results[0].Status.Should().Be("accepted");
        result.Results[0].OperationId.Should().Be("op-1");
    }

    [Fact]
    public void ProcessPush_ExistingEntity_ClientVersionAboveZero_AcceptsOperation()
    {
        var entityId = Guid.NewGuid();
        var ops = new[] { MakeOp("op-2", entityId, clientVersion: 1) };
        var logs = new[] { MakeLog(entityId) };

        var result = this.sut.ProcessPush(ops, logs);

        result.Results[0].Status.Should().Be("accepted");
    }

    [Fact]
    public void ProcessPush_ExistingEntity_ClientVersionZero_ReturnsConflict()
    {
        var entityId = Guid.NewGuid();
        var ops = new[] { MakeOp("op-3", entityId, clientVersion: 0) };
        var logs = new[] { MakeLog(entityId) };

        var result = this.sut.ProcessPush(ops, logs);

        result.Results[0].Status.Should().Be("conflict");
        result.Results[0].ConflictType.Should().Be("version_mismatch");
    }

    [Fact]
    public void ProcessPush_MultipleOperations_AllAccepted_WhenNoExistingLogs()
    {
        var ops = Enumerable.Range(1, 5)
            .Select(i => MakeOp($"op-{i}", Guid.NewGuid()))
            .ToArray();

        var result = this.sut.ProcessPush(ops, []);

        result.Results.Should().HaveCount(5);
        result.Results.Should().OnlyContain(r => r.Status == "accepted");
    }

    [Fact]
    public void ProcessPush_LogForDifferentEntity_DoesNotTriggerConflict()
    {
        var entityId = Guid.NewGuid();
        var differentEntityId = Guid.NewGuid();

        var ops = new[] { MakeOp("op-6", entityId, clientVersion: 0) };
        var logs = new[]
        {
            new SyncLog
            {
                Id = Guid.NewGuid(),
                EntityId = differentEntityId,
                EntityType = "score",
                Operation = "update",
                UserId = "user-1",
                DeviceId = "device-1",
                AppliedAt = DateTimeOffset.UtcNow,
            },
        };

        var result = this.sut.ProcessPush(ops, logs);

        result.Results[0].Status.Should().Be("accepted");
    }

    [Fact]
    public void ProcessPush_MoreThanMaxBatchSize_OnlyProcessesMaxBatchSize()
    {
        var ops = Enumerable.Range(1, SyncConstants.MaxBatchSize + 10)
            .Select(i => MakeOp($"op-{i}", Guid.NewGuid()))
            .ToArray();

        var result = this.sut.ProcessPush(ops, []);

        result.Results.Should().HaveCount(SyncConstants.MaxBatchSize);
    }

    [Fact]
    public void ProcessPush_MixedConflictsAndAccepted_ReturnsCorrectResults()
    {
        var newEntityId = Guid.NewGuid();
        var conflictEntityId = Guid.NewGuid();

        var ops = new[]
        {
            MakeOp("op-new", newEntityId, clientVersion: 1),
            MakeOp("op-conflict", conflictEntityId, clientVersion: 0),
        };

        var logs = new[] { MakeLog(conflictEntityId) };

        var result = this.sut.ProcessPush(ops, logs);

        result.Results.Should().HaveCount(2);
        result.Results.Single(r => r.OperationId == "op-new").Status.Should().Be("accepted");
        result.Results.Single(r => r.OperationId == "op-conflict").Status.Should().Be("conflict");
    }
}
