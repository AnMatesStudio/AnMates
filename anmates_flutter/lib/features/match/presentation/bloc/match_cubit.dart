import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/match_candidate.dart';
import '../../domain/usecases/load_candidates_usecase.dart';
import '../../domain/usecases/swipe_usecase.dart';
import 'match_state.dart';

/// MatchCubit orchestrates the swipe deck.
///
/// Why a Cubit (not a Bloc)?
/// - Swipe actions are sequential and not concurrent. No event transformers
///   needed.
/// - State transitions are: Initial → Loading → Loaded → (swipe) → Loaded.
///   Optimistic deck advance keeps the UI snappy: we increment currentIndex
///   immediately and reconcile with the backend response, surfacing
///   mutual-match overlays when they happen.
class MatchCubit extends Cubit<MatchState> {
  final LoadCandidatesUseCase _loadCandidates;
  final SwipeUseCase _swipe;

  MatchCubit({
    required LoadCandidatesUseCase loadCandidates,
    required SwipeUseCase swipe,
  }) : _loadCandidates = loadCandidates,
       _swipe = swipe,
       super(const MatchInitial());

  /// Fetch the first batch of candidates.
  Future<void> loadCandidates() async {
    emit(const MatchLoading());
    final result = await _loadCandidates();
    if (result.isSuccess) {
      emit(MatchLoaded(candidates: result.data!));
    } else {
      emit(MatchError(result.failure!.message));
    }
  }

  /// User swiped on the current top card.
  /// Optimistically advance the deck, then fire-and-await the backend call
  /// to surface mutual-match notifications.
  Future<void> swipeTopCard(SwipeAction action) async {
    final current = state;
    if (current is! MatchLoaded) return;
    final top = current.topCard;
    if (top == null) return;

    // Optimistic advance — UI moves on immediately.
    emit(current.copyWith(currentIndex: current.currentIndex + 1));

    final result = await _swipe(userId: top.userId, action: action);
    if (!result.isSuccess) {
      // Network failure on a swipe is best-effort; we don't roll back the
      // deck (the user already saw it advance) but surface for analytics
      // in future. For now, swallow silently.
      return;
    }
    if (result.data!.isMutualMatch) {
      final after = state;
      if (after is MatchLoaded) {
        emit(after.copyWith(mutualMatchUserId: top.userId));
      }
    }
  }

  /// UI has acknowledged the mutual match celebration overlay.
  void clearMutualMatch() {
    final current = state;
    if (current is MatchLoaded && current.mutualMatchUserId != null) {
      emit(current.copyWith(clearMutualMatch: true));
    }
  }
}
