import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/items_provider.dart';
import '../widgets/stat_chip.dart';

/// Manifest home dashboard with stats, quick actions, and readiness score.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemCount = ref.watch(itemCountProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manifest'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              // TODO: Profile / settings
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Quick Actions ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quick Actions', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _QuickAction(
                        icon: Icons.camera_alt,
                        label: 'Add Item',
                        onTap: () => context.push('/ingest'),
                      ),
                      _QuickAction(
                        icon: Icons.search,
                        label: 'Search',
                        onTap: () => context.go('/search'),
                      ),
                      _QuickAction(
                        icon: Icons.backpack,
                        label: 'Mission',
                        onTap: () => context.go('/missions'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- Inventory Stats ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Vault', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  itemCount.when(
                    data: (count) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        StatChip(
                          label: 'Items',
                          value: '$count',
                          icon: Icons.inventory_2,
                        ),
                        const StatChip(
                          label: 'Domains',
                          value: '6',
                          icon: Icons.category,
                        ),
                        const StatChip(
                          label: 'Ready',
                          value: '--',
                          icon: Icons.check_circle,
                        ),
                      ],
                    ),
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (_, __) => const Text('Could not load stats'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- Readiness Score ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Readiness Score', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: 0.0, // TODO: calculate from item coverage
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add items and run a mission to see your readiness score.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- Underutilized Assets ----
          Text('Underutilized Assets', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline,
                  color: theme.colorScheme.primary),
              title: const Text('No usage data yet'),
              subtitle: const Text(
                'Items unused for 90+ days will appear here.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
