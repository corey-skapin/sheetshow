import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sheetshow/core/theme/app_theme.dart';
import 'package:sheetshow/features/library/ui/library_screen.dart';
import 'package:sheetshow/features/reader/models/reader_args.dart';
import 'package:sheetshow/features/reader/ui/reader_screen.dart';
import 'package:sheetshow/features/setlists/ui/performance_mode_screen.dart';
import 'package:sheetshow/features/setlists/ui/set_list_builder.dart';
import 'package:sheetshow/features/setlists/ui/set_lists_screen.dart';

final _router = GoRouter(
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

void main() {
  // Workaround for Flutter Windows keyboard state assertion bug:
  // https://github.com/flutter/flutter/issues/107579
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await windowManager.ensureInitialized();
      await windowManager.setPreventClose(true);
      windowManager.waitUntilReadyToShow(const WindowOptions(), () async {
        await windowManager.show();
        await windowManager.focus();
      });
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

class SheetShowApp extends ConsumerStatefulWidget {
  const SheetShowApp({super.key});

  @override
  ConsumerState<SheetShowApp> createState() => _SheetShowAppState();
}

class _SheetShowAppState extends ConsumerState<SheetShowApp>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  /// Default close handler — allows close when no screen overrides it.
  @override
  void onWindowClose() {
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SheetShow',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
