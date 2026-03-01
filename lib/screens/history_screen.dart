import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/history_item.dart';
import '../widgets/formatted_text.dart';

String _extractTitleFromSummary(String summary, String fullExplanation) {
  final base = summary.trim().isNotEmpty ? summary.trim() : fullExplanation.trim();
  if (base.isEmpty) return "Saved explanation";

  final end = base.indexOf('.');
  if (end != -1) {
    return base.substring(0, end + 1).trim();
  }

  return base.length > 80 ? '${base.substring(0, 80)}…' : base;
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final box = Hive.box('history');

    return Scaffold(
      appBar: AppBar(
        title: const Text("History"),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        // ignore: unnecessary_underscores
        builder: (context, _, __) {
          if (box.isEmpty) {
            return _buildEmptyState(theme);
          }

          final items = List.generate(box.length, (index) {
            final map = Map<String, dynamic>.from(box.getAt(index));
            return HistoryItem.fromMap(map);
          }).reversed.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final title = _extractTitleFromSummary(
                item.summary,
                item.fullExplanation,
              );

              return Dismissible(
                key: ValueKey(item.timestamp.toIso8601String()),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(
                    Icons.delete,
                    color: theme.colorScheme.onError,
                  ),
                ),
                onDismissed: (_) {
                  final originalIndex = box.length - 1 - index;
                  box.deleteAt(originalIndex);
                },
                child: Card(
                  elevation: 1,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final deletedItem = await Navigator.push<HistoryItem?>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HistoryDetailScreen(item: item),
                        ),
                      );

                      if (deletedItem != null) {
                        final idx = box.values.toList().indexWhere((raw) {
                          final map = Map<String, dynamic>.from(raw);
                          final loaded = HistoryItem.fromMap(map);
                          return loaded.timestamp == deletedItem.timestamp;
                        });
                        if (idx != -1) {
                          box.deleteAt(idx);
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 28,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatTimestamp(item.timestamp),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 20),
            Text(
              "No history yet",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your past explanations will appear here.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    return "${time.month}/${time.day}/${time.year}  "
        "${time.hour}:${time.minute.toString().padLeft(2, '0')}";
  }
}

class HistoryDetailScreen extends StatelessWidget {
  final HistoryItem item;

  const HistoryDetailScreen({
    super.key,
    required this.item,
  });

  bool _isMeaningful(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return false;
    if (v == "none stated") return false;
    if (v == "none stated.") return false;
    if (v == "none") return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final fields = [
      _DetailFieldData(
        icon: Icons.description_outlined,
        label: "Summary",
        value: item.summary,
        alwaysShow: false,
      ),
      _DetailFieldData(
        icon: Icons.check_circle_outline,
        label: "Required Action",
        value: item.requiredAction,
        alwaysShow: true,
      ),
      _DetailFieldData(
        icon: Icons.schedule_outlined,
        label: "Deadline",
        value: item.deadline,
        alwaysShow: false,
      ),
      _DetailFieldData(
        icon: Icons.attach_money,
        label: "Money Involved",
        value: item.moneyInvolved,
        alwaysShow: false,
      ),
      _DetailFieldData(
        icon: Icons.warning_amber_outlined,
        label: "Consequences",
        value: item.consequences,
        alwaysShow: false,
      ),
    ];

    final visibleFields = fields.where((f) {
      if (f.alwaysShow) return true;
      return _isMeaningful(f.value);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Explanation"),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: theme.colorScheme.onSurface),
            tooltip: "Delete",
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) {
                  final dialogTheme = Theme.of(context);
                  return AlertDialog(
                    title: Text(
                      "Delete Entry",
                      style: dialogTheme.textTheme.titleLarge?.copyWith(
                        color: dialogTheme.colorScheme.onSurface,
                      ),
                    ),
                    content: Text(
                      "Are you sure you want to delete this explanation?",
                      style: dialogTheme.textTheme.bodyMedium?.copyWith(
                        color: dialogTheme.colorScheme.onSurface,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Delete"),
                      ),
                    ],
                  );
                },
              );

              if (confirmed == true && context.mounted) {
                Navigator.pop(context, item);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Saved on ${_formatTimestamp(item.timestamp)}",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (visibleFields.isNotEmpty) ...[
                      for (final field in visibleFields)
                        _buildPremiumCard(theme, field),
                      const SizedBox(height: 24),
                    ],
                    FormattedText(text: item.fullExplanation),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.share,
                    color: theme.colorScheme.onSurface,
                  ),
                  tooltip: "Share",
                  onPressed: () {
                    Share.share(item.fullExplanation);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard(ThemeData theme, _DetailFieldData data) {
    final bg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            data.icon,
            size: 28,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    return "${time.month}/${time.day}/${time.year}  "
        "${time.hour}:${time.minute.toString().padLeft(2, '0')}";
  }
}

class _DetailFieldData {
  final IconData icon;
  final String label;
  final String value;
  final bool alwaysShow;

  _DetailFieldData({
    required this.icon,
    required this.label,
    required this.value,
    this.alwaysShow = false,
  });
}