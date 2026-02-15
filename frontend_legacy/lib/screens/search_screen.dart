import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';
import '../widgets/search_result_card.dart';

/// AI semantic search screen.
/// Users describe a mission/need in natural language and get curated results.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  bool _submitted = false;

  void _runSearch() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    ref.read(searchQueryProvider.notifier).state = query;
    setState(() => _submitted = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Search')),
      body: Column(
        children: [
          // ---- Search Input ----
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Describe your mission',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText:
                            'e.g., 48-hour cold climate medical mission',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _runSearch(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _runSearch,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Search & Synthesize'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ---- Results ----
          Expanded(
            child: !_submitted
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.saved_search,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        const Text(
                          'Describe what you need.\nNexus will find the best items.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : results.when(
                    data: (response) {
                      if (response == null) {
                        return const SizedBox.shrink();
                      }

                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Mission summary
                          if (response.missionSummary != null) ...[
                            Card(
                              color: theme.colorScheme.primaryContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mission Analysis',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        color: theme.colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      response.missionSummary!,
                                      style: TextStyle(
                                        color: theme.colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Warnings
                          for (final warning in response.warnings)
                            Card(
                              color: theme.colorScheme.errorContainer,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(Icons.warning_amber,
                                    color: theme.colorScheme.error),
                                title: Text(
                                  warning,
                                  style: TextStyle(
                                    color:
                                        theme.colorScheme.onErrorContainer,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),

                          // Selected items
                          if (response.allItems.isNotEmpty) ...[
                            Text(
                              'Selected Items (${response.allItems.length})',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ...response.allItems.map(
                              (item) => SearchResultCard(item: item),
                            ),
                          ],

                          // Rejected items
                          if (response.rejectedItems.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Rejected (${response.rejectedItems.length})',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ...response.rejectedItems.map(
                              (item) => SearchResultCard(
                                  item: item, isRejected: true),
                            ),
                          ],

                          const SizedBox(height: 80),
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Searching & synthesizing...'),
                        ],
                      ),
                    ),
                    error: (err, _) => Center(
                      child: Text('Search failed: $err'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
