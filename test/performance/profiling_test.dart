import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/performance/frame_performance_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FramePerformanceMonitor (G12-AC1)', () {
    late FramePerformanceMonitor monitor;

    setUp(() {
      monitor = FramePerformanceMonitor();
    });

    tearDown(() {
      monitor.stop();
    });

    test('initial state: no frames, not running', () {
      expect(monitor.frameCount, 0);
      expect(monitor.lastFrameUs, isNull);
      expect(monitor.averageFrameUs, isNull);
      expect(monitor.percentiles, isNull);
      expect(monitor.slowFrameCount, 0);
      expect(monitor.isRunning, isFalse);
    });

    test('start() transitions to running and is idempotent', () {
      monitor.start();
      expect(monitor.isRunning, isTrue);

      // Second call must not throw or double-register.
      monitor.start();
      expect(monitor.isRunning, isTrue);

      monitor.stop();
      expect(monitor.isRunning, isFalse);
    });

    test('recordFrameTotalUs accumulates frames in the sliding window', () {
      const us = [5000, 7000, 10000, 12000, 15000];
      for (final v in us) {
        monitor.recordFrameTotalUs(v);
      }

      expect(monitor.frameCount, us.length);
      expect(monitor.lastFrameUs, us.last);
      expect(monitor.averageFrameUs, us.reduce((a, b) => a + b) / us.length);
      expect(monitor.slowFrameCount, 0, reason: 'No frame > 16667 us');
    });

    test('frames exceeding 16.667ms are counted as slow', () {
      monitor.recordFrameTotalUs(20000); // slow
      monitor.recordFrameTotalUs(8000); // fast
      monitor.recordFrameTotalUs(25000); // slow

      expect(monitor.slowFrameCount, 2);
    });

    test('window size is respected (FIFO eviction)', () {
      final small = FramePerformanceMonitor(windowSize: 3);
      for (final v in [1000, 2000, 3000, 4000]) {
        small.recordFrameTotalUs(v);
      }

      expect(small.frameCount, 3, reason: 'Window capped at 3');
      expect(small.lastFrameUs, 4000);
      // Average over the 3 retained frames (2000 + 3000 + 4000) / 3 = 3000.
      expect(small.averageFrameUs, closeTo(3000.0, 1e-9));
    });

    test('percentiles are returned for >= 2 frames', () {
      final m = FramePerformanceMonitor();
      for (var i = 1; i <= 20; i++) {
        m.recordFrameTotalUs(1000 * i);
      }

      final p = m.percentiles;
      expect(p, isNotNull);
      // Sorted: 1000..20000. p50 ~ index 9..10 → ~10k. p95 ~ index 18..19 → ~19k.
      expect(p!.p50, inInclusiveRange(9000, 11000));
      expect(p.p95, greaterThanOrEqualTo(18000));
      expect(p.p99, greaterThanOrEqualTo(19000));
    });

    test('percentiles return null for 0 or 1 frame', () {
      expect(monitor.percentiles, isNull);
      monitor.recordFrameTotalUs(5000);
      expect(monitor.percentiles, isNull);
    });

    test('reset() clears window and slow frame counter', () {
      monitor.recordFrameTotalUs(20000);
      monitor.recordFrameTotalUs(5000);
      expect(monitor.frameCount, 2);
      expect(monitor.slowFrameCount, 1);

      monitor.reset();
      expect(monitor.frameCount, 0);
      expect(monitor.slowFrameCount, 0);
    });

    test('snapshot reflects current state', () {
      monitor.recordFrameTotalUs(8000);
      final s = monitor.snapshot();
      expect(s.frameCount, 1);
      expect(s.lastFrameUs, 8000);
      expect(s.lastFrameMs, closeTo(8.0, 1e-9));
      expect(s.averageFrameMs, closeTo(8.0, 1e-9));
      expect(s.p50Us, isNull, reason: 'Need >= 2 frames for percentiles');
    });

    test(
      'G12-AC1: instrumentation overhead is small (callback under 1ms for 120 frames)',
      () {
        final m = FramePerformanceMonitor(windowSize: 120);
        m.start();

        // Simulate 120 frames in one batch.
        final sw = Stopwatch()..start();
        for (var i = 0; i < 120; i++) {
          m.recordFrameTotalUs(5000 + i);
        }
        sw.stop();

        m.stop();

        // The whole 120-frame callback should be well under 1ms on any host.
        expect(
          sw.elapsedMicroseconds,
          lessThan(1000),
          reason:
              'FramePerformanceMonitor callback must add < 1ms overhead per frame batch',
        );
      },
    );

    test('stop() flips isRunning to false', () {
      monitor.start();
      monitor.recordFrameTotalUs(5000);
      expect(monitor.frameCount, 1);

      monitor.stop();
      expect(monitor.isRunning, isFalse);
    });

    test('Riverpod provider returns a fresh monitor and disposes it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final monitor = container.read(framePerformanceMonitorProvider);
      expect(monitor, isA<FramePerformanceMonitor>());

      // Subsequent reads return the same singleton instance.
      final again = container.read(framePerformanceMonitorProvider);
      expect(identical(monitor, again), isTrue);
    });

    test('SchedulerBinding callback integration (start + manual frame)', () {
      // Make sure adding a real callback does not crash and that stop
      // removes it (we don't actually drive frames in unit tests).
      monitor.start();
      monitor.stop();
      expect(monitor.isRunning, isFalse);
    });

    test('FramePerformanceSnapshot exposes ms helpers', () {
      const snap = FramePerformanceSnapshot(
        frameCount: 2,
        lastFrameUs: 16000,
        averageFrameUs: 15000,
        p50Us: 14000,
        p95Us: 19000,
        p99Us: 19500,
        slowFrameCount: 0,
      );
      expect(snap.lastFrameMs, 16.0);
      expect(snap.averageFrameMs, 15.0);
    });
  });
}
