class TabGroupProposal {
  final List<ProposedGroup> groups;

  TabGroupProposal({required this.groups});

  Set<String> get allTabIds =>
      groups.expand((g) => g.tabIds).toSet();
}

class ProposedGroup {
  final String name;
  final List<String> tabIds;
  final int color;

  ProposedGroup({
    required this.name,
    required this.tabIds,
    this.color = 0xFF2196F3,
  });
}
