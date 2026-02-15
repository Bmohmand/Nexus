import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/search_provider.dart';
import '../providers/mission_provider.dart';
import '../widgets/mission_item_card.dart';

/// Mission planner: describe a scenario, pick constraints, run the optimizer.
class MissionScreen extends ConsumerStatefulWidget {
  const MissionScreen({super.key});

  @override
  ConsumerState<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends ConsumerState<MissionScreen> {
  final _queryController = TextEditingController();

  void _runPack() {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    final preset = ref.read(selectedPresetProvider);
    ref.read(packStateProvider.notifier).runPack(
          query: query,
          constraints: preset,
        );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final packState = ref.watch(packStateProvider);
    final selectedPreset = ref.watch(selectedPresetProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mission Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () => context.push('/scan'),
            tooltip: 'Live Scan',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Mission Briefing ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mission Briefing',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _queryController,
                    decoration: const InputDecoration(
                      labelText: 'Mission Description',
                      hintText:
                          'e.g., 3-day winter camping trip, sub-zero temps',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                  const SizedBox(height: 12),

                  // Constraint preset
                  DropdownButtonFormField<String>(
                    initialValue: selectedPreset,
                    decoration: const InputDecoration(
                      labelText: 'Constraint Preset',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tune),
                    ),
                    items: constraintPresets.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(selectedPresetProvider.notifier).state =
                            value;
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: packState.isLoading ? null : _runPack,
                      icon: packState.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.rocket_launch),
                      label: Text(packState.isLoading
                          ? 'Optimizing...'
                          : 'Run Optimizer'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---- Error ----
          if (packState.error != null) ...[
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  packState.error!,
                  style: TextStyle(
                      color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ),
          ],

          // ---- Results ----
          if (packState.result != null) ...[
            const SizedBox(height: 16),

            // Summary card
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (packState.result!.missionSummary != null) ...[
                      Text(
                        packState.result!.missionSummary!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.backpack, size: 18),
                          label: Text(
                            '${packState.result!.packedItems.length} items',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        Chip(
                          avatar: const Icon(Icons.scale, size: 18),
                          label: Text(
                            '${(packState.result!.totalWeightGrams / 1000).toStringAsFixed(1)} kg',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        Chip(
                          avatar: const Icon(Icons.speed, size: 18),
                          label: Text(
                            '${(packState.result!.weightUtilization * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Warnings
            for (final warning in packState.result!.warnings)
              Card(
                color: theme.colorScheme.errorContainer,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(Icons.warning_amber,
                      color: theme.colorScheme.error),
                  title: Text(
                    warning,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

            // Packed items
            Text('Packed Items', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            ...packState.result!.packedItems
                .map((item) => MissionItemCard(item: item)),

            const SizedBox(height: 80),
          ],
        ],
      ),
    );
  }
}
