import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'api_service.dart';

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
  double _packMaxWeightKg = 7.0;
  bool _isPacking = false;
  static const List<Map<String, dynamic>> _weightPresets = [
    {'label': '7 kg backpack', 'kg': 7.0},
    {'label': '23 kg checked', 'kg': 23.0},
    {'label': '5 kg drone', 'kg': 5.0},
    {'label': '10 kg daypack', 'kg': 10.0},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _testConnections(); // Test backend and Supabase on startup
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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ..._weightPresets.map((preset) {
                        final kg = (preset['kg'] as num).toDouble();
                        final selected = (_packMaxWeightKg - kg).abs() < 0.1;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(preset['label'] as String),
                            selected: selected,
                            onSelected: (_) => setState(() => _packMaxWeightKg = kg),
                            selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.3),
                            checkmarkColor: const Color(0xFF6366F1),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: (_searchController.text.trim().isEmpty || _isPacking)
                    ? null
                    : () => _performPackRecommendation(),
                icon: _isPacking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.backpack_outlined, size: 20),
                label: const Text('Recommend for my bag'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          if (_isSearching) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 30, 41, 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color.fromRGBO(255, 99, 102, 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI-powered semantic search across all your items',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
    setState(() {
      _isSearching = true;
    });
    
    // Show loading state
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Searching vector space...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Call the actual API
    try {
      final results = await NexusApiService.semanticSearch(
        query: query,
        topK: 15,
      );
      
      if (mounted) {
        Navigator.pop(context);
        
        if (results != null && results.isNotEmpty) {
          // Show results dialog
          _showSearchResults(results);
        } else {
          // Show no results message
          _showNoResultsDialog();
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

  void _performPackRecommendation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isPacking = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Packing for your bag...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final response = await NexusApiService.packRecommendation(
        query: query,
        maxWeightKg: _packMaxWeightKg,
        topK: 50,
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (response != null) {
        _showPackResults(response);
      } else {
        _showErrorDialog('Pack recommendation failed. Check backend.');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorDialog('Pack failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isPacking = false);
    }
  }

  void _showPackResults(Map<String, dynamic> response) {
    final packed = List<Map<String, dynamic>>.from(response['packed_items'] ?? []);
    final totalGrams = (response['total_weight_grams'] as num?)?.toDouble() ?? 0;
    final utilization = (response['weight_utilization'] as num?)?.toDouble() ?? 0;
    final status = response['status'] as String? ?? '';
    final missionSummary = response['mission_summary'] as String?;
    final warnings = List<String>.from(response['warnings'] ?? []);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.backpack, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Pack for your bag', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Chip(
                      label: Text(status),
                      backgroundColor: status == 'optimal'
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : const Color(0xFF6366F1).withValues(alpha: 0.2),
                    ),
                  ),
                Row(
                  children: [
                    Text(
                      '${(totalGrams / 1000).toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(' used ', style: TextStyle(color: Color(0xFF94A3B8))),
                    Text(
                      '(${(utilization * 100).toStringAsFixed(0)}% of ${_packMaxWeightKg} kg)',
                      style: const TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                if (missionSummary != null && missionSummary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      missionSummary,
                      style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
                    ),
                  ),
                ],
                if (warnings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...warnings.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 16),
                        const SizedBox(width: 6),
                        Expanded(child: Text(w, style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12))),
                      ],
                    ),
                  )),
                ],
                const SizedBox(height: 12),
                Text(
                  'Packed items (${packed.length})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...packed.map((item) {
                  final qty = item['quantity'] as int? ?? 1;
                  final w = (item['weight_grams'] as num?)?.toDouble() ?? 0;
                  final score = (item['similarity_score'] as num?)?.toDouble() ?? 0;
                  return Card(
                    color: const Color(0xFF334155),
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                      title: Text(
                        item['name'] ?? 'Item',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${item['category'] ?? ''} · qty $qty · ${(w * qty / 1000).toStringAsFixed(2)} kg',
                        style: const TextStyle(color: Color(0xFF94A3B8)),
                      ),
                      trailing: Text(
                        '${(score * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Color(0xFF6366F1)),
                      ),
                    ),
                  );
                }),
                if (packed.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No items fit within the weight limit.',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
              ],
            ),
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