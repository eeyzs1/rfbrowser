import 'package:flutter/material.dart';

class CommandBar extends StatefulWidget {
  final ValueChanged<String> onCommand;
  final VoidCallback onClose;

  const CommandBar({super.key, required this.onCommand, required this.onClose});

  @override
  State<CommandBar> createState() => _CommandBarState();
}

class _CommandBarState extends State<CommandBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onCommand(text);
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration.collapsed(
                        hintText: 'Ask anything or type a command...',
                        hintStyle: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                      onSubmitted: (_) => _handleSubmit(),
                      onChanged: (value) {
                        setState(() {
                          _suggestions = _getSuggestions(value);
                        });
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
            ),
            if (_suggestions.isNotEmpty)
              Divider(height: 1, color: theme.dividerColor),
            if (_suggestions.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.arrow_right, size: 16),
                      title: Text(
                        _suggestions[index],
                        style: theme.textTheme.bodyMedium,
                      ),
                      onTap: () {
                        _controller.text = _suggestions[index];
                        _handleSubmit();
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _getSuggestions(String query) {
    if (query.isEmpty) return [];
    final commands = [
      'New Note',
      'New Tab',
      'Open Daily Note',
      'Search Notes',
      'Toggle Theme',
      'Settings',
      'AI Chat',
    ];
    return commands
        .where((c) => c.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}
