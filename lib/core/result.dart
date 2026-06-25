/// A type-safe result type for operations that can succeed or fail.
///
/// Prefer [Result] over throwing exceptions for expected failures (file I/O,
/// network calls, validation). Reserve exceptions for programmer errors.
///
/// ```dart
/// Future<Result<String>> readFile(String path) async {
///   try {
///     final content = await File(path).readAsString();
///     return Result.success(content);
///   } catch (e) {
///     return Result.failure(e);
///   }
/// }
///
/// final result = await readFile('config.json');
/// final content = result.getOrElse(() => '{}');
/// ```
sealed class Result<T> {
  const Result();

  /// Creates a successful [Result] containing [value].
  factory Result.success(T value) = Success<T>;

  /// Creates a failed [Result] containing [error].
  factory Result.failure(Object error) = Failure<T>;

  /// Pattern-matches on the result, calling [success] for [Success] values
  /// and [failure] for [Failure] values.
  R when<R>({
    required R Function(T value) success,
    required R Function(Object error) failure,
  }) {
    final self = this;
    return switch (self) {
      Success<T>(:final value) => success(value),
      Failure<T>(:final error) => failure(error),
    };
  }

  /// Returns the contained value if [Success], otherwise [orElse].
  T getOrElse(T Function() orElse) {
    final self = this;
    return switch (self) {
      Success<T>(:final value) => value,
      Failure<T>() => orElse(),
    };
  }

  /// Returns the contained value if [Success], otherwise throws the
  /// contained error.
  T getOrThrow() {
    final self = this;
    return switch (self) {
      Success<T>(:final value) => value,
      Failure<T>(:final error) => throw error,
    };
  }

  /// The contained value if [Success], otherwise `null`.
  T? get valueOrNull {
    final self = this;
    return switch (self) {
      Success<T>(:final value) => value,
      Failure<T>() => null,
    };
  }

  /// The contained error if [Failure], otherwise `null`.
  Object? get errorOrNull {
    final self = this;
    return switch (self) {
      Success<T>() => null,
      Failure<T>(:final error) => error,
    };
  }

  /// `true` if this is a [Success].
  bool get isSuccess => this is Success<T>;

  /// `true` if this is a [Failure].
  bool get isFailure => this is Failure<T>;

  /// Transforms a [Success] value via [mapper]. [Failure] is passed through.
  Result<R> map<R>(R Function(T value) mapper) {
    final self = this;
    return switch (self) {
      Success<T>(:final value) => Result.success(mapper(value)),
      Failure<T>(:final error) => Result.failure(error),
    };
  }

  /// Transforms a [Failure] error via [mapper]. [Success] is passed through.
  Result<T> mapFailure(Object Function(Object error) mapper) {
    final self = this;
    return switch (self) {
      Success<T>() => this,
      Failure<T>(:final error) => Result.failure(mapper(error)),
    };
  }

  /// Flat-maps a [Success] value via [mapper]. [Failure] is passed through.
  Result<R> flatMap<R>(Result<R> Function(T value) mapper) {
    final self = this;
    return switch (self) {
      Success<T>(:final value) => mapper(value),
      Failure<T>(:final error) => Result.failure(error),
    };
  }
}

/// A successful [Result] containing [value].
final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

/// A failed [Result] containing [error].
final class Failure<T> extends Result<T> {
  final Object error;
  const Failure(this.error);
}
