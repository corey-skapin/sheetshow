import 'package:flutter_riverpod/flutter_riverpod.dart';

// T018: ErrorDisplayService — maps technical exceptions to user-readable messages.
// No stack traces or internal error details are ever shown in the UI.

/// Categorised application exception.
class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => 'AppException($code): $message';
}

/// Network connectivity exception.
class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause})
      : super(code: 'network_error');
}

/// HTTP validation error (422 or 400 from server).
class ValidationException extends AppException {
  const ValidationException(super.message) : super(code: 'validation_error');
}

/// Storage quota exceeded (server-side).
class QuotaExceededException extends AppException {
  const QuotaExceededException()
      : super(
          'Cloud storage is full. Free up space to continue syncing.',
          code: 'quota_exceeded',
        );
}

/// Local storage is too full to import the file.
class LocalStorageFullException extends AppException {
  const LocalStorageFullException()
      : super(
          'Not enough storage space to import this file.',
          code: 'local_storage_full',
        );
}

/// Corrupt or unsupported PDF file.
class InvalidPdfException extends AppException {
  const InvalidPdfException()
      : super(
          "This file couldn't be imported — it may be corrupted or password-protected.",
          code: 'invalid_pdf',
        );
}

/// Authentication failure.
class AuthException extends AppException {
  const AuthException(super.message) : super(code: 'auth_error');
}

/// Folder depth limit exceeded.
class FolderDepthException extends AppException {
  const FolderDepthException()
      : super(
          'Folders cannot be nested more than 10 levels deep.',
          code: 'folder_depth_exceeded',
        );
}

/// A root-level folder with that name already exists.
class DuplicateFolderNameException extends AppException {
  DuplicateFolderNameException(String name)
      : super(
          'A root folder named "$name" already exists.',
          code: 'duplicate_folder_name',
        );
}

/// Maps [Exception] subtypes to user-readable error messages.
class ErrorDisplayService {
  /// Returns a human-readable message with a corrective action hint.
  String getDisplayMessage(Object error) {
    if (error is AppException) return error.message;

    final message = error.toString().toLowerCase();

    if (message.contains('socket') ||
        message.contains('connection') ||
        message.contains('network') ||
        message.contains('timeout')) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }

    if (message.contains('401') || message.contains('unauthorized')) {
      return 'Your session has expired. Please log in again.';
    }

    if (message.contains('403') || message.contains('forbidden')) {
      return 'You do not have permission to perform this action.';
    }

    if (message.contains('404') || message.contains('not found')) {
      return 'The requested item was not found. It may have been deleted.';
    }

    if (message.contains('storage') || message.contains('disk')) {
      return 'Not enough storage space. Please free up space and try again.';
    }

    return 'Something went wrong. Please try again.';
  }
}

/// Riverpod provider for [ErrorDisplayService].
final errorDisplayServiceProvider = Provider<ErrorDisplayService>(
  (_) => ErrorDisplayService(),
);
