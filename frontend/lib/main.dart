import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'api_service.dart';
import 'models/storage_container.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math' as math;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexus - Physical World API',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _explainResults = false;
  List<StorageContainer> _containers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _testConnections(); // Test backend and Supabase on startup
    _loadContainers();
  }

  Future<void> _loadContainers() async {
    final data = await NexusApiService.getContainers();
    if (data != null && mounted) {
      setState(() {
        _containers = data.map((c) => StorageContainer.fromJson(c)).toList();
        // Pre-select default containers
        for (final c in _containers) {
          c.isSelected = c.isDefault;
        }
      });
    }
  }

  /// Test both backend and Supabase connections
  Future<void> _testConnections() async {
    // Wait a moment for the UI to render
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Test Supabase
    final supabaseOk = await NexusApiService.supabaseHealthCheck();
    
    // Test Backend (will fail if not configured yet, that's OK)
    final backendOk = await NexusApiService.healthCheck();
    
    if (!mounted) return;
    
    // Show status
    String message = '';
    Color color = const Color(0xFF10B981);
    
    if (supabaseOk && backendOk) {
      message = '✅ Connected: Supabase & Backend';
      color = const Color(0xFF10B981); // Green
    } else if (supabaseOk && !backendOk) {
      message = '⚠️ Supabase: ✅ | Backend: ❌ (Check .env API_BASE_URL & ensure backend is running)';
      color = const Color(0xFFF59E0B); // Orange
    } else if (!supabaseOk && backendOk) {
      message = '⚠️ Supabase: ❌ | Backend: ✅';
      color = const Color(0xFFF59E0B); // Orange
    } else {
      message = '❌ Not Connected: Check configuration';
      color = const Color(0xFFEF4444); // Red
    }
    
    // Show snackbar with status
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  /// Show detailed connection status
  void _showConnectionStatus() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Test connections
    final supabaseOk = await NexusApiService.supabaseHealthCheck();
    final backendOk = await NexusApiService.healthCheck();

    if (!mounted) return;
    Navigator.pop(context); // Close loading

    // Show results
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.wifi_tethering, color: Color(0xFF6366F1)),
            SizedBox(width: 12),
            Text('Connection Status', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusRow('Supabase Database', supabaseOk),
            const SizedBox(height: 12),
            _buildStatusRow('FastAPI Backend', backendOk),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configuration',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Supabase: ${supabaseOk ? "Connected" : "Check credentials"}',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Backend: ${backendOk ? "Connected" : "Check .env API_BASE_URL & ensure backend is running"}',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!backendOk || !supabaseOk)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _testConnections();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool isConnected) {
    return Row(
      children: [
        Icon(
          isConnected ? Icons.check_circle : Icons.cancel,
          color: isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        Text(
          isConnected ? 'Online' : 'Offline',
          style: TextStyle(
            color: isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  const ItemsGridView(),
                  const CameraIngestView(),
                  const GraphVisualizationView(),
                  ContainersView(onContainersChanged: _loadContainers),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.hub_outlined, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nexus',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Physical World API',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: _showConnectionStatus,
                icon: const Icon(Icons.settings_outlined, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isSearching ? const Color(0xFF6366F1) : Colors.transparent,
                width: 2,
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Describe your mission... (e.g., "3-week disaster relief in cold climate")',
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.mic, color: Color(0xFF8B5CF6)),
                      onPressed: () {
                        // Voice input integration point
                      },
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF64748B)),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _isSearching = false;
                          });
                        },
                      ),
                  ],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _isSearching = value.isNotEmpty;
                });
              },
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _performSemanticSearch(value);
                }
              },
            ),
          ),
          if (_isSearching) ...[
            const SizedBox(height: 12),
            if (_containers.isNotEmpty) ...[
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _containers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final c = _containers[index];
                    return FilterChip(
                      label: Text(
                        '${c.name} (${c.weightDisplayLbs})',
                        style: TextStyle(
                          fontSize: 12,
                          color: c.isSelected ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                      selected: c.isSelected,
                      onSelected: (selected) {
                        setState(() {
                          c.isSelected = selected;
                        });
                      },
                      avatar: Icon(
                        Icons.luggage_outlined,
                        size: 16,
                        color: c.isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                      selectedColor: const Color(0xFF6366F1),
                      backgroundColor: const Color(0xFF1E293B),
                      side: BorderSide(
                        color: c.isSelected ? const Color(0xFF6366F1) : const Color(0xFF334155),
                      ),
                      showCheckmark: false,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_containers.any((c) => c.isSelected))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.insights, color: Color(0xFF94A3B8), size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'AI insights',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 24,
                      child: Switch(
                        value: _explainResults,
                        onChanged: (v) => setState(() => _explainResults = v),
                        activeColor: const Color(0xFF6366F1),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 30, 41, 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color.fromRGBO(255, 99, 102, 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _containers.any((c) => c.isSelected)
                          ? 'AI will pack items into selected containers'
                          : 'AI-powered semantic search across all your items',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(
          top: BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.transparent,
        selectedItemColor: const Color(0xFF6366F1),
        unselectedItemColor: const Color(0xFF64748B),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Items',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_outlined),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.scatter_plot_rounded),
            label: 'Graph',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.luggage_outlined),
            label: 'Storage',
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        setState(() {
          _selectedIndex = 1;
        });
      },
      backgroundColor: const Color(0xFF6366F1),
      elevation: 8,
      icon: const Icon(Icons.add_a_photo, color: Colors.white),
      label: const Text(
        'Quick Scan',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _performSemanticSearch(String query) async {
    final selectedContainers = _containers.where((c) => c.isSelected).toList();

    setState(() {
      _isSearching = true;
    });

    // Show loading state
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  selectedContainers.isNotEmpty
                      ? 'Packing into ${selectedContainers.length} container(s)...'
                      : 'Searching vector space...',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      if (selectedContainers.isNotEmpty) {
        // Multi-container pack
        final containerIds = selectedContainers.map((c) => c.id).toList();
        final result = await NexusApiService.packMultiContainer(
          query: query,
          containerIds: containerIds,
          topK: 30,
          explain: _explainResults,
        );

        if (mounted) {
          Navigator.pop(context);
          if (result != null) {
            _showMultiPackResults(result);
          } else {
            _showErrorDialog('Multi-container packing failed.');
          }
        }
      } else {
        // Regular semantic search
        final results = await NexusApiService.semanticSearch(
          query: query,
          topK: 15,
        );

        if (mounted) {
          Navigator.pop(context);
          if (results != null && results.isNotEmpty) {
            _showSearchResults(results);
          } else {
            _showNoResultsDialog();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorDialog('Search failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _showSearchResults(List<Map<String, dynamic>> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          '${results.length} Results',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: results.length,
            itemBuilder: (context, index) {
              final item = results[index];
              final imageUrl = item['image_url'] as String?;
              return Card(
                color: const Color(0xFF334155),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: (imageUrl != null && imageUrl.isNotEmpty)
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.check_circle,
                                color: Color(0xFF10B981),
                              ),
                            )
                          : const Icon(
                              Icons.check_circle,
                              color: Color(0xFF10B981),
                            ),
                    ),
                  ),
                  title: Text(
                    item['name'] ?? 'Item ${index + 1}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    item['category'] ?? 'Unknown category',
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                  trailing: Text(
                    '${((item['score'] ?? 0) * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Color(0xFF6366F1)),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMultiPackResults(Map<String, dynamic> result) {
    final containers = List<Map<String, dynamic>>.from(result['containers'] ?? []);
    final warnings = List<String>.from(result['warnings'] ?? []);
    final missionSummary = result['mission_summary'] as String?;
    final status = result['status'] as String? ?? 'unknown';
    final totalWeight = (result['total_weight_grams'] as num?)?.toDouble() ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            Icon(
              status == 'optimal' ? Icons.check_circle : Icons.warning_amber,
              color: status == 'optimal' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pack Result (${(totalWeight / 453.592).toStringAsFixed(1)} lbs)',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (missionSummary != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    missionSummary,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ...containers.map((container) {
                final cName = container['container_name'] as String? ?? 'Container';
                final cMaxWeight = (container['max_weight_grams'] as num?)?.toDouble() ?? 0;
                final cTotalWeight = (container['total_weight_grams'] as num?)?.toDouble() ?? 0;
                final cUtilization = (container['weight_utilization'] as num?)?.toDouble() ?? 0;
                final packedItems = List<Map<String, dynamic>>.from(container['packed_items'] ?? []);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.luggage_outlined, color: Color(0xFF6366F1), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          '${(cTotalWeight / 453.592).toStringAsFixed(1)} / ${(cMaxWeight / 453.592).toStringAsFixed(1)} lbs',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: cUtilization.clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFF334155),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          cUtilization > 0.9 ? const Color(0xFFF59E0B) : const Color(0xFF6366F1),
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...packedItems.map((item) => Card(
                          color: const Color(0xFF334155),
                          margin: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                            title: Text(
                              '${item['name']} x${item['quantity'] ?? 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                            subtitle: Text(
                              item['category'] ?? '',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                            trailing: Text(
                              '${((item['weight_grams'] as num? ?? 0) * (item['quantity'] as num? ?? 1) / 453.592).toStringAsFixed(1)} lbs',
                              style: const TextStyle(color: Color(0xFF6366F1), fontSize: 11),
                            ),
                          ),
                        )),
                    if (packedItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No items assigned to this container',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
              if (warnings.isNotEmpty) ...[
                const Divider(color: Color(0xFF334155)),
                ...warnings.map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber, color: Color(0xFFF59E0B), size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              w,
                              style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNoResultsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'No Results',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'No items found matching your search criteria.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Error',
          style: TextStyle(color: Color(0xFFEF4444)),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    }
  }


// Items Grid View — fetches real data from backend / Supabase
class ItemsGridView extends StatefulWidget {
  const ItemsGridView({super.key});

  @override
  State<ItemsGridView> createState() => _ItemsGridViewState();
}

class _ItemsGridViewState extends State<ItemsGridView> {
  List<Map<String, dynamic>> _items = [];
  int _itemCount = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await NexusApiService.getItems(limit: 100);
      if (result != null) {
        final itemsList = result['items'] as List<dynamic>? ?? [];
        setState(() {
          _items = List<Map<String, dynamic>>.from(itemsList);
          _itemCount = result['count'] as int? ?? _items.length;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load items';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Collection',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isLoading
                        ? 'Loading...'
                        : '$_itemCount items indexed',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Refresh button
                  GestureDetector(
                    onTap: _fetchItems,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.refresh, size: 16, color: Color(0xFF6366F1)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.filter_list, size: 16, color: Color(0xFF6366F1)),
                        SizedBox(width: 6),
                        Text(
                          'Filter',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _fetchItems,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, color: Color(0xFF64748B), size: 48),
            SizedBox(height: 12),
            Text(
              'No items yet',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Scan items using the camera to add them',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchItems,
      color: const Color(0xFF6366F1),
      child: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          return _buildItemCard(_items[index]);
        },
      ),
    );
  }

 Widget _buildItemCard(Map<String, dynamic> item) {
  final imageUrl = item['image_url'] as String?;
  final name = item['name'] as String? ?? 'Unknown Item';
  final category = item['category'] as String? ?? 'misc';

  return GestureDetector(  // ADD THIS
    onTap: () {  // ADD THIS
      Navigator.push(  // ADD THIS
        context,  // ADD THIS
        MaterialPageRoute(  // ADD THIS
          builder: (context) => ItemDetailPage(item: item),  // ADD THIS
        ),  // ADD THIS
      );  // ADD THIS
    },  // ADD THIS
    child: Container(  // CHANGE: was just "Container(" before
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF334155),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: const Color(0xFF6366F1),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stack) => Center(
                          child: Icon(
                            _getCategoryIcon(category),
                            size: 48,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          _getCategoryIcon(category),
                          size: 48,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 99, 102, 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Color(0xFF6366F1),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    )
  );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'clothing':
        return Icons.checkroom;
      case 'medical':
        return Icons.medical_services_outlined;
      case 'survival':
      case 'camping':
        return Icons.outdoor_grill_outlined;
      case 'tech':
        return Icons.devices_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      default:
        return Icons.category;
    }
  }
}

// Camera Ingest View
class CameraIngestView extends StatefulWidget {
  const CameraIngestView({super.key});

  @override
  State<CameraIngestView> createState() => _CameraIngestViewState();
}

class _CameraIngestViewState extends State<CameraIngestView> {
  bool _isProcessing = false;
  String? _selectedImagePath;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            height: 400,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color.fromRGBO(255, 99, 102, 0.3),
                width: 2,
              ),
            ),
            child: _isProcessing
                ? _buildProcessingState()
                : (_selectedImagePath != null
                    ? _buildImagePreview()
                    : _buildCameraPlaceholder()),
          ),
          const SizedBox(height: 24),
          const Text(
            'Universal Item Ingest',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No forms. No categories. Just scan.',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _captureImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt),
                      SizedBox(width: 8),
                      Text(
                        'Capture Image',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isProcessing ? null : _pickFromGallery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                  elevation: 0,
                ),
                child: const Icon(Icons.photo_library),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 30, 41, 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI extracts utility, materials, and context',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.hub, color: Color(0xFF8B5CF6), size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Multimodal embeddings index to vector space',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF334155),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_a_photo,
            size: 64,
            color: Color(0xFF6366F1),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Camera Preview',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(
          color: Color(0xFF6366F1),
        ),
        const SizedBox(height: 24),
        const Text(
          'Processing Image',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Extracting context with GPT-4o Vision',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF334155),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Generating multimodal embeddings...',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.file(
            File(_selectedImagePath!),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                setState(() {
                  _selectedImagePath = null;
                });
              },
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: ElevatedButton(
            onPressed: () => _processAndIngestImage(_selectedImagePath!),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload),
                SizedBox(width: 8),
                Text(
                  'Process & Upload',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _captureImage() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      // Capture image from camera
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (photo != null) {
        setState(() {
          _selectedImagePath = photo.path;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Camera error: $e');
      }
    }
  }

  void _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      // Pick image from gallery
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Gallery error: $e');
      }
    }
  }

  /// Process and ingest image to backend
  /// NEW: First uploads to Supabase Storage, then sends URL to backend
  Future<void> _processAndIngestImage(String imagePath) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Step 1: Upload image to Supabase Storage
      final imageUrl = await NexusApiService.uploadImageToStorage(imagePath);
      
      if (imageUrl == null) {
        throw Exception('Failed to upload image to storage');
      }

      // Step 2: Send image URL to backend for AI processing
      final result = await NexusApiService.ingestImage(
        imageUrl: imageUrl,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _selectedImagePath = null; // Clear preview after upload
        });

        if (result != null) {
          _showSuccessDialog();
        } else {
          _showErrorDialog('Failed to process image. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _showErrorDialog('Error: $e');
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Item Indexed!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vector embedding created and stored in Pinecone',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Error',
          style: TextStyle(color: Color(0xFFEF4444)),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
      }
    }

// Graph Visualization View
class GraphVisualizationView extends StatefulWidget {
  const GraphVisualizationView({super.key});

  @override
  State<GraphVisualizationView> createState() => _GraphVisualizationViewState();
}

class _GraphVisualizationViewState extends State<GraphVisualizationView> {
  List<GraphNode> _nodes = [];
  bool _isLoading = true;
  String _statusMessage = 'Loading items...';
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  double _lastRotationX = 0.0;
  double _lastRotationY = 0.0;

  @override
  void initState() {
    super.initState();
    _loadGraphData();
  }

  Future<void> _loadGraphData() async {
    try {
      setState(() {
        _statusMessage = 'Fetching items from database...';
      });

      // Fetch items with embeddings
      final items = await NexusApiService.getManifestItems();
      
      if (items == null || items.isEmpty) {
        setState(() {
          _statusMessage = 'No items found';
          _isLoading = false;
        });
        return;
      }

      // Filter items with embeddings
      final itemsWithEmbeddings = items.where((item) {
        final embedding = item['embedding'];
        return embedding != null && embedding is List && embedding.isNotEmpty;
      }).toList();

      if (itemsWithEmbeddings.isEmpty) {
        setState(() {
          _statusMessage = 'No items with embeddings found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Reducing ${itemsWithEmbeddings.length} embeddings to 3D...';
      });

      // Extract embeddings as List<List<double>>
      final embeddings = itemsWithEmbeddings.map((item) {
        final embedding = item['embedding'] as List;
        return embedding.map((e) => (e as num).toDouble()).toList();
      }).toList();

      // Perform PCA to reduce to 3D
      final positions3D = _performPCA(embeddings, 3);

      // Create graph nodes
      final nodes = <GraphNode>[];
      for (int i = 0; i < itemsWithEmbeddings.length; i++) {
        final item = itemsWithEmbeddings[i];
        final category = (item['category'] ?? item['domain'] ?? 'misc').toString().toLowerCase();
        
        nodes.add(GraphNode(
          id: item['id']?.toString() ?? i.toString(),
          name: item['name']?.toString() ?? 'Unknown Item',
          category: category,
          position: vm.Vector3(
            positions3D[i][0],
            positions3D[i][1],
            positions3D[i][2],
          ),
          color: _getCategoryColor(category),
        ));
      }

      setState(() {
        _nodes = nodes;
        _isLoading = false;
        _statusMessage = '';
      });

    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isLoading = false;
      });
      print('Error loading graph data: $e');
    }
  }

  // Simple PCA implementation
  List<List<double>> _performPCA(List<List<double>> embeddings, int targetDim) {
    final n = embeddings.length;
    final d = embeddings[0].length;

    print('PCA: $n items, $d dimensions → $targetDim dimensions');

    // Center the data
    final mean = List<double>.filled(d, 0.0);
    for (var emb in embeddings) {
      for (int j = 0; j < d; j++) {
        mean[j] += emb[j];
      }
    }
    for (int j = 0; j < d; j++) {
      mean[j] /= n;
    }

    final centered = embeddings.map((emb) {
      return List.generate(d, (j) => emb[j] - mean[j]);
    }).toList();

    // Simple projection (approximate PCA)
    final positions = <List<double>>[];
    final third = d ~/ 3;
    
    for (var emb in centered) {
      final x = emb.sublist(0, third).reduce((a, b) => a + b) / third;
      final y = emb.sublist(third, third * 2).reduce((a, b) => a + b) / third;
      final z = emb.sublist(third * 2).reduce((a, b) => a + b) / (d - third * 2);
      
      positions.add([x * 50, y * 50, z * 50]);
    }

    return positions;
  }

  Color _getCategoryColor(String category) {
    const colors = {
      'clothing': Color(0xFF6366F1),
      'medical': Color(0xFFEF4444),
      'survival': Color(0xFF10B981),
      'tech': Color(0xFF8B5CF6),
      'food': Color(0xFFF59E0B),
      'camping': Color(0xFF14B8A6),
    };
    return colors[category] ?? const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF6366F1),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // 3D Graph
                GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _rotationY += details.delta.dx * 0.01;
                      _rotationX += details.delta.dy * 0.01;
                    });
                  },
                  onPanEnd: (details) {
                    _lastRotationX = _rotationX;
                    _lastRotationY = _rotationY;
                  },
                  child: CustomPaint(
                    painter: Graph3DPainter(
                      nodes: _nodes,
                      rotationX: _rotationX,
                      rotationY: _rotationY,
                    ),
                    size: Size.infinite,
                  ),
                ),
                
                // Legend
                Positioned(
                  top: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Semantic Graph',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_nodes.length} items in vector space',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildLegendItem('Clothing', const Color(0xFF6366F1)),
                        _buildLegendItem('Medical', const Color(0xFFEF4444)),
                        _buildLegendItem('Survival', const Color(0xFF10B981)),
                        _buildLegendItem('Tech', const Color(0xFF8B5CF6)),
                        _buildLegendItem('Food', const Color(0xFFF59E0B)),
                      ],
                    ),
                  ),
                ),
                
                // Hint
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Drag to rotate • Items cluster by semantic similarity',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// Graph Node Model
class GraphNode {
  final String id;
  final String name;
  final String category;
  final vm.Vector3 position;
  final Color color;

  GraphNode({
    required this.id,
    required this.name,
    required this.category,
    required this.position,
    required this.color,
  });
}

// 3D Graph Painter
class Graph3DPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final double rotationX;
  final double rotationY;

  Graph3DPainter({
    required this.nodes,
    required this.rotationX,
    required this.rotationY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scale = 3.0;

    // Sort nodes by Z position (painter's algorithm)
    final sortedNodes = List<GraphNode>.from(nodes);
    sortedNodes.sort((a, b) {
      final aRotated = _rotatePoint(a.position);
      final bRotated = _rotatePoint(b.position);
      return bRotated.z.compareTo(aRotated.z);
    });

    // Draw nodes
    for (final node in sortedNodes) {
      final rotated = _rotatePoint(node.position);
      
      // Perspective projection
      final perspective = 1.0 / (1.0 + rotated.z / 500);
      final screenX = centerX + rotated.x * scale * perspective;
      final screenY = centerY + rotated.y * scale * perspective;
      
      // Node size based on depth
      final nodeSize = 8.0 * perspective;
      
      // Draw node with glow
      final paint = Paint()
        ..color = node.color.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      
      canvas.drawCircle(
        Offset(screenX, screenY),
        nodeSize * 2,
        paint,
      );
      
      final nodePaint = Paint()
        ..color = node.color
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(screenX, screenY),
        nodeSize,
        nodePaint,
      );
    }
  }

  vm.Vector3 _rotatePoint(vm.Vector3 point) {
    // Rotate around Y axis
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);
    final x1 = point.x * cosY - point.z * sinY;
    final z1 = point.x * sinY + point.z * cosY;
    
    // Rotate around X axis
    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);
    final y2 = point.y * cosX - z1 * sinX;
    final z2 = point.y * sinX + z1 * cosX;
    
    return vm.Vector3(x1, y2, z2);
  }

  @override
  bool shouldRepaint(Graph3DPainter oldDelegate) {
    return rotationX != oldDelegate.rotationX ||
           rotationY != oldDelegate.rotationY ||
           nodes != oldDelegate.nodes;
  }
}

// Storage Containers View
class ContainersView extends StatefulWidget {
  final VoidCallback? onContainersChanged;

  const ContainersView({super.key, this.onContainersChanged});

  @override
  State<ContainersView> createState() => _ContainersViewState();
}

class _ContainersViewState extends State<ContainersView> {
  List<StorageContainer> _containers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchContainers();
  }

  Future<void> _fetchContainers() async {
    setState(() => _isLoading = true);
    final data = await NexusApiService.getContainers();
    if (data != null && mounted) {
      setState(() {
        _containers = data.map((c) => StorageContainer.fromJson(c)).toList();
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showContainerForm({StorageContainer? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final weightCtrl = TextEditingController(
      text: existing != null
          ? (existing.maxWeightGrams / 453.592).toStringAsFixed(1)
          : '',
    );
    final qtyCtrl = TextEditingController(
      text: existing?.quantity.toString() ?? '1',
    );
    String selectedType = existing?.containerType ?? 'bag';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            existing != null ? 'Edit Container' : 'Add Container',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    hintText: 'e.g., Carry-on Luggage',
                    hintStyle: TextStyle(color: Color(0xFF475569)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6366F1)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: const Color(0xFF334155),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6366F1)),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'bag', child: Text('Bag / Backpack')),
                    DropdownMenuItem(value: 'case', child: Text('Case / Suitcase')),
                    DropdownMenuItem(value: 'crate', child: Text('Crate / Box')),
                    DropdownMenuItem(value: 'drone_payload', child: Text('Drone Payload')),
                    DropdownMenuItem(value: 'vehicle', child: Text('Vehicle')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedType = v ?? 'bag'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weightCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Max Weight (lbs)',
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    hintText: 'e.g., 15.0',
                    hintStyle: TextStyle(color: Color(0xFF475569)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6366F1)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    hintText: 'How many of this container?',
                    hintStyle: TextStyle(color: Color(0xFF475569)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6366F1)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6366F1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final weightLbs = double.tryParse(weightCtrl.text.trim());
                if (name.isEmpty || weightLbs == null || weightLbs <= 0) return;

                final weightGrams = weightLbs * 453.592;
                final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                final desc = descCtrl.text.trim();

                Navigator.pop(context);

                if (existing != null) {
                  await NexusApiService.updateContainer(
                    containerId: existing.id,
                    updates: {
                      'name': name,
                      'container_type': selectedType,
                      'max_weight_grams': weightGrams,
                      'quantity': qty,
                      if (desc.isNotEmpty) 'description': desc,
                    },
                  );
                } else {
                  await NexusApiService.createContainer(
                    containerData: {
                      'name': name,
                      'container_type': selectedType,
                      'max_weight_grams': weightGrams,
                      'quantity': qty,
                      if (desc.isNotEmpty) 'description': desc,
                    },
                  );
                }

                _fetchContainers();
                widget.onContainersChanged?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
              ),
              child: Text(existing != null ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteContainer(StorageContainer container) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Container?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "${container.name}"? This cannot be undone.',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await NexusApiService.deleteContainer(containerId: container.id);
      _fetchContainers();
      widget.onContainersChanged?.call();
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'bag':
        return Icons.backpack_outlined;
      case 'case':
        return Icons.luggage_outlined;
      case 'crate':
        return Icons.inventory_2_outlined;
      case 'drone_payload':
        return Icons.flight_outlined;
      case 'vehicle':
        return Icons.local_shipping_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Storage Containers',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_containers.length} container(s) defined',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showContainerForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _containers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: Color(0xFF334155),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.luggage_outlined,
                              size: 64,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No containers yet',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add your luggage, backpacks, or drone payloads\nto enable smart packing',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _containers.length,
                      itemBuilder: (context, index) {
                        final c = _containers[index];
                        return Card(
                          color: const Color(0xFF1E293B),
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFF334155)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF334155),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getTypeIcon(c.containerType),
                                color: const Color(0xFF6366F1),
                                size: 24,
                              ),
                            ),
                            title: Text(
                              c.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  '${c.weightDisplayLbs} capacity  |  Qty: ${c.quantity}',
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                ),
                                if (c.description != null && c.description!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    c.description!,
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
                              color: const Color(0xFF334155),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showContainerForm(existing: c);
                                } else if (value == 'delete') {
                                  _deleteContainer(c);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit', style: TextStyle(color: Colors.white)),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// NEW: Item Detail Page - Add this at the bottom of main.dart
// Item Detail Page - UPDATED VERSION
// Item Detail Page - UPDATED (no domain duplication)
class ItemDetailPage extends StatelessWidget {
  final Map<String, dynamic> item;

  const ItemDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item['image_url'] as String?;
    final name = item['name'] as String? ?? 'Unknown Item';
    final category = item['category'] as String? ?? item['domain'] as String? ?? 'Uncategorized';
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Item Details',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (imageUrl != null && imageUrl.isNotEmpty)
              Container(
                width: double.infinity,
                height: 300,
                color: const Color(0xFF334155),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: Color(0xFF64748B),
                      ),
                    );
                  },
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Category Badge (removed domain)
                  _buildBadge(category, const Color(0xFF6366F1)),
                  
                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFF334155)),
                  const SizedBox(height: 24),
                  
                  // Overview (removed domain row)
                  _buildSection('Overview', [
                    _buildDetailRow('Status', item['status']),
                    _buildDetailRow('Quantity', item['quantity']),
                  ]),
                  
                  // Specifications (only show if any field has data)
                  if (_hasSpecifications())
                    ...[
                      const SizedBox(height: 24),
                      _buildSection('Specifications', [
                        _buildDetailRow('Primary Material', item['primary_material']),
                        _buildDetailRow('Weight Estimate', item['weight_estimate']),
                        _buildDetailRow('Thermal Rating', item['thermal_rating']),
                        _buildDetailRow('Water Resistance', item['water_resistance']),
                      ]),
                    ],
                  
                  // Medical (only show if has data)
                  if (item['medical_application'] != null && item['medical_application'].toString().isNotEmpty)
                    ...[
                      const SizedBox(height: 24),
                      _buildSection('Medical', [
                        _buildDetailRow('Medical Application', item['medical_application']),
                      ]),
                    ],
                  
                  // Utility Summary (only show if has data)
                  if (item['utility_summary'] != null && item['utility_summary'].toString().isNotEmpty)
                    ...[
                      const SizedBox(height: 24),
                      _buildSection('Utility Summary', [
                        _buildUtilitySummary(item['utility_summary']),
                      ]),
                    ],
                  
                  // Debug: Show ALL fields
                  const SizedBox(height: 24),
_buildSection('', [
  ...item.entries.where((e) => 
    !['id', 'user_id', 'profile_id', 'image_url', 'created_at', 'updated_at', 'name', 'domain', 'category', 'status', 'quantity', 'utility_summary'].contains(e.key)
  ).map((e) => _buildDetailRow(
    _formatFieldName(e.key), 
    e.value,
  )),
]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasSpecifications() {
    return (item['primary_material'] != null && item['primary_material'].toString().isNotEmpty) ||
           (item['weight_estimate'] != null && item['weight_estimate'].toString().isNotEmpty) ||
           (item['thermal_rating'] != null && item['thermal_rating'].toString().isNotEmpty) ||
           (item['water_resistance'] != null && item['water_resistance'].toString().isNotEmpty);
  }

  String _formatFieldName(String key) {
    return key.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    // Filter out empty widgets
    final nonEmptyChildren = children.where((w) => w is! SizedBox || (w as SizedBox).height != 0).toList();
    
    if (nonEmptyChildren.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...nonEmptyChildren,
      ],
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty || value.toString() == 'null') {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilitySummary(dynamic summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Text(
        summary.toString(),
        style: const TextStyle(
          color: Color(0xFFE2E8F0),
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
}