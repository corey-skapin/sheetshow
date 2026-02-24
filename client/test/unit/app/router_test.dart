import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sheetshow/main.dart';

void main() {
  group('goRouterProvider', () {
    setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

    test('creates a GoRouter instance within a ProviderScope', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);

      expect(router, isA<GoRouter>());
    });

    test('returns the same instance on repeated reads', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router1 = container.read(goRouterProvider);
      final router2 = container.read(goRouterProvider);

      expect(identical(router1, router2), isTrue);
    });
  });
}
