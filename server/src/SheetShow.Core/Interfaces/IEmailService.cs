// <copyright file="IEmailService.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace SheetShow.Core.Interfaces;

/// <summary>Abstraction over email delivery.</summary>
public interface IEmailService
{
    /// <summary>Send a password reset email to the specified address.</summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    Task SendPasswordResetAsync(string toEmail, string resetLink, CancellationToken cancellationToken = default);
}
