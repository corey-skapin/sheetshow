import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/core/services/clock_service.dart';

void main() {
  group('SystemClockService', () {
    test('now() returns a DateTime close to the real wall clock', () {
      const sut = SystemClockService();
      final before = DateTime.now();
      final result = sut.now();
      final after = DateTime.now();

      expect(
        result.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(result.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('two calls return non-decreasing times', () {
      const sut = SystemClockService();
      final first = sut.now();
      final second = sut.now();
      expect(second.isAtSameMomentAs(first) || second.isAfter(first), isTrue);
    });
  });
}
