import 'package:anmates/core/errors/failures.dart';
import 'package:anmates/features/match/domain/entities/match_candidate.dart';
import 'package:anmates/features/match/domain/repositories/match_repository.dart';
import 'package:anmates/features/match/domain/usecases/swipe_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMatchRepository extends Mock implements MatchRepository {}

void main() {
  late MockMatchRepository repo;
  late SwipeUseCase useCase;

  setUpAll(() {
    registerFallbackValue(SwipeAction.like);
  });

  setUp(() {
    repo = MockMatchRepository();
    useCase = SwipeUseCase(repo);
  });

  group('SwipeUseCase', () {
    test('rejects empty userId without calling repo', () async {
      final result = await useCase(userId: '', action: SwipeAction.like);

      expect(result.isSuccess, false);
      expect(result.failure, isA<ValidationFailure>());
      verifyNever(
        () => repo.swipe(
          userId: any(named: 'userId'),
          action: any(named: 'action'),
        ),
      );
    });

    test('forwards a valid swipe to the repository', () async {
      when(
        () => repo.swipe(
          userId: any(named: 'userId'),
          action: any(named: 'action'),
        ),
      ).thenAnswer(
        (_) async => Result.success(const SwipeResult(isMutualMatch: false)),
      );

      final result = await useCase(userId: 'u-123', action: SwipeAction.like);

      expect(result.isSuccess, true);
      verify(
        () => repo.swipe(userId: 'u-123', action: SwipeAction.like),
      ).called(1);
    });

    test('propagates repository failure', () async {
      when(
        () => repo.swipe(
          userId: any(named: 'userId'),
          action: any(named: 'action'),
        ),
      ).thenAnswer(
        (_) async => Result.failure(const NetworkFailure(message: 'offline')),
      );

      final result = await useCase(userId: 'u-123', action: SwipeAction.pass);

      expect(result.isSuccess, false);
      expect(result.failure, isA<NetworkFailure>());
    });
  });
}
