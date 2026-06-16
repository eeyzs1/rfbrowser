import 'dart:collection';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// G12-AC1: lightweight frame-level performance monitor.
///
/// Subscribes to [SchedulerBinding.addTimingsCallback] and keeps a sliding
/// window of recent frame total build+raster durations. Overhead per frame is
/// bounded by the window size (default 120 frames) plus the cost of the
/// callback itself, which is dominated by a single timing call.
///
/// Stats are exposed in microseconds; helpers convert to ms.
class FramePerformanceMonitor {
  /// Sliding-window size. 120 frames ≈ 2 seconds at 60fps.
  final int windowSize;
  final Queue<int> _totalBuildRasterUs = Queue<int>();
  int _slowFrames = 0;
  bool _running = false;
  TimingsCallback? _callback;

  FramePerformanceMonitor({this.windowSize = 120});

  /// Start collecting timings. Idempotent.
  void start() {
    if (_running) return;
    _running = true;
    _callback = _onFrame;
    SchedulerBinding.instance.addTimingsCallback(_callback!);
  }

  /// Stop collecting and detach the callback.
  void stop() {
    if (!_running) return;
    if (_callback != null) {
      SchedulerBinding.instance.removeTimingsCallback(_callback!);
    }
    _callback = null;
    _running = false;
  }

  bool get isRunning => _running;

  void _onFrame(List<FrameTiming> timings) {
    for (final t in timings) {
      // totalSpan = build + raster + ... ; the canonical "frame cost"
      recordFrameTotalUs(t.totalSpan.inMicroseconds);
    }
  }

  /// Records a single frame's total cost in microseconds. Public for test
  /// injection; in production, frames flow in via [_onFrame] from the
  /// SchedulerBinding callback.
  void recordFrameTotalUs(int microseconds) {
    _totalBuildRasterUs.addLast(microseconds);
    if (_totalBuildRasterUs.length > windowSize) {
      _totalBuildRasterUs.removeFirst();
    }
    if (microseconds > 16667) {
      _slowFrames++;
    }
  }

  /// Most recent total frame cost in microseconds, or null if no data.
  int? get lastFrameUs =>
      _totalBuildRasterUs.isEmpty ? null : _totalBuildRasterUs.last;

  /// Number of frames currently in the sliding window.
  int get frameCount => _totalBuildRasterUs.length;

  /// Cumulative count of frames > 16.667ms since [start] was called.
  int get slowFrameCount => _slowFrames;

  /// Average frame total in microseconds, or null if empty.
  double? get averageFrameUs {
    if (_totalBuildRasterUs.isEmpty) return null;
    final sum = _totalBuildRasterUs.fold<int>(0, (a, b) => a + b);
    return sum / _totalBuildRasterUs.length;
  }

  /// p50 / p95 / p99 frame totals in microseconds, or null if not enough data.
  FramePercentiles? get percentiles {
    if (_totalBuildRasterUs.length < 2) return null;
    final sorted = List<int>.from(_totalBuildRasterUs)..sort();
    int at(double q) =>
        sorted[(sorted.length * q).floor().clamp(0, sorted.length - 1)];
    return FramePercentiles(p50: at(0.50), p95: at(0.95), p99: at(0.99));
  }

  /// Snapshot of all current stats. Useful for testing / dashboards.
  FramePerformanceSnapshot snapshot() {
    final p = percentiles;
    return FramePerformanceSnapshot(
      frameCount: frameCount,
      lastFrameUs: lastFrameUs,
      averageFrameUs: averageFrameUs,
      p50Us: p?.p50,
      p95Us: p?.p95,
      p99Us: p?.p99,
      slowFrameCount: slowFrameCount,
    );
  }

  /// Reset window state (does not stop collection).
  void reset() {
    _totalBuildRasterUs.clear();
    _slowFrames = 0;
  }
}

class FramePercentiles {
  final int p50;
  final int p95;
  final int p99;
  const FramePercentiles({
    required this.p50,
    required this.p95,
    required this.p99,
  });
}

class FramePerformanceSnapshot {
  final int frameCount;
  final int? lastFrameUs;
  final double? averageFrameUs;
  final int? p50Us;
  final int? p95Us;
  final int? p99Us;
  final int slowFrameCount;

  const FramePerformanceSnapshot({
    required this.frameCount,
    required this.lastFrameUs,
    required this.averageFrameUs,
    required this.p50Us,
    required this.p95Us,
    required this.p99Us,
    required this.slowFrameCount,
  });

  /// Convenience: last frame in ms, or null.
  double? get lastFrameMs => lastFrameUs == null ? null : lastFrameUs! / 1000.0;

  /// Convenience: average in ms.
  double? get averageFrameMs =>
      averageFrameUs == null ? null : averageFrameUs! / 1000.0;
}

final framePerformanceMonitorProvider = Provider<FramePerformanceMonitor>((
  ref,
) {
  final monitor = FramePerformanceMonitor();
  ref.onDispose(monitor.stop);
  return monitor;
});
