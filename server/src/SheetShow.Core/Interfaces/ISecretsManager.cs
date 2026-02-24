namespace SheetShow.Core.Interfaces;

/// <summary>Abstraction over secrets management (Azure Key Vault, AWS Secrets Manager, etc.).</summary>
public interface ISecretsManager
{
    /// <summary>Retrieve a secret value by name.</summary>
    Task<string> GetSecretAsync(string secretName, CancellationToken cancellationToken = default);
}
