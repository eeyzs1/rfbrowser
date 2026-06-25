part of '../canvas_page.dart';

/// Alignment guide computation and snap-to-edge logic for the canvas.
///
/// Extracted from [_CanvasInputHitTestMixin] to keep hit-testing and
/// alignment concerns in separate files. All methods override abstract
/// declarations on [_CanvasViewStateBase].
mixin _CanvasAlignmentGuidesMixin on _CanvasViewStateBase {
  @override
  List<AlignmentGuide> _computeAlignmentGuides(
    CanvasCard draggedCard,
    List<CanvasCard> allCards,
  ) {
    if (_altKeyPressed) return [];
    final guides = <AlignmentGuide>[];
    final threshold = _CanvasViewStateBase._alignmentThreshold;
    final vr = Rect.fromLTWH(
      _cameraX - _viewW / 2 / _scale,
      _cameraY - _viewH / 2 / _scale,
      _viewW / _scale,
      _viewH / _scale,
    );

    for (final other in allCards) {
      if (other.id == draggedCard.id) continue;
      if (!vr.overlaps(other.rect.inflate(50))) continue;

      final dCenterX = (draggedCard.center.dx - other.center.dx).abs();
      if (dCenterX < threshold) {
        final x = other.center.dx;
        guides.add(
          AlignmentGuide(
            start: Offset(x, vr.top),
            end: Offset(x, vr.bottom),
            type: AlignmentGuideType.centerVertical,
          ),
        );
      }

      final dCenterY = (draggedCard.center.dy - other.center.dy).abs();
      if (dCenterY < threshold) {
        final y = other.center.dy;
        guides.add(
          AlignmentGuide(
            start: Offset(vr.left, y),
            end: Offset(vr.right, y),
            type: AlignmentGuideType.centerHorizontal,
          ),
        );
      }

      final dLeft = (draggedCard.x - other.x).abs();
      if (dLeft < threshold) {
        final x = other.x;
        guides.add(
          AlignmentGuide(
            start: Offset(x, vr.top),
            end: Offset(x, vr.bottom),
            type: AlignmentGuideType.leftEdge,
          ),
        );
      }

      final dRight =
          ((draggedCard.x + draggedCard.width) - (other.x + other.width)).abs();
      if (dRight < threshold) {
        final x = other.x + other.width;
        guides.add(
          AlignmentGuide(
            start: Offset(x, vr.top),
            end: Offset(x, vr.bottom),
            type: AlignmentGuideType.rightEdge,
          ),
        );
      }

      final dTop = (draggedCard.y - other.y).abs();
      if (dTop < threshold) {
        final y = other.y;
        guides.add(
          AlignmentGuide(
            start: Offset(vr.left, y),
            end: Offset(vr.right, y),
            type: AlignmentGuideType.topEdge,
          ),
        );
      }

      final dBottom =
          ((draggedCard.y + draggedCard.height) - (other.y + other.height))
              .abs();
      if (dBottom < threshold) {
        final y = other.y + other.height;
        guides.add(
          AlignmentGuide(
            start: Offset(vr.left, y),
            end: Offset(vr.right, y),
            type: AlignmentGuideType.bottomEdge,
          ),
        );
      }
    }
    return guides;
  }

  @override
  double? _getSnapOffset(CanvasCard draggedCard, List<CanvasCard> allCards) {
    if (_altKeyPressed) return null;
    final threshold = _CanvasViewStateBase._alignmentThreshold;
    for (final other in allCards) {
      if (other.id == draggedCard.id) continue;
      final dCenterX = (draggedCard.center.dx - other.center.dx).abs();
      if (dCenterX < threshold) {
        return other.center.dx - draggedCard.width / 2 - draggedCard.x;
      }
      final dLeft = (draggedCard.x - other.x).abs();
      if (dLeft < threshold) return other.x - draggedCard.x;
      final dRight =
          ((draggedCard.x + draggedCard.width) - (other.x + other.width)).abs();
      if (dRight < threshold) {
        return (other.x + other.width - draggedCard.width) - draggedCard.x;
      }
    }
    return null;
  }

  @override
  double? _getSnapOffsetY(CanvasCard draggedCard, List<CanvasCard> allCards) {
    if (_altKeyPressed) return null;
    final threshold = _CanvasViewStateBase._alignmentThreshold;
    for (final other in allCards) {
      if (other.id == draggedCard.id) continue;
      final dCenterY = (draggedCard.center.dy - other.center.dy).abs();
      if (dCenterY < threshold) {
        return other.center.dy - draggedCard.height / 2 - draggedCard.y;
      }
      final dTop = (draggedCard.y - other.y).abs();
      if (dTop < threshold) return other.y - draggedCard.y;
      final dBottom =
          ((draggedCard.y + draggedCard.height) - (other.y + other.height))
              .abs();
      if (dBottom < threshold) {
        return (other.y + other.height - draggedCard.height) - draggedCard.y;
      }
    }
    return null;
  }
}
