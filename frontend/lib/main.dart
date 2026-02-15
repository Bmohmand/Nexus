import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'api_service.dart';
import 'models/storage_container.dart';

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
      message = '⚠️ Supabase: ✅ | Backend: ❌ (Update URL in api_service.dart)';
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
                    'Backend: ${backendOk ? "Connected" : "Update URL in api_service.dart"}',
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
      floatingActionButton: _buildFAB(),
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
        title: const Text(
          'Search Results',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: results.length,
            itemBuilder: (context, index) {
              final item = results[index];
              return Card(
                color: const Color(0xFF334155),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Color(0xFF10B981)),
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


// Items Grid View
class ItemsGridView extends StatelessWidget {
  const ItemsGridView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Collection',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '48 items indexed',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
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
        ),
        Expanded(
          child: _buildItemsGrid(),
        ),
      ],
    );
  }

  Widget _buildItemsGrid() {
    // Sample data - replace with actual API data
    final items = List.generate(
      12,
      (index) => {
        'name': _getItemName(index),
        'category': _getCategory(index),
        'similarity': (85 + (index * 2)) % 100,
      },
    );

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildItemCard(item);
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Container(
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
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Icon(
                  _getCategoryIcon(item['category'] as String),
                  size: 48,
                  color: const Color(0xFF6366F1),
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
                  item['name'] as String,
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
                        item['category'] as String,
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
    );
  }

  String _getItemName(int index) {
    final names = [
      'Wool Trench Coat',
      'First Aid Kit',
      'LED Flashlight',
      'Thermal Blanket',
      'Gore-Tex Jacket',
      'Antibiotics',
      'Camp Stove',
      'Water Filter',
      'Trauma Kit',
      'Sleeping Bag',
      'Gauze Pack',
      'Multi-tool',
    ];
    return names[index % names.length];
  }

  String _getCategory(int index) {
    final categories = [
      'Clothing',
      'Medical',
      'Survival',
      'Medical',
      'Clothing',
      'Medical',
      'Survival',
      'Survival',
      'Medical',
      'Survival',
      'Medical',
      'Survival',
    ];
    return categories[index % categories.length];
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Clothing':
        return Icons.checkroom;
      case 'Medical':
        return Icons.medical_services_outlined;
      case 'Survival':
        return Icons.outdoor_grill_outlined;
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
  imageUrl: imageUrl,  // Changed from imagePath to imageUrl
  userId: 'demo_user',
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
class GraphVisualizationView extends StatelessWidget {
  const GraphVisualizationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Semantic Graph',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Vector space visualization',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF334155),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.scatter_plot,
                            size: 64,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '3D Force Graph',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Items cluster by semantic similarity',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Legend
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 15, 23, 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 6,
                                backgroundColor: Color(0xFF6366F1),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Clothing',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 6,
                                backgroundColor: Color(0xFFEF4444),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Medical',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 6,
                                backgroundColor: Color(0xFF10B981),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Survival',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 30, 41, 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF6366F1), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Distance between nodes represents cosine similarity in vector space',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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