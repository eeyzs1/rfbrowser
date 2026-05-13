import 'package:flutter/material.dart';
import '../../../data/models/canvas_model.dart';

class MinimapPainter extends CustomPainter {
  final List<CanvasCard> cards;
  final List<CanvasConnection> connections;
  final double minX, minY, mmScale;
  final double offsetX, offsetY;
  final double cameraX, cameraY, viewW, viewH, scale;
  final Color primaryColor, dividerColor, cardColor, scaffoldBg;

  MinimapPainter({
    required this.cards,
    required this.connections,
    required this.minX,
    required this.minY,
    required this.mmScale,
    required this.offsetX,
    required this.offsetY,
    required this.cameraX,
    required this.cameraY,
    required this.viewW,
    required this.viewH,
    required this.scale,
    required this.primaryColor,
    required this.dividerColor,
    required this.cardColor,
    required this.scaffoldBg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = scaffoldBg.withValues(alpha: 0.3),
    );

    for (final conn in connections) {
      final fromCard = cards.where((c) => c.id == conn.fromCardId).firstOrNull;
      final toCard = cards.where((c) => c.id == conn.toCardId).firstOrNull;
      if (fromCard == null || toCard == null) continue;
      final fx = (fromCard.center.dx - minX) * mmScale + offsetX;
      final fy = (fromCard.center.dy - minY) * mmScale + offsetY;
      final tx = (toCard.center.dx - minX) * mmScale + offsetX;
      final ty = (toCard.center.dy - minY) * mmScale + offsetY;
      canvas.drawLine(
        Offset(fx, fy),
        Offset(tx, ty),
        Paint()
          ..color = dividerColor
          ..strokeWidth = 0.5,
      );
    }

    for (final card in cards) {
      final x = (card.x - minX) * mmScale + offsetX;
      final y = (card.y - minY) * mmScale + offsetY;
      final w = card.width * mmScale;
      final h = card.height * mmScale;
      canvas.drawRect(
        Rect.fromLTWH(x, y, w, h),
        Paint()..color = cardColor.withValues(alpha: 0.4),
      );
      canvas.drawRect(
        Rect.fromLTWH(x, y, w, h),
        Paint()
          ..color = cardColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }

    final vpLeft = (cameraX - viewW / 2 / scale - minX) * mmScale + offsetX;
    final vpTop = (cameraY - viewH / 2 / scale - minY) * mmScale + offsetY;
    final vpW = (viewW / scale) * mmScale;
    final vpH = (viewH / scale) * mmScale;

    final vpRect = Rect.fromLTWH(vpLeft, vpTop, vpW, vpH);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final outsidePath = Path()..addRect(fullRect);
    final vpPath = Path()..addRect(vpRect);
    final dimPath = Path.combine(PathOperation.difference, outsidePath, vpPath);
    canvas.drawPath(
      dimPath,
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );

    canvas.drawRect(
      vpRect,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      vpRect,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant MinimapPainter old) {
    return !identical(cards, old.cards) ||
        !identical(connections, old.connections) ||
        cameraX != old.cameraX ||
        cameraY != old.cameraY ||
        scale != old.scale ||
        viewW != old.viewW ||
        viewH != old.viewH ||
        offsetX != old.offsetX ||
        offsetY != old.offsetY;
  }
}
