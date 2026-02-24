// <copyright file="ISecretsManager.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.Core.Interfaces;

/// <summary>Abstraction over secrets management (Azure Key Vault, AWS Secrets Manager, etc.).</summary>
public interface ISecretsManager
{
    /// <summary>Retrieve a secret value by name.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    Task<string> GetSecretAsync(string secretName, CancellationToken cancellationToken = default);
}
