import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item.dart';
import '../core/constants.dart';
import '../services/supabase_service.dart';

/// Singleton Supabase service.
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

/// Currently selected domain filter in the Vault.
final vaultDomainFilterProvider = StateProvider<AssetDomain?>((ref) => null);

/// Fetches the list of items from Supabase, filtered by domain.
final itemsProvider = FutureProvider<List<NexusItem>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  final domain = ref.watch(vaultDomainFilterProvider);
  return service.fetchItems(domain: domain);
});

/// Fetches total item count.
final itemCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.itemCount();
});

/// Fetches a single item by ID.
final itemDetailProvider =
    FutureProvider.family<NexusItem?, String>((ref, id) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.fetchItem(id);
});
