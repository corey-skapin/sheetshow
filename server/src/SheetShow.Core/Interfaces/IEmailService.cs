namespace SheetShow.Core.Interfaces;

/// <summary>Abstraction over email delivery.</summary>
public interface IEmailService
{
    /// <summary>Send a password reset email to the specified address.</summary>
    Task SendPasswordResetAsync(string toEmail, string resetLink, CancellationToken cancellationToken = default);
}
