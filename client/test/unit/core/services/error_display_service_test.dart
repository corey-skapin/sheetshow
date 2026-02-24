import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/core/services/error_display_service.dart';

void main() {
  group('AppException', () {
    test('message and code are stored', () {
      const e = AppException('oops', code: 'err_code');
      expect(e.message, 'oops');
      expect(e.code, 'err_code');
      expect(e.cause, isNull);
    });

    test('toString contains code and message', () {
      const e = AppException('oops', code: 'err_code');
      expect(e.toString(), contains('oops'));
      expect(e.toString(), contains('err_code'));
    });

    test('cause can be attached', () {
      final inner = Exception('inner');
      final e = AppException('outer', code: 'c', cause: inner);
      expect(e.cause, same(inner));
    });
  });

  group('NetworkException', () {
    test('code is network_error', () {
      const e = NetworkException('no connection');
      expect(e.code, 'network_error');
      expect(e.message, 'no connection');
    });
  });

  group('ValidationException', () {
    test('code is validation_error', () {
      const e = ValidationException('bad input');
      expect(e.code, 'validation_error');
      expect(e.message, 'bad input');
    });
  });

  group('QuotaExceededException', () {
    test('has quota_exceeded code', () {
      const e = QuotaExceededException();
      expect(e.code, 'quota_exceeded');
      expect(e.message, isNotEmpty);
    });
  });

  group('LocalStorageFullException', () {
    test('has local_storage_full code', () {
      const e = LocalStorageFullException();
      expect(e.code, 'local_storage_full');
      expect(e.message, isNotEmpty);
    });
  });

  group('InvalidPdfException', () {
    test('has invalid_pdf code', () {
      const e = InvalidPdfException();
      expect(e.code, 'invalid_pdf');
      expect(e.message, isNotEmpty);
    });
  });

  group('AuthException', () {
    test('has auth_error code', () {
      const e = AuthException('not logged in');
      expect(e.code, 'auth_error');
      expect(e.message, 'not logged in');
    });
  });

  group('FolderDepthException', () {
    test('has folder_depth_exceeded code', () {
      const e = FolderDepthException();
      expect(e.code, 'folder_depth_exceeded');
      expect(e.message, isNotEmpty);
    });
  });

  group('ErrorDisplayService.getDisplayMessage', () {
    late ErrorDisplayService sut;

    setUp(() => sut = ErrorDisplayService());

    test('returns AppException message directly', () {
      const e = AppException('custom message', code: 'x');
      expect(sut.getDisplayMessage(e), 'custom message');
    });

    test('maps socket error to connectivity message', () {
      final e = Exception('SocketException: connection refused');
      expect(
        sut.getDisplayMessage(e),
        contains('internet connection'),
      );
    });

    test('maps connection error to connectivity message', () {
      final e = Exception('connection timed out');
      expect(sut.getDisplayMessage(e), contains('internet connection'));
    });

    test('maps timeout to connectivity message', () {
      final e = Exception('request timeout');
      expect(sut.getDisplayMessage(e), contains('internet connection'));
    });

    test('maps 401 to session-expired message', () {
      final e = Exception('error 401 unauthorized');
      expect(sut.getDisplayMessage(e), contains('session has expired'));
    });

    test('maps unauthorized keyword to session-expired message', () {
      final e = Exception('unauthorized access');
      expect(sut.getDisplayMessage(e), contains('session has expired'));
    });

    test('maps 403 to permission message', () {
      final e = Exception('403 forbidden');
      expect(sut.getDisplayMessage(e), contains('permission'));
    });

    test('maps forbidden keyword to permission message', () {
      final e = Exception('forbidden resource');
      expect(sut.getDisplayMessage(e), contains('permission'));
    });

    test('maps 404 to not-found message', () {
      final e = Exception('404 not found');
      expect(sut.getDisplayMessage(e), contains('not found'));
    });

    test('maps not found keyword to not-found message', () {
      final e = Exception('resource not found');
      expect(sut.getDisplayMessage(e), contains('not found'));
    });

    test('maps storage error to storage message', () {
      final e = Exception('storage full');
      expect(sut.getDisplayMessage(e), contains('storage'));
    });

    test('maps disk error to storage message', () {
      final e = Exception('disk quota exceeded');
      expect(sut.getDisplayMessage(e), contains('storage'));
    });

    test('returns generic message for unknown error', () {
      final e = Exception('something really unexpected');
      expect(sut.getDisplayMessage(e), contains('Something went wrong'));
    });

    test('NetworkException message returned directly', () {
      const e = NetworkException('offline');
      expect(sut.getDisplayMessage(e), 'offline');
    });
  });
}
