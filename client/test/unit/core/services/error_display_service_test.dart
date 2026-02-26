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

  group('FolderDepthException', () {
    test('has folder_depth_exceeded code', () {
      const e = FolderDepthException();
      expect(e.code, 'folder_depth_exceeded');
      expect(e.message, isNotEmpty);
    });
  });

  group('DuplicateFolderNameException', () {
    test('has duplicate_folder_name code', () {
      final e = DuplicateFolderNameException('Jazz');
      expect(e.code, 'duplicate_folder_name');
      expect(e.message, contains('Jazz'));
    });
  });

  group('ErrorDisplayService.getDisplayMessage', () {
    late ErrorDisplayService sut;

    setUp(() => sut = ErrorDisplayService());

    test('returns AppException message directly', () {
      const e = AppException('custom message', code: 'x');
      expect(sut.getDisplayMessage(e), 'custom message');
    });

    test('maps storage error to storage message', () {
      final e = Exception('storage full');
      expect(sut.getDisplayMessage(e), contains('storage'));
    });

    test('maps disk error to storage message', () {
      final e = Exception('disk quota exceeded');
      expect(sut.getDisplayMessage(e), contains('storage'));
    });

    test('maps permission error to permission message', () {
      final e = Exception('permission denied');
      expect(sut.getDisplayMessage(e), contains('Permission denied'));
    });

    test('maps access denied to permission message', () {
      final e = Exception('access denied');
      expect(sut.getDisplayMessage(e), contains('Permission denied'));
    });

    test('returns generic message for unknown error', () {
      final e = Exception('something really unexpected');
      expect(sut.getDisplayMessage(e), contains('Something went wrong'));
    });
  });
}
