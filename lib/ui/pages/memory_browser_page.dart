import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/chat_memory.dart';
import '../../l10n/app_localizations.dart';
import '../../services/memory_service.dart';
import '../../services/memory_stats_service.dart';
import 'memory_graph_page.dart';

part 'memory_browser/memory_stats.dart';
part 'memory_browser/memory_fragments.dart';
part 'memory_browser/memory_summaries.dart';
part 'memory_browser/memory_hebbian.dart';
part 'memory_browser/memory_insights.dart';

/// Top-level browser for the memory subsystem.
///
/// Renders three panels:
///   - Fragments, grouped by tier (short / mid / long)
///   - L1/L2/L3 summaries
///   - Hebbian edges for the currently-selected fragment
class MemoryBrowserPage extends ConsumerStatefulWidget {
  const MemoryBrowserPage({super.key});

  @override
  ConsumerState<MemoryBrowserPage> createState() => _MemoryBrowserPageState();
}

class _MemoryBrowserPageState extends ConsumerState<MemoryBrowserPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _query = '';
  bool _onlyActive = true;
  bool _onlyPinned = false;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  /// 是否已看过引导卡片（null = 加载中，false = 首次进入需展示，true = 已关闭）
  bool? _hasSeenGuide;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadGuideFlag();
  }

  /// 从 SharedPreferences 读取引导卡片是否已看过
  Future<void> _loadGuideFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('hasSeenMemoryGuide') ?? false;
    if (mounted) setState(() => _hasSeenGuide = seen);
  }

  /// 关闭引导卡片并持久化标记
  Future<void> _dismissGuide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenMemoryGuide', true);
    if (mounted) setState(() => _hasSeenGuide = true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memory = ref.watch(memoryServiceProvider);
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.memoryBrowser),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree),
            tooltip: 'View network',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MemoryGraphPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l.refresh,
            onPressed: () {
              ref.invalidate(memoryStatsProvider);
              ref.invalidate(memoryInsightsProvider);
              setState(() {});
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.psychology), text: 'Fragments'),
            Tab(icon: Icon(Icons.notes), text: 'Summaries'),
            Tab(icon: Icon(Icons.account_tree), text: 'Hebbian'),
            Tab(icon: Icon(Icons.insights), text: 'Insights'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 首次进入时显示概念引导卡片
          if (_hasSeenGuide == false) _buildGuideCard(context, l),
          const _StatsOverview(),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search memory…',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            _searchDebounce?.cancel();
                            _searchDebounce = Timer(
                              const Duration(milliseconds: 200),
                              () {
                                if (mounted) {
                                  setState(
                                    () =>
                                        _query = _searchController.text.trim(),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Active'),
                        selected: _onlyActive,
                        onSelected: (v) => setState(() => _onlyActive = v),
                      ),
                      const SizedBox(width: 4),
                      FilterChip(
                        label: const Text('Pinned'),
                        selected: _onlyPinned,
                        onSelected: (v) => setState(() => _onlyPinned = v),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _FragmentsTab(
                        query: _query,
                        onlyActive: _onlyActive,
                        onlyPinned: _onlyPinned,
                        memory: memory,
                      ),
                      _SummariesTab(query: _query, memory: memory),
                      _HebbianTab(memory: memory, ref: ref),
                      const _InsightsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建首次进入的概念引导卡片（Info 风格）
  Widget _buildGuideCard(BuildContext context, AppLocalizations l) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.memoryGuideTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(l.memoryGuideDesc, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _GuideChip(text: l.memoryGuideFragments),
                    _GuideChip(text: l.memoryGuideSummaries),
                    _GuideChip(text: l.memoryGuideHebbian),
                    _GuideChip(text: l.memoryGuideInsights),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _dismissGuide,
                    child: Text(l.memoryGuideDismiss),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 引导卡片中的标签芯片
class _GuideChip extends StatelessWidget {
  final String text;
  const _GuideChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? hint;
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
              if (hint != null)
                Text(
                  hint!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Micro extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Micro({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: theme.hintColor),
        const SizedBox(width: 3),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.hintColor,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
