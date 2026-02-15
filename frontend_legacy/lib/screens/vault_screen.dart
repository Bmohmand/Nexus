import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/items_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/item_card.dart';
import '../widgets/domain_filter_chips.dart';

/// The Vault — grid view of all inventory items, filterable by domain.
class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsProvider);
    final selectedDomain = ref.watch(vaultDomainFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(itemsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          DomainFilterChips(
            selected: selectedDomain,
            onSelected: (domain) {
              ref.read(vaultDomainFilterProvider.notifier).state = domain;
            },
          ),
          Expanded(
            child: items.when(
              data: (itemList) {
                if (itemList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          'Your vault is empty',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text('Tap + to add your first item'),
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: itemList.length,
                  itemBuilder: (context, index) {
                    final item = itemList[index];
                    return ItemCard(
                      item: item,
                      onTap: () => context.push('/item/${item.id}'),
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) {
                if (err is NexusSchemaNotReadyException) {
                  return _SchemaSetupMessage(
                    onRetry: () => ref.invalidate(itemsProvider),
                  );
                }
                return Center(child: Text('Error: $err'));
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/ingest'),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Add Item'),
      ),
    );
  }
}

/// Shown when the manifest_items table doesn't exist yet (migrations not run).
class _SchemaSetupMessage extends StatelessWidget {
  final VoidCallback onRetry;

  const _SchemaSetupMessage({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.build_circle_outlined,
                        size: 40, color: theme.colorScheme.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Database not set up',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "The table public.manifest_items wasn't found. Run the database migration in your Supabase project:",
                ),
                const SizedBox(height: 12),
                SelectableText(
                  'backend/migrations/000_run_all_manifest.sql',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'In Supabase: Dashboard → SQL Editor → New query → paste the file contents → Run.',
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry after running migration'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
