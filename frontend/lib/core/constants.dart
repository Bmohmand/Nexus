// Manifest — App-wide constants.

/// Supabase Storage bucket for item images. Must be created in Dashboard → Storage.
const String kStorageBucketName = 'manifest-assets';

/// Base URL for the FastAPI middleware server.
/// Override via flutter_dotenv or compile-time env.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

/// Asset domains (must match the item_domain enum in the database).
enum AssetDomain {
  general('general', 'General'),
  clothing('clothing', 'Clothing'),
  medical('medical', 'Medical'),
  tech('tech', 'Tech'),
  camping('camping', 'Camping'),
  food('food', 'Food'),
  misc('misc', 'Misc');

  const AssetDomain(this.value, this.label);
  final String value;
  final String label;

  static AssetDomain fromString(String? s) {
    if (s == null) return AssetDomain.general;
    return AssetDomain.values.firstWhere(
      (d) => d.value == s,
      orElse: () => AssetDomain.general,
    );
  }
}

/// Item lifecycle status (must match item_status enum in DB).
enum ItemStatus {
  available('available', 'Available'),
  inUse('in_use', 'In Use'),
  needsRepair('needs_repair', 'Needs Repair'),
  retired('retired', 'Retired');

  const ItemStatus(this.value, this.label);
  final String value;
  final String label;

  static ItemStatus fromString(String? s) {
    if (s == null) return ItemStatus.available;
    return ItemStatus.values.firstWhere(
      (st) => st.value == s,
      orElse: () => ItemStatus.available,
    );
  }
}
