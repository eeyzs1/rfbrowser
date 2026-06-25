class CanvasSearchState {
  final String query;
  final List<String> matchedCardIds;
  final int activeIndex;

  const CanvasSearchState({
    this.query = '',
    this.matchedCardIds = const [],
    this.activeIndex = 0,
  });

  bool get isActive => query.isNotEmpty;

  CanvasSearchState copyWith({
    String? query,
    List<String>? matchedCardIds,
    int? activeIndex,
  }) {
    return CanvasSearchState(
      query: query ?? this.query,
      matchedCardIds: matchedCardIds ?? this.matchedCardIds,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }
}
