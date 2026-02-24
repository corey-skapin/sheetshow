import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sheetshow/core/services/api_client.dart';
import 'package:sheetshow/core/theme/app_theme.dart';
import 'package:sheetshow/features/auth/services/token_storage_service.dart';
import 'package:sheetshow/features/auth/ui/forgot_password_screen.dart';
import 'package:sheetshow/features/auth/ui/login_screen.dart';
import 'package:sheetshow/features/auth/ui/register_screen.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/ui/library_screen.dart';
import 'package:sheetshow/features/reader/ui/reader_screen.dart';
import 'package:sheetshow/features/setlists/ui/performance_mode_screen.dart';
import 'package:sheetshow/features/setlists/ui/set_list_builder.dart';
import 'package:sheetshow/features/setlists/ui/set_lists_screen.dart';

// T020: App entry point — Riverpod ProviderScope + GoRouter routing skeleton.

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
        final score = state.extra as ScoreModel?;
        final scoreId = state.pathParameters['scoreId']!;
        return ReaderScreen(scoreId: scoreId, score: score);
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
    GoRoute(
      path: '/auth/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/auth/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/auth/forgot-password',
      name: 'forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
  ],
);

void main() {
  // Workaround for Flutter Windows keyboard state assertion bug:
  // https://github.com/flutter/flutter/issues/107579
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(
        ProviderScope(
          overrides: [
            tokenLoaderProvider.overrideWith(
              (ref) => ref.read(tokenStorageServiceProvider).getAccessToken,
            ),
          ],
          child: const SheetShowApp(),
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
