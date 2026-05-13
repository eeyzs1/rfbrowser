part of '../canvas_page.dart';

mixin CanvasPanelsMixin on _CanvasViewStateBase {
    @override
    Widget _buildZoomControls(ThemeData theme) {
      final l = AppLocalizations.of(context)!;
      return Positioned(
        right: 12,
        bottom: 40,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: _zoomIn,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: l.zoomIn,
                color: theme.hintColor,
              ),
              Container(
                width: 32,
                height: 24,
                alignment: Alignment.center,
                child: Text(
                  '${(_scale * 100).round()}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                onPressed: _zoomOut,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: l.zoomOut,
                color: theme.hintColor,
              ),
              Container(width: 24, height: 1, color: theme.dividerColor),
              IconButton(
                icon: const Icon(Icons.filter_center_focus, size: 16),
                onPressed: _zoomReset,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: l.resetZoom,
                color: theme.hintColor,
              ),
            ],
          ),
        ),
      );
    }

    @override
    Widget _buildMinimap(ThemeData theme, CanvasData canvasData) {
      if (canvasData.cards.isEmpty) return const SizedBox.shrink();

      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
      for (final card in canvasData.cards) {
        minX = math.min(minX, card.x);
        minY = math.min(minY, card.y);
        maxX = math.max(maxX, card.x + card.width);
        maxY = math.max(maxY, card.y + card.height);
      }

      const minimapW = 160.0;
      const minimapH = 100.0;
      const padding = 20.0;

      final contentW = maxX - minX + padding * 2;
      final contentH = maxY - minY + padding * 2;
      final mmScale = math.min(minimapW / contentW, minimapH / contentH);

      final contentMinimapW = contentW * mmScale;
      final contentMinimapH = contentH * mmScale;
      final offsetX = (minimapW - contentMinimapW) / 2;
      final offsetY = (minimapH - contentMinimapH) / 2;

      return Positioned(
        left: 12,
        bottom: 40,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTapUp: (details) {
              final tapLocal = details.localPosition;
              final worldX = minX - padding + (tapLocal.dx - offsetX) / mmScale;
              final worldY = minY - padding + (tapLocal.dy - offsetY) / mmScale;
              _cameraX = worldX;
              _cameraY = worldY;
              _cameraNotifier.notify();
            },
            child: Container(
              width: minimapW,
              height: minimapH,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: CustomPaint(
                  size: const Size(minimapW, minimapH),
                  painter: MinimapPainter(
                    cards: canvasData.cards,
                    connections: canvasData.connections,
                    minX: minX - padding,
                    minY: minY - padding,
                    mmScale: mmScale,
                    offsetX: offsetX,
                    offsetY: offsetY,
                    cameraX: _cameraX,
                    cameraY: _cameraY,
                    viewW: _viewW,
                    viewH: _viewH,
                    scale: _scale,
                    primaryColor: theme.colorScheme.primary,
                    dividerColor: theme.dividerColor,
                    cardColor: theme.hintColor,
                    scaffoldBg: theme.scaffoldBackgroundColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    @override
    Widget _buildInlineEditor(
      ThemeData theme,
      CanvasData canvasData,
      AppSettings settings,
    ) {
      final l = AppLocalizations.of(context)!;
      final card = ref
          .read(canvasProvider.notifier)
          .cardById(_inlineEditingCardId!);
      if (card == null) return const SizedBox.shrink();

      final pos = _w2s(card.x, card.y);
      final cardScreenW = card.width * _scale;
      final cardScreenH = card.height * _scale;
      final headerH = 30.0 * _scale;
      final cardFontSize = card.effectiveFontSize(settings.editorFontSize);
      final scaledFont = cardFontSize * _scale;
      final accentW = 3.0 * _scale;
      final padH = 10.0 * _scale;

      return Positioned(
        left: pos.dx,
        top: pos.dy,
        width: cardScreenW,
        height: cardScreenH,
        child: IgnorePointer(
          ignoring: false,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      Container(
                        height: headerH,
                        padding: EdgeInsets.only(
                          left: accentW + padH,
                          right: accentW + padH,
                        ),
                        color: Colors.transparent,
                        alignment: Alignment.centerLeft,
                        child: TextField(
                          controller: _inlineTitleCtrl,
                          focusNode: _inlineTitleFocus,
                          style: TextStyle(
                            fontSize: scaledFont,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2 / _scale,
                            height: 1.0,
                          ),
                          strutStyle: StrutStyle(
                            forceStrutHeight: true,
                            height: 1.0,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: l.title,
                            hintStyle: TextStyle(
                              color: theme.hintColor.withValues(alpha: 0.5),
                              fontSize: scaledFont,
                            ),
                          ),
                          onSubmitted: (_) => _inlineContentFocus?.requestFocus(),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: Colors.transparent,
                          padding: EdgeInsets.only(
                            left: accentW + padH,
                            right: accentW + padH,
                            top: 4 * _scale,
                          ),
                          child: TextField(
                            controller: _inlineContentCtrl,
                            focusNode: _inlineContentFocus,
                            style: TextStyle(
                              fontSize: scaledFont * 1.06,
                              height: 1.4,
                            ),
                            strutStyle: StrutStyle(
                              forceStrutHeight: true,
                              height: 1.4,
                            ),
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              hintText: card.type == CanvasCardType.note
                                  ? l.noteContent
                                  : l.typeSomething,
                              hintStyle: TextStyle(
                                color: theme.hintColor.withValues(alpha: 0.5),
                                fontSize: scaledFont * 1.06,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: accentW,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    @override
    Offset _w2s(double wx, double wy) {
      return Offset(
        (wx - _cameraX) * _scale + _viewW / 2,
        (wy - _cameraY) * _scale + _viewH / 2,
      );
    }


}
