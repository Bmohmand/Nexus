import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/search_result.dart';
import '../services/api_client.dart';

/// Singleton API client for FastAPI middleware.
final apiClientProvider = Provider<NexusApiClient>((ref) {
  return NexusApiClient();
});

/// Current search query text.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Whether synthesis (LLM) is enabled for search.
final searchSynthesizeProvider = StateProvider<bool>((ref) => true);

/// Search results from the Nexus API.
/// Triggers a new search whenever the query changes.
final searchResultsProvider = FutureProvider<SearchResponse?>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return null;

  final client = ref.watch(apiClientProvider);
  final synthesize = ref.watch(searchSynthesizeProvider);

  return client.search(
    query: query,
    synthesize: synthesize,
  );
});

/// Pack results state.
class PackState {
  final bool isLoading;
  final PackResponse? result;
  final String? error;

  const PackState({this.isLoading = false, this.result, this.error});

  PackState copyWith({bool? isLoading, PackResponse? result, String? error}) {
    return PackState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      error: error,
    );
  }
}

final packStateProvider =
    StateNotifierProvider<PackNotifier, PackState>((ref) {
  return PackNotifier(ref.watch(apiClientProvider));
});

class PackNotifier extends StateNotifier<PackState> {
  final NexusApiClient _client;

  PackNotifier(this._client) : super(const PackState());

  Future<void> runPack({
    required String query,
    required dynamic constraints,
    int topK = 30,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _client.pack(
        query: query,
        constraints: constraints,
        topK: topK,
      );
      state = PackState(result: result);
    } catch (e) {
      state = PackState(error: e.toString());
    }
  }

  void reset() => state = const PackState();
}
