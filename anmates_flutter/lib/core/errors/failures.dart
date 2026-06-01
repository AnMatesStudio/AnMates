// Typed failure classes for clean error handling across feature boundaries
sealed class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkFailure extends Failure {
  final int? statusCode;
  const NetworkFailure({String message = 'Network error', this.statusCode})
    : super(message);
}

class AuthFailure extends Failure {
  final String? code;
  const AuthFailure({String message = 'Authentication failed', this.code})
    : super(message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}

class DataParsingFailure extends Failure {
  const DataParsingFailure(super.message);
}
