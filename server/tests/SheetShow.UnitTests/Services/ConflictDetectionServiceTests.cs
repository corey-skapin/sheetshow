// <copyright file="ConflictDetectionServiceTests.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.UnitTests.Services;

using FluentAssertions;
using SheetShow.Core.Entities;
using SheetShow.Core.Services;
using Xunit;

public sealed class ConflictDetectionServiceTests
{
    private readonly ConflictDetectionService sut = new();

    private static SyncOperation MakeOperation(string operationId, Guid entityId, int clientVersion = 1, string? payload = null) =>
        new(operationId, "score", entityId, "update", clientVersion, payload);

    private static SyncLog MakeLog(Guid entityId, string? payloadJson = null) =>
        new()
        {
            Id = Guid.NewGuid(),
            EntityId = entityId,
            EntityType = "score",
            Operation = "update",
            PayloadJson = payloadJson,
            UserId = "user-1",
            DeviceId = "device-1",
            AppliedAt = DateTimeOffset.UtcNow,
        };

    [Fact]
    public void Evaluate_NoExistingLog_ReturnsAccepted()
    {
        var op = MakeOperation("op-1", Guid.NewGuid());

        var result = this.sut.Evaluate(op, existingLog: null);

        result.OperationId.Should().Be("op-1");
        result.Status.Should().Be("accepted");
        result.ConflictType.Should().BeNull();
    }

    [Fact]
    public void Evaluate_ExistingLog_ClientVersionZero_ReturnsConflict()
    {
        var entityId = Guid.NewGuid();
        var op = MakeOperation("op-2", entityId, clientVersion: 0, payload: null);
        var existingLog = MakeLog(entityId, payloadJson: "{\"title\":\"server version\"}");

        var result = this.sut.Evaluate(op, existingLog);

        result.OperationId.Should().Be("op-2");
        result.Status.Should().Be("conflict");
        result.ConflictType.Should().Be("version_mismatch");
        result.ServerPayload.Should().Be("{\"title\":\"server version\"}");
    }

    [Fact]
    public void Evaluate_ExistingLog_ClientVersionAboveZero_ReturnsAccepted()
    {
        var entityId = Guid.NewGuid();
        var op = MakeOperation("op-3", entityId, clientVersion: 2);
        var existingLog = MakeLog(entityId);

        var result = this.sut.Evaluate(op, existingLog);

        result.OperationId.Should().Be("op-3");
        result.Status.Should().Be("accepted");
        result.ConflictType.Should().BeNull();
    }

    [Fact]
    public void Evaluate_ExistingLog_ClientVersion1_ReturnsAccepted()
    {
        var entityId = Guid.NewGuid();
        var op = MakeOperation("op-4", entityId, clientVersion: 1);
        var existingLog = MakeLog(entityId);

        var result = this.sut.Evaluate(op, existingLog);

        result.Status.Should().Be("accepted");
    }

    [Fact]
    public void Evaluate_ExistingLogWithNullPayload_ClientVersionZero_ConflictServerPayloadIsNull()
    {
        var entityId = Guid.NewGuid();
        var op = MakeOperation("op-5", entityId, clientVersion: 0);
        var existingLog = MakeLog(entityId, payloadJson: null);

        var result = this.sut.Evaluate(op, existingLog);

        result.Status.Should().Be("conflict");
        result.ServerPayload.Should().BeNull();
    }
}
