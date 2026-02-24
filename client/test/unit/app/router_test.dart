// Tests for goRouterProvider defined in main.dart.
// GoRouter must be read inside a ProviderContainer — testWidgets is required
// because GoRouter interacts with the Flutter binding on construction.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sheetshow/main.dart';

void main() {
  group('goRouterProvider', () {
    testWidgets('creates a GoRouter instance within a ProviderScope',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);

      expect(router, isA<GoRouter>());
    });

    testWidgets('returns the same instance on repeated reads',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router1 = container.read(goRouterProvider);
      final router2 = container.read(goRouterProvider);

      expect(identical(router1, router2), isTrue);
    });
  });
}
