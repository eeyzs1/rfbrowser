import 'package:flutter/material.dart';
import '../../data/models/canvas_model.dart';

/// Pure-function service for canvas and card style operations.
///
/// All methods are side-effect free: they take immutable model objects and
/// return new immutable copies with the requested style change applied.
/// [CanvasNotifier] delegates to this service for any style/content mutation
/// so the notifier stays focused on state coordination and persistence.
class CanvasStyleService {
  const CanvasStyleService();

  // ─── Canvas-level style ─────────────────────────────────────────────

  /// Returns a copy of [data] with the default card style replaced.
  /// Pass `null` to clear the default.
  CanvasData withDefaultCardStyle(CanvasData data, CanvasCardStyle? style) {
    return data.copyWith(
      settings: data.settings.copyWith(
        defaultCardStyle: style,
        clearDefaultCardStyle: style == null,
      ),
    );
  }

  /// Returns a copy of [data] with the default connection style replaced.
  /// Pass `null` to clear the default.
  CanvasData withDefaultConnectionStyle(
    CanvasData data,
    CanvasConnectionStyle? style,
  ) {
    return data.copyWith(
      settings: data.settings.copyWith(
        defaultConnectionStyle: style,
        clearDefaultConnectionStyle: style == null,
      ),
    );
  }

  /// Returns a copy of [data] with the background color replaced.
  /// Pass `null` to clear the background.
  CanvasData withBackgroundColor(CanvasData data, int? colorValue) {
    return data.copyWith(
      settings: data.settings.copyWith(
        backgroundColorValue: colorValue,
        clearBackgroundColor: colorValue == null,
      ),
    );
  }

  // ─── Card-level style ───────────────────────────────────────────────

  CanvasCard withFontFamily(CanvasCard card, String family) {
    return card.copyWith(fontFamily: family);
  }

  CanvasCard withTextColor(CanvasCard card, int colorValue) {
    return card.copyWith(textColorValue: colorValue);
  }

  CanvasCard withLatexFormula(CanvasCard card, String? formula) {
    return card.copyWith(latexFormula: formula, clearLatex: formula == null);
  }

  CanvasCard withHtmlContent(CanvasCard card, String? html) {
    return card.copyWith(htmlContent: html, clearHtml: html == null);
  }

  CanvasCard withCustomSvg(CanvasCard card, String? svgData) {
    return card.copyWith(customSvgData: svgData, clearSvg: svgData == null);
  }

  CanvasCard withConnectionPointOffset(
    CanvasCard card,
    double offsetX,
    double offsetY,
  ) {
    return card.copyWith(
      connectionPointOffsetX: offsetX.clamp(0.0, 1.0),
      connectionPointOffsetY: offsetY.clamp(0.0, 1.0),
    );
  }

  // ─── Card content / metadata ────────────────────────────────────────

  CanvasCard withMetadata(CanvasCard card, CanvasCardMetadata metadata) {
    return card.copyWith(metadata: metadata);
  }

  CanvasCard withHyperlink(CanvasCard card, String? url) {
    final meta = card.metadata ?? const CanvasCardMetadata();
    return card.copyWith(
      metadata: meta.copyWith(hyperlink: url, clearHyperlink: url == null),
    );
  }

  CanvasCard withTextAlign(CanvasCard card, {TextAlignH? h, TextAlignV? v}) {
    return card.copyWith(
      textAlignH: h ?? card.textAlignH,
      textAlignV: v ?? card.textAlignV,
    );
  }

  CanvasCard withRichContent(CanvasCard card, List<RichTextSegment> segments) {
    return card.copyWith(richContent: segments);
  }

  CanvasCard withToggledAutoNumber(CanvasCard card) {
    return card.copyWith(autoNumber: !card.autoNumber);
  }

  CanvasCard withFreehandPoints(CanvasCard card, List<Offset> points) {
    return card.copyWith(freehandPoints: points);
  }

  CanvasCard withTableSize(CanvasCard card, int rows, int cols) {
    final cells = List<CanvasTableCell>.generate(rows * cols, (i) {
      if (i < card.tableCells.length) return card.tableCells[i];
      return const CanvasTableCell();
    });
    return card.copyWith(tableRows: rows, tableCols: cols, tableCells: cells);
  }

  /// Returns a copy of [card] with the cell at ([row], [col]) set to [text].
  /// Returns [card] unchanged if the index is out of bounds.
  CanvasCard withTableCell(CanvasCard card, int row, int col, String text) {
    final idx = row * card.tableCols + col;
    if (idx < 0 || idx >= card.tableCells.length) return card;
    final cells = List<CanvasTableCell>.from(card.tableCells);
    cells[idx] = CanvasTableCell(text: text);
    return card.copyWith(tableCells: cells);
  }

  CanvasCard withToggledVerticalText(CanvasCard card) {
    return card.copyWith(verticalText: !card.verticalText);
  }

  // ─── Batch operations ───────────────────────────────────────────────

  /// Returns a copy of [data] where every card whose id is in [cardIds] has
  /// its color set to [colorValue].
  CanvasData withBatchCardColor(
    CanvasData data,
    List<String> cardIds,
    int colorValue,
  ) {
    final cardIdSet = cardIds.toSet();
    final newCards = data.cards.map((c) {
      if (cardIdSet.contains(c.id)) {
        return c.copyWith(colorValue: colorValue);
      }
      return c;
    }).toList();
    return data.copyWith(cards: newCards);
  }

  // ─── Enumeration ────────────────────────────────────────────────────

  /// Returns a copy of [data] where every card with `autoNumber == true` has
  /// its title prefixed with an incrementing counter (`"N. title"`).
  /// Existing numeric prefixes are stripped before re-numbering.
  CanvasData withEnumeratedCards(CanvasData data) {
    int counter = 1;
    final updatedCards = data.cards.map((card) {
      if (card.autoNumber) {
        return card.copyWith(
          title:
              '${counter++}. ${card.title.replaceAll(RegExp(r'^\d+\.\s*'), '')}',
        );
      }
      return card;
    }).toList();
    return data.copyWith(cards: updatedCards);
  }
}
