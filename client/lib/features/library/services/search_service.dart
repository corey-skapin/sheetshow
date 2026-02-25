import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetshow/core/constants/app_constants.dart';
import 'package:sheetshow/core/database/app_database.dart';
import 'package:sheetshow/features/library/models/score_model.dart';
import 'package:sheetshow/features/library/repositories/score_repository.dart';

// T048: SearchService — debounced FTS5 full-text search over score title and tags.

/// Provides real-time FTS5 search over the local score library.
class SearchService {
  SearchService(this._db, this._scoreRepository);

  final AppDatabase _db;
  final ScoreRepository _scoreRepository;

  /// Returns a stream of matching scores for [query].
  /// Debounces input by [kSearchDebounceMs] ms.
  /// Empty query returns all scores.
  Stream<List<ScoreModel>> searchStream(String query) async* {
    await Future<void>.delayed(
      const Duration(milliseconds: kSearchDebounceMs),
    );

    if (query.trim().isEmpty) {
      yield* _scoreRepository.watchAll();
      return;
    }

    // FTS5 match query
    final ids = await _db.searchScoreIds(query.trim());
    if (ids.isEmpty) {
      yield [];
      return;
    }

    // Load matching scores
    final scores = <ScoreModel>[];
    for (final id in ids) {
      final score = await _scoreRepository.getById(id);
      if (score != null) {
        final tags = await _scoreRepository.getEffectiveTags(id);
        scores.add(score.copyWith(effectiveTags: tags));
      }
    }
    yield scores;
  }
}

/// Riverpod provider for [SearchService].
final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService(
    ref.watch(databaseProvider).requireValue,
    ref.watch(scoreRepositoryProvider),
  );
});
