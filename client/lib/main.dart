import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sheetshow/core/theme/app_theme.dart';
import 'package:sheetshow/features/library/ui/library_screen.dart';
import 'package:sheetshow/features/reader/models/reader_args.dart';
import 'package:sheetshow/features/reader/ui/reader_screen.dart';
import 'package:sheetshow/features/setlists/ui/performance_mode_screen.dart';
import 'package:sheetshow/features/setlists/ui/set_list_builder.dart';
import 'package:sheetshow/features/setlists/ui/set_lists_screen.dart';

/// Provides the app's [GoRouter] instance within the current [ProviderScope].
///
/// Creating the router here (instead of at module level) ensures that any
/// [GoRouter.redirect] callback can safely read Riverpod providers via [ref].
final goRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/library',
    routes: [
      GoRoute(
        path: '/library',
        name: 'library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/reader/:scoreId',
        name: 'reader',
        builder: (context, state) {
          final args = state.extra as ReaderArgs?;
          final scoreId = state.pathParameters['scoreId']!;
          return ReaderScreen(
            scoreId: scoreId,
            score: args?.score,
            scores: args?.scores ?? const [],
            currentIndex: args?.currentIndex ?? 0,
          );
        },
      ),
      GoRoute(
        path: '/setlists',
        name: 'setlists',
        builder: (context, state) => const SetListsScreen(),
      ),
      GoRoute(
        path: '/setlists/:id/builder',
        name: 'setlist-builder',
        builder: (context, state) {
          final setListId = state.pathParameters['id']!;
          return SetListBuilderScreen(setListId: setListId);
        },
      ),
      GoRoute(
        path: '/setlists/:id/performance',
        name: 'setlist-performance',
        builder: (context, state) {
          final setListId = state.pathParameters['id']!;
          return PerformanceModeScreen(setListId: setListId);
        },
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

void main() {
  // Workaround for Flutter Windows keyboard state assertion bug:
  // https://github.com/flutter/flutter/issues/107579
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(
        const ProviderScope(
          child: SheetShowApp(),
        ),
      );
    },
    (error, stack) {
      if (error.toString().contains('KeyDownEvent is dispatched')) return;
      FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack));
    },
  );
}

class SheetShowApp extends ConsumerWidget {
  const SheetShowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'SheetShow',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
