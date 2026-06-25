import 'dart:convert';

import '../../../core/logging/app_logger.dart';
import 'canvas_card.dart';
import 'canvas_connection.dart';
import 'canvas_group.dart';
import 'canvas_layer.dart';
import 'canvas_settings.dart';

class CanvasData {
  static const unassignedSentinel = '__unassigned__';

  final List<CanvasCard> cards;
  final List<CanvasConnection> connections;
  final List<CanvasGroup> groups;
  final List<CanvasLayer> layers;
  final CanvasSettings settings;
  final List<String> selectedCardIds;
  final String? inlineEditingCardId;
  final String? selectedConnectionId;
  final String? selectedLayerId;

  CanvasData({
    this.cards = const [],
    this.connections = const [],
    this.groups = const [],
    this.layers = const [],
    CanvasSettings? settings,
    this.selectedCardIds = const [],
    this.inlineEditingCardId,
    this.selectedConnectionId,
    this.selectedLayerId,
  }) : settings = settings ?? CanvasSettings();

  CanvasData copyWith({
    List<CanvasCard>? cards,
    List<CanvasConnection>? connections,
    List<CanvasGroup>? groups,
    List<CanvasLayer>? layers,
    CanvasSettings? settings,
    List<String>? selectedCardIds,
    String? inlineEditingCardId,
    String? selectedConnectionId,
    bool clearSelectedCardIds = false,
    bool clearInlineEditingCardId = false,
    bool clearSelectedConnectionId = false,
    String? selectedLayerId,
    bool clearSelectedLayerId = false,
  }) {
    return CanvasData(
      cards: cards ?? this.cards,
      connections: connections ?? this.connections,
      groups: groups ?? this.groups,
      layers: layers ?? this.layers,
      settings: settings ?? this.settings,
      selectedCardIds: clearSelectedCardIds
          ? []
          : (selectedCardIds ?? this.selectedCardIds),
      inlineEditingCardId: clearInlineEditingCardId
          ? null
          : (inlineEditingCardId ?? this.inlineEditingCardId),
      selectedConnectionId: clearSelectedConnectionId
          ? null
          : (selectedConnectionId ?? this.selectedConnectionId),
      selectedLayerId: clearSelectedLayerId
          ? null
          : (selectedLayerId ?? this.selectedLayerId),
    );
  }

  String toJsonString() => jsonEncode({
    'cards': cards.map((c) => c.toJson()).toList(),
    'connections': connections.map((c) => c.toJson()).toList(),
    'groups': groups.map((g) => g.toJson()).toList(),
    'layers': layers.map((l) => l.toJson()).toList(),
    'settings': settings.toJson(),
    if (selectedLayerId != null) 'selectedLayerId': selectedLayerId,
  });

  factory CanvasData.fromJsonString(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return CanvasData(
        cards:
            (data['cards'] as List?)
                ?.map((e) => CanvasCard.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        connections:
            (data['connections'] as List?)
                ?.map(
                  (e) => CanvasConnection.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            [],
        groups:
            (data['groups'] as List?)
                ?.map((e) => CanvasGroup.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        layers:
            (data['layers'] as List?)
                ?.map((e) => CanvasLayer.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        settings: data['settings'] != null
            ? CanvasSettings.fromJson(data['settings'] as Map<String, dynamic>)
            : CanvasSettings(),
        selectedLayerId: data['selectedLayerId'] as String?,
      );
    } catch (_) {
      appLog.error('CanvasData: failed to parse JSON');
      return CanvasData();
    }
  }
}
