import 'package:anmates/core/errors/failures.dart';
import 'package:anmates/features/match/domain/entities/match_candidate.dart';
import 'package:anmates/features/match/domain/repositories/match_repository.dart';
import 'package:anmates/features/match/domain/usecases/load_candidates_usecase.dart';
import 'package:anmates/features/match/domain/usecases/swipe_usecase.dart';
import 'package:anmates/features/match/presentation/bloc/match_cubit.dart';
import 'package:anmates/features/match/presentation/bloc/match_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMatchRepository extends Mock implements MatchRepository {}

const _candidateA = MatchCandidate(
  userId: 'u-A',
  name: 'Khanh',
  overlapCount: 3,
  overlapFoods: ['🍜', '🍻'],
  score: 0.92,
);

const _candidateB = MatchCandidate(
  userId: 'u-B',
  name: 'Linh',
  overlapCount: 1,
  overlapFoods: ['☕'],
  score: 0.71,
);

void main() {
  setUpAll(() {
    registerFallbackValue(SwipeAction.like);
  });

  late MockMatchRepository repo;
  late MatchCubit cubit;

  setUp(() {
    repo = MockMatchRepository();
    cubit = MatchCubit(
      loadCandidates: LoadCandidatesUseCase(repo),
      swipe: SwipeUseCase(repo),
    );
  });

  tearDown(() => cubit.close());

  Future<void> drain() async => Future<void>.delayed(Duration.zero);

  group('MatchCubit.loadCandidates', () {
    test('emits Loading then Loaded on success', () async {
      when(() => repo.getCandidates()).thenAnswer(
        (_) async => Result.success(const [_candidateA, _candidateB]),
      );

      final emitted = <MatchState>[];
      final sub = cubit.stream.listen(emitted.add);

      await cubit.loadCandidates();
      await drain();
      await sub.cancel();

      expect(emitted, hasLength(2));
      expect(emitted[0], isA<MatchLoading>());
      expect(emitted[1], isA<MatchLoaded>());
      final loaded = emitted[1] as MatchLoaded;
      expect(loaded.candidates, hasLength(2));
      expect(loaded.currentIndex, 0);
      expect(loaded.topCard, _candidateA);
    });

    test('emits Loading then Error on failure', () async {
      when(
        () => repo.getCandidates(),
      ).thenAnswer((_) async => Result.failure(const ServerFailure('boom')));

      final emitted = <MatchState>[];
      final sub = cubit.stream.listen(emitted.add);

      await cubit.loadCandidates();
      await drain();
      await sub.cancel();

      expect(emitted.last, isA<MatchError>());
      expect((emitted.last as MatchError).message, 'boom');
    });
  });

  group('MatchCubit.swipeTopCard', () {
    test('advances deck optimistically and surfaces mutual match', () async {
      when(() => repo.getCandidates()).thenAnswer(
        (_) async => Result.success(const [_candidateA, _candidateB]),
      );
      await cubit.loadCandidates();

      when(
        () => repo.swipe(
          userId: any(named: 'userId'),
          action: any(named: 'action'),
        ),
      ).thenAnswer(
        (_) async => Result.success(
          const SwipeResult(isMutualMatch: true, matchId: 'm-1'),
        ),
      );

      final emitted = <MatchState>[];
      final sub = cubit.stream.listen(emitted.add);

      await cubit.swipeTopCard(SwipeAction.like);
      await drain();
      await sub.cancel();

      // 1) Optimistic advance (currentIndex 0 -> 1)
      // 2) Mutual-match overlay (mutualMatchUserId set)
      expect(emitted, hasLength(2));
      expect((emitted[0] as MatchLoaded).currentIndex, 1);
      expect((emitted[1] as MatchLoaded).mutualMatchUserId, 'u-A');
    });

    test('does nothing when state is not MatchLoaded', () async {
      // State is still MatchInitial — swipe should be a no-op.
      final emitted = <MatchState>[];
      final sub = cubit.stream.listen(emitted.add);

      await cubit.swipeTopCard(SwipeAction.like);
      await drain();
      await sub.cancel();

      expect(emitted, isEmpty);
      verifyNever(
        () => repo.swipe(
          userId: any(named: 'userId'),
          action: any(named: 'action'),
        ),
      );
    });

    test('swallows backend failure silently (UI already advanced)', () async {
      when(
        () => repo.getCandidates(),
      ).thenAnswer((_) async => Result.success(const [_candidateA]));
      await cubit.loadCandidates();

      when(
        () => repo.swipe(
          userId: any(named: 'userId'),
          action: any(named: 'action'),
        ),
      ).thenAnswer(
        (_) async => Result.failure(const NetworkFailure(message: 'offline')),
      );

      final emitted = <MatchState>[];
      final sub = cubit.stream.listen(emitted.add);

      await cubit.swipeTopCard(SwipeAction.pass);
      await drain();
      await sub.cancel();

      // Only the optimistic advance — no rollback, no error emit.
      expect(emitted, hasLength(1));
      expect((emitted[0] as MatchLoaded).currentIndex, 1);
    });
  });

  group('MatchCubit.clearMutualMatch', () {
    test('clears the mutualMatchUserId on Loaded state', () async {
      when(
        () => repo.getCandidates(),
      ).thenAnswer((_) async => Result.success(const [_candidateA]));
      await cubit.loadCandidates();
      when(
        () => repo.swipe(
          userId: any(named: 'userId'),
          action: any(named: 'action'),
        ),
      ).thenAnswer(
        (_) async => Result.success(
          const SwipeResult(isMutualMatch: true, matchId: 'm-1'),
        ),
      );
      await cubit.swipeTopCard(SwipeAction.like);

      // Now mutualMatchUserId is set. Clear it.
      final emitted = <MatchState>[];
      final sub = cubit.stream.listen(emitted.add);

      cubit.clearMutualMatch();
      await drain();
      await sub.cancel();

      expect(emitted, hasLength(1));
      expect((emitted[0] as MatchLoaded).mutualMatchUserId, isNull);
    });
  });

  group('MatchLoaded helpers', () {
    test('topCard returns null when deck is empty', () {
      const state = MatchLoaded(candidates: [], currentIndex: 0);
      expect(state.isDeckEmpty, true);
      expect(state.topCard, isNull);
    });
  });
}
