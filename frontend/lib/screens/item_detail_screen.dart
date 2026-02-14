import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../providers/items_provider.dart';

/// Detail view for a single ManifestItem showing all AI-extracted metadata.
class ItemDetailScreen extends ConsumerWidget {
  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(itemDetailProvider(itemId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Item'),
                  content: const Text(
                      'Remove this item from your vault?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                final supabase = ref.read(supabaseServiceProvider);
                await supabase.deleteItem(itemId);
                ref.invalidate(itemsProvider);
                if (context.mounted) {
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item deleted')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: itemAsync.when(
        data: (item) {
          if (item == null) {
            return const Center(child: Text('Item not found'));
          }
          return ListView(
            children: [
              // Image
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: item.imageUrl!,
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 300,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 300,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image, size: 64),
                  ),
                )
              else
                Container(
                  height: 200,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.inventory_2, size: 64),
                  ),
                ),

              // Metadata
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Chip(label: Text(item.domain.label)),
                    if (item.category != null)
                      Chip(label: Text(item.category!)),
                    const Divider(height: 24),

                    // AI Context
                    if (item.utilitySummary != null) ...[
                      Text('Utility',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(item.utilitySummary!),
                      const SizedBox(height: 16),
                    ],

                    _row('Material', item.primaryMaterial),
                    _row('Weight', item.weightEstimate),
                    _row('Thermal', item.thermalRating),
                    _row('Water Resistance', item.waterResistance),
                    _row('Medical Use', item.medicalApplication),
                    _row('Durability', item.durability),
                    _row('Compressibility', item.compressibility),
                    _row('Quantity', '${item.quantity}'),
                    _row('Status', item.status.label),

                    if (item.semanticTags.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Tags',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: item.semanticTags
                            .map((t) => Chip(
                                  label: Text(t,
                                      style: const TextStyle(fontSize: 12)),
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
