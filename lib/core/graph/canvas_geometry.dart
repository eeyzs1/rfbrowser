import 'dart:ui';

/// Pure geometry utilities used by the canvas view for hit-testing and
/// connection path rendering.
///
/// Extracted from `_CanvasInputHandlersMixin` to:
/// 1. Make the math testable in isolation (no widget/ref dependencies).
/// 2. Reduce the size of the `_CanvasViewState` God object.
/// 3. Allow reuse by other canvas-related widgets (e.g. minimap, export).
///
/// All methods are static and pure — they depend only on their arguments.
class CanvasGeometry {
  const CanvasGeometry._();

  /// Evaluates a cubic Bézier curve at parameter [t] ∈ [0, 1].
  ///
  /// Used to render smooth connection paths between canvas cards.
  static Offset cubicBezierPoint(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    double t,
  ) {
    final u = 1 - t;
    return Offset(
      u * u * u * p0.dx +
          3 * u * u * t * p1.dx +
          3 * u * t * t * p2.dx +
          t * t * t * p3.dx,
      u * u * u * p0.dy +
          3 * u * u * t * p1.dy +
          3 * u * t * t * p2.dy +
          t * t * t * p3.dy,
    );
  }

  /// Projects point [p] onto the segment [a]→[b], clamped to the segment.
  static Offset projectPointOnSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return a;
    var t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    return Offset(a.dx + t * dx, a.dy + t * dy);
  }

  /// Returns the perpendicular distance from [p] to segment [a]→[b].
  static double pointToSegmentDist(Offset p, Offset a, Offset b) {
    final proj = projectPointOnSegment(p, a, b);
    return (p - proj).distance;
  }

  /// Returns the distance from [p] to the closest point on the polyline
  /// [points] (consecutive pairs form segments).
  static double pointToPolylineDist(Offset p, List<Offset> points) {
    if (points.length < 2) {
      return points.isEmpty
          ? double.infinity
          : (p - points.first).distance;
    }
    var minDist = double.infinity;
    for (int i = 0; i < points.length - 1; i++) {
      final d = pointToSegmentDist(p, points[i], points[i + 1]);
      if (d < minDist) minDist = d;
    }
    return minDist;
  }
}
