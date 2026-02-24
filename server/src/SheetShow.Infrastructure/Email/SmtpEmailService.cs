using SheetShow.Core.Interfaces;

namespace SheetShow.Infrastructure.Email;

/// <summary>SMTP email service. Logs to console in development.</summary>
public sealed class SmtpEmailService : IEmailService
{
    private readonly ILogger<SmtpEmailService> _logger;
    private readonly IConfiguration _configuration;

    public SmtpEmailService(ILogger<SmtpEmailService> logger, IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;
    }

    /// <inheritdoc/>
    public Task SendPasswordResetAsync(string toEmail, string resetLink, CancellationToken cancellationToken = default)
    {
        // In development, log the reset link instead of sending email
        if (_configuration["ASPNETCORE_ENVIRONMENT"] == "Development")
        {
            _logger.LogInformation("Password reset link for {Email}: {ResetLink}", toEmail, resetLink);
            return Task.CompletedTask;
        }

        // Production: send via SMTP (requires ISecretsManager for credentials)
        _logger.LogInformation("Sending password reset email to {Email}", toEmail);
        // TODO: Implement SMTP sending via System.Net.Mail.SmtpClient using secrets
        return Task.CompletedTask;
    }
}
