import 'package:sheetshow/features/library/models/score_model.dart';

// Navigation arguments for the reader route.

/// Carries navigation context when opening a PDF in [ReaderScreen].
///
/// [score] is the eagerly-loaded score (may be null if only [scoreId] is known).
/// [scores] is the ordered list of scores in the current view, used for
/// previous/next navigation.
/// [currentIndex] is the index of the open score within [scores].
class ReaderArgs {
  const ReaderArgs({
    this.score,
    this.scores = const [],
    this.currentIndex = 0,
  });

  final ScoreModel? score;
  final List<ScoreModel> scores;
  final int currentIndex;
}
