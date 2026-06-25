import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/core/graph/canvas_geometry.dart';

void main() {
  group('CanvasGeometry', () {
    group('cubicBezierPoint', () {
      test('returns p0 at t=0', () {
        final p = CanvasGeometry.cubicBezierPoint(
          const Offset(0, 0),
          const Offset(100, 0),
          const Offset(100, 100),
          const Offset(100, 100),
          0,
        );
        expect(p, const Offset(0, 0));
      });

      test('returns p3 at t=1', () {
        final p = CanvasGeometry.cubicBezierPoint(
          const Offset(0, 0),
          const Offset(100, 0),
          const Offset(100, 100),
          const Offset(200, 200),
          1,
        );
        expect(p, const Offset(200, 200));
      });

      test('returns midpoint at t=0.5 for symmetric control points', () {
        // Linear Bézier (control points on the line) at t=0.5 = midpoint.
        final p = CanvasGeometry.cubicBezierPoint(
          const Offset(0, 0),
          const Offset(50, 0),
          const Offset(50, 0),
          const Offset(100, 0),
          0.5,
        );
        expect(p.dx, closeTo(50, 1e-9));
        expect(p.dy, closeTo(0, 1e-9));
      });
    });

    group('projectPointOnSegment', () {
      test('projects to start when point is before segment', () {
        final proj = CanvasGeometry.projectPointOnSegment(
          const Offset(-10, 5),
          const Offset(0, 0),
          const Offset(10, 0),
        );
        expect(proj, const Offset(0, 0));
      });

      test('projects to end when point is beyond segment', () {
        final proj = CanvasGeometry.projectPointOnSegment(
          const Offset(20, 5),
          const Offset(0, 0),
          const Offset(10, 0),
        );
        expect(proj, const Offset(10, 0));
      });

      test('projects to closest point on segment', () {
        final proj = CanvasGeometry.projectPointOnSegment(
          const Offset(5, 10),
          const Offset(0, 0),
          const Offset(10, 0),
        );
        expect(proj, const Offset(5, 0));
      });

      test('handles degenerate segment (a == b)', () {
        final proj = CanvasGeometry.projectPointOnSegment(
          const Offset(5, 5),
          const Offset(3, 3),
          const Offset(3, 3),
        );
        expect(proj, const Offset(3, 3));
      });
    });

    group('pointToSegmentDist', () {
      test('returns perpendicular distance', () {
        final dist = CanvasGeometry.pointToSegmentDist(
          const Offset(5, 3),
          const Offset(0, 0),
          const Offset(10, 0),
        );
        expect(dist, closeTo(3, 1e-9));
      });

      test('returns distance to endpoint when projection is outside', () {
        final dist = CanvasGeometry.pointToSegmentDist(
          const Offset(15, 4),
          const Offset(0, 0),
          const Offset(10, 0),
        );
        // Distance from (15,4) to (10,0) = sqrt(25+16) = sqrt(41)
        expect(dist, closeTo(6.4031, 0.001));
      });
    });

    group('pointToPolylineDist', () {
      test('returns infinity for empty polyline', () {
        final dist = CanvasGeometry.pointToPolylineDist(
          const Offset(0, 0),
          const [],
        );
        expect(dist, double.infinity);
      });

      test('returns distance to single point', () {
        final dist = CanvasGeometry.pointToPolylineDist(
          const Offset(3, 4),
          [const Offset(0, 0)],
        );
        expect(dist, closeTo(5, 1e-9));
      });

      test('returns distance to closest segment', () {
        final dist = CanvasGeometry.pointToPolylineDist(
          const Offset(5, 2),
          [const Offset(0, 0), const Offset(10, 0), const Offset(10, 10)],
        );
        // Closest segment is (0,0)-(10,0), perpendicular distance = 2
        expect(dist, closeTo(2, 1e-9));
      });
    });
  });
}
