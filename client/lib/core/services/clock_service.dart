import 'package:flutter_riverpod/flutter_riverpod.dart';

// T013: ClockService abstraction for deterministic tests.
// Production code must NOT call DateTime.now() directly — use ClockService.now() instead.

/// Abstract clock service — allows test code to inject a deterministic clock.
abstract class ClockService {
  /// Returns the current date and time.
  DateTime now();
}

/// System clock implementation using the real wall clock.
class SystemClockService implements ClockService {
  const SystemClockService();

  @override
  DateTime now() => DateTime.now();
}

/// Riverpod provider for the clock service.
/// Override this in tests to inject a [FakeClockService].
final clockServiceProvider = Provider<ClockService>(
  (_) => const SystemClockService(),
);
