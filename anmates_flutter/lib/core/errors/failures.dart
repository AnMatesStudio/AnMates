// Typed failure classes for clean error handling across feature boundaries
abstract sealed class Failure {
  final String message;
  const Failure(this.message);
}

class NetworkFailure extends Failure {
  final int? statusCode;
  NetworkFailure({String message = 'Network error', this.statusCode})
      : super(message);
}

class AuthFailure extends Failure {
  final String? code;
  AuthFailure({String message = 'Authentication failed', this.code})
      : super(message);
}

class ValidationFailure extends Failure {
  ValidationFailure(String message) : super(message);
}

class CacheFailure extends Failure {
  CacheFailure(String message) : super(message);
}

class ServerFailure extends Failure {
  ServerFailure(String message) : super(message);
}

class UnknownFailure extends Failure {
  UnknownFailure(String message) : super(message);
}

class DataParsingFailure extends Failure {
  DataParsingFailure(String message) : super(message);
}
