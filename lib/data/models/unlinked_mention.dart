class UnlinkedMentionResult {
  final String sourceNoteId;
  final String targetTitle;
  final String context;
  final int position;

  UnlinkedMentionResult({
    required this.sourceNoteId,
    required this.targetTitle,
    required this.context,
    required this.position,
  });
}
