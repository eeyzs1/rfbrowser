import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/browser_tab.dart';
import 'package:rfbrowser/data/models/tab_group_proposal.dart';

class AutoGroupEngine {
  static bool canAutoGroup(List<BrowserTab> tabs) => tabs.length >= 3;

  static TabGroupProposal generateProposal(List<BrowserTab> tabs) {
    final domainGroups = <String, List<String>>{};

    for (final tab in tabs) {
      final uri = Uri.tryParse(tab.url);
      String domain;
      if (uri != null && uri.host.isNotEmpty) {
        domain = uri.host.replaceAll('www.', '');
        final parts = domain.split('.');
        if (parts.length > 2) {
          domain = parts.sublist(parts.length - 2).join('.');
        }
      } else if (tab.url == 'about:blank') {
        continue;
      } else {
        domain = 'other';
      }
      domainGroups.putIfAbsent(domain, () => []).add(tab.id);
    }

    final groups = <ProposedGroup>[];
    final groupColors = [0xFF2196F3, 0xFF4CAF50, 0xFFFF9800, 0xFF9C27B0, 0xFFF44336, 0xFF00BCD4];
    var colorIdx = 0;

    for (final entry in domainGroups.entries) {
      if (entry.value.length >= 2) {
        groups.add(
          ProposedGroup(
            name: entry.key,
            tabIds: entry.value,
            color: groupColors[colorIdx % groupColors.length],
          ),
        );
        colorIdx++;
      }
    }

    final groupedTabIds = groups.expand((g) => g.tabIds).toSet();
    final ungrouped = tabs
        .where((t) => !groupedTabIds.contains(t.id) && t.url != 'about:blank')
        .map((t) => t.id)
        .toList();
    if (ungrouped.isNotEmpty) {
      groups.add(
        ProposedGroup(
          name: 'Other',
          tabIds: ungrouped,
          color: groupColors[colorIdx % groupColors.length],
        ),
      );
    }

    return TabGroupProposal(groups: groups);
  }
}

void main() {
  group('AutoGroupEngine', () {
    test('AC-P2-3-3: canAutoGroup returns false for < 3 tabs', () {
      final tabs = [
        BrowserTab(id: '1', url: 'https://a.com'),
        BrowserTab(id: '2', url: 'https://b.com'),
      ];
      expect(AutoGroupEngine.canAutoGroup(tabs), false);
    });

    test('AC-P2-3-4: canAutoGroup returns true for >= 3 tabs', () {
      final tabs = [
        BrowserTab(id: '1', url: 'https://a.com'),
        BrowserTab(id: '2', url: 'https://b.com'),
        BrowserTab(id: '3', url: 'https://c.com'),
      ];
      expect(AutoGroupEngine.canAutoGroup(tabs), true);
    });

    test('AC-P2-3-1: generates groups by domain', () {
      final tabs = [
        BrowserTab(id: '1', url: 'https://github.com/repo1'),
        BrowserTab(id: '2', url: 'https://github.com/repo2'),
        BrowserTab(id: '3', url: 'https://news.site.com/a'),
        BrowserTab(id: '4', url: 'https://news.site.com/b'),
        BrowserTab(id: '5', url: 'https://news.site.com/c'),
      ];

      final proposal = AutoGroupEngine.generateProposal(tabs);
      expect(proposal.groups.length, greaterThanOrEqualTo(2));

      final githubGroup = proposal.groups.where((g) => g.name == 'github.com').firstOrNull;
      expect(githubGroup, isNotNull);
      expect(githubGroup!.tabIds.length, 2);

      final newsGroup = proposal.groups.where((g) => g.name == 'site.com').firstOrNull;
      expect(newsGroup, isNotNull);
      expect(newsGroup!.tabIds.length, 3);
    });

    test('AC-P2-3-2: allTabIds covers all input tabs', () {
      final tabs = [
        BrowserTab(id: '1', url: 'https://github.com/a'),
        BrowserTab(id: '2', url: 'https://github.com/b'),
        BrowserTab(id: '3', url: 'https://example.com/c'),
      ];

      final proposal = AutoGroupEngine.generateProposal(tabs);
      final allTabIds = proposal.allTabIds;
      final inputIds = tabs.map((t) => t.id).toSet();
      expect(allTabIds, inputIds);
    });

    test('skips about:blank tabs', () {
      final tabs = [
        BrowserTab(id: '0', url: 'about:blank'),
        BrowserTab(id: '1', url: 'https://github.com/a'),
        BrowserTab(id: '2', url: 'https://github.com/b'),
      ];

      final proposal = AutoGroupEngine.generateProposal(tabs);
      expect(proposal.allTabIds, isNot(contains('0')));
    });
  });
}
