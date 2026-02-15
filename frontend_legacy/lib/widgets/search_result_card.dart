import 'package:flutter/material.dart';
import '../models/search_result.dart';

/// Card displaying a single search result with similarity score and AI reasoning.
class SearchResultCard extends StatelessWidget {
  final SearchResultItem item;
  final bool isRejected;

  const SearchResultCard({
    super.key,
    required this.item,
    this.isRejected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scorePercent = (item.score * 100).toStringAsFixed(0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isRejected
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isRejected
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
          child: Text(
            '$scorePercent%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isRejected ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.utilitySummary != null)
              Text(
                item.utilitySummary!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (item.reason != null) ...[
              const SizedBox(height: 4),
              Text(
                item.reason!,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: isRejected
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (item.semanticTags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: item.semanticTags
                    .take(4)
                    .map((tag) => Chip(
                          label: Text(tag, style: const TextStyle(fontSize: 10)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
        isThreeLine: true,
        trailing: isRejected
            ? const Icon(Icons.cancel, color: Colors.red)
            : const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }
}
