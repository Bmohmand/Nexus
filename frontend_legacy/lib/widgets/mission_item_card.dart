import 'package:flutter/material.dart';
import '../models/search_result.dart';

/// Displays a packed item from the knapsack optimizer result.
class MissionItemCard extends StatelessWidget {
  final PackedItem item;

  const MissionItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weightKg = (item.weightGrams * item.quantity / 1000).toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            'x${item.quantity}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${item.category} · ${weightKg}kg · ${(item.similarityScore * 100).toStringAsFixed(0)}% match',
        ),
        trailing: const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }
}
