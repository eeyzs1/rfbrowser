import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/core/result.dart';

void main() {
  group('Result factories', () {
    test('Result.success creates a Success with the given value', () {
      final result = Result<int>.success(42);
      expect(result, isA<Success<int>>());
      expect((result as Success<int>).value, 42);
    });

    test('Result.failure creates a Failure with the given error', () {
      final result = Result<int>.failure('boom');
      expect(result, isA<Failure<int>>());
      expect((result as Failure<int>).error, 'boom');
    });

    test('Success and Failure are const-constructible', () {
      const success = Success<String>('ok');
      const failure = Failure<String>('err');
      expect(success.value, 'ok');
      expect(failure.error, 'err');
    });
  });

  group('when', () {
    test('calls success branch for Success', () {
      final result = Result<int>.success(10);
      final output = result.when(
        success: (v) => 'value=$v',
        failure: (e) => 'error=$e',
      );
      expect(output, 'value=10');
    });

    test('calls failure branch for Failure', () {
      final result = Result<int>.failure('bad');
      final output = result.when(
        success: (v) => 'value=$v',
        failure: (e) => 'error=$e',
      );
      expect(output, 'error=bad');
    });

    test('preserves return type R independent of T', () {
      final result = Result<String>.success('hello');
      final length = result.when<int>(
        success: (v) => v.length,
        failure: (_) => -1,
      );
      expect(length, 5);
    });
  });

  group('getOrElse', () {
    test('returns value for Success', () {
      final result = Result<int>.success(7);
      expect(result.getOrElse(() => 0), 7);
    });

    test('returns orElse for Failure', () {
      final result = Result<int>.failure('err');
      expect(result.getOrElse(() => 999), 999);
    });
  });

  group('getOrThrow', () {
    test('returns value for Success', () {
      final result = Result<String>.success('ok');
      expect(result.getOrThrow(), 'ok');
    });

    test('throws the contained error for Failure', () {
      final exception = FormatException('bad format');
      final result = Result<String>.failure(exception);
      expect(() => result.getOrThrow(), throwsA(same(exception)));
    });

    test('re-throws the exact same object reference', () {
      final error = ArgumentError('arg');
      final result = Result<int>.failure(error);
      expect(() => result.getOrThrow(), throwsA(same(error)));
    });
  });

  group('valueOrNull', () {
    test('returns value for Success', () {
      final result = Result<int>.success(5);
      expect(result.valueOrNull, 5);
    });

    test('returns null for Failure', () {
      final result = Result<int>.failure('err');
      expect(result.valueOrNull, isNull);
    });
  });

  group('errorOrNull', () {
    test('returns null for Success', () {
      final result = Result<int>.success(5);
      expect(result.errorOrNull, isNull);
    });

    test('returns error for Failure', () {
      final error = Exception('fail');
      final result = Result<int>.failure(error);
      expect(result.errorOrNull, same(error));
    });
  });

  group('isSuccess / isFailure', () {
    test('isSuccess true and isFailure false for Success', () {
      final result = Result<int>.success(1);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
    });

    test('isSuccess false and isFailure true for Failure', () {
      final result = Result<int>.failure('e');
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
    });
  });

  group('map', () {
    test('transforms the value for Success', () {
      final result = Result<int>.success(3);
      final mapped = result.map((v) => v * 2);
      expect(mapped, isA<Success<int>>());
      expect(mapped.valueOrNull, 6);
    });

    test('passes through Failure unchanged', () {
      const error = 'original';
      final result = Result<int>.failure(error);
      final mapped = result.map((v) => v * 2);
      expect(mapped, isA<Failure<int>>());
      expect(mapped.errorOrNull, same(error));
    });

    test('supports type widening (int → num)', () {
      final result = Result<int>.success(42);
      final mapped = result.map<num>((v) => v.toDouble());
      expect(mapped.valueOrNull, 42.0);
    });
  });

  group('mapFailure', () {
    test('transforms the error for Failure', () {
      final result = Result<int>.failure('low-level');
      final mapped = result.mapFailure((e) => 'wrapped: $e');
      expect(mapped, isA<Failure<int>>());
      expect(mapped.errorOrNull, 'wrapped: low-level');
    });

    test('passes through Success unchanged (same reference)', () {
      final result = Result<int>.success(10);
      final mapped = result.mapFailure((e) => 'should not run');
      expect(mapped, isA<Success<int>>());
      expect(mapped.valueOrNull, 10);
    });
  });

  group('flatMap', () {
    test('chains Success → Success', () {
      final result = Result<int>.success(5);
      final flat = result.flatMap((v) => Result<String>.success('num=$v'));
      expect(flat, isA<Success<String>>());
      expect(flat.valueOrNull, 'num=5');
    });

    test('chains Success → Failure (mapper returns Failure)', () {
      final result = Result<int>.success(5);
      final flat = result.flatMap((v) => Result<String>.failure('too big'));
      expect(flat, isA<Failure<String>>());
      expect(flat.errorOrNull, 'too big');
    });

    test('short-circuits Failure without calling mapper', () {
      const error = 'short-circuit';
      final result = Result<int>.failure(error);
      var mapperCalled = false;
      final flat = result.flatMap((v) {
        mapperCalled = true;
        return Result<String>.success('never');
      });
      expect(mapperCalled, isFalse);
      expect(flat, isA<Failure<String>>());
      expect(flat.errorOrNull, same(error));
    });
  });

  group('sealed exhaustiveness', () {
    test('switch expression handles both cases without default', () {
      // This test documents that Result is a sealed class, meaning
      // switch expressions are exhaustive with just Success + Failure.
      Result<int> makeResult(bool ok) =>
          ok ? Result.success(1) : Result.failure('no');

      for (final ok in [true, false]) {
        final result = makeResult(ok);
        final label = switch (result) {
          Success<int>() => 'ok',
          Failure<int>() => 'fail',
        };
        expect(label, ok ? 'ok' : 'fail');
      }
    });
  });
}
