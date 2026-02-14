import 'package:flutter/material.dart';

void main() {
  runApp(const ClosetAIApp());
}

class ClosetAIApp extends StatelessWidget {
  const ClosetAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitCheck',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Main Navigation with Bottom Nav Bar
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ClosetLibraryScreen(),
    const OutfitGeneratorScreen(),
    const PackingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.checkroom_outlined),
            selectedIcon: Icon(Icons.checkroom),
            label: 'Closet',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Outfits',
          ),
          NavigationDestination(
            icon: Icon(Icons.luggage_outlined),
            selectedIcon: Icon(Icons.luggage),
            label: 'Packing',
          ),
        ],
      ),
    );
  }
}

// HOME SCREEN
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FitCheck'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ClosetHealthScreen(),
                ),
              );
            },
            tooltip: 'Closet Health',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick Actions Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _QuickActionButton(
                        icon: Icons.camera_alt,
                        label: 'Add Item',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CameraUploadScreen(),
                            ),
                          );
                        },
                      ),
                      _QuickActionButton(
                        icon: Icons.auto_awesome,
                        label: 'Generate',
                        onTap: () {},
                      ),
                      _QuickActionButton(
                        icon: Icons.luggage,
                        label: 'Pack',
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Recent Outfits
          Text(
            'Recent Outfits',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (context, index) {
                return const _OutfitPreviewCard();
              },
            ),
          ),
          const SizedBox(height: 16),

          // Stats Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Closet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(label: 'Items', value: '42'),
                      _StatItem(label: 'Outfits', value: '18'),
                      _StatItem(label: 'Unworn', value: '3'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// CLOSET LIBRARY SCREEN
class ClosetLibraryScreen extends StatefulWidget {
  const ClosetLibraryScreen({super.key});

  @override
  State<ClosetLibraryScreen> createState() => _ClosetLibraryScreenState();
}

class _ClosetLibraryScreenState extends State<ClosetLibraryScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Closet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterBottomSheet(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('All'),
                _buildFilterChip('Tops'),
                _buildFilterChip('Bottoms'),
                _buildFilterChip('Outerwear'),
                _buildFilterChip('Shoes'),
              ],
            ),
          ),

          // Grid of clothing items
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: 8, // Placeholder count
              itemBuilder: (context, index) {
                return const _ClothingItemCard();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CameraUploadScreen(),
            ),
          );
        },
        icon: const Icon(Icons.camera_alt),
        label: const Text('Add Item'),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = label;
          });
        },
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Options',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.wb_sunny),
                title: const Text('By Season'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('By Color'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Recently Worn'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber),
                title: const Text('Not Worn in 90 Days'),
                onTap: () {},
              ),
            ],
          ),
        );
      },
    );
  }
}

// OUTFIT GENERATOR SCREEN
class OutfitGeneratorScreen extends StatefulWidget {
  const OutfitGeneratorScreen({super.key});

  @override
  State<OutfitGeneratorScreen> createState() => _OutfitGeneratorScreenState();
}

class _OutfitGeneratorScreenState extends State<OutfitGeneratorScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Outfit'),
      ),
      body: Column(
        children: [
          // Prompt Input
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Describe your occasion',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _promptController,
                      decoration: const InputDecoration(
                        hintText: 'e.g., Date night in SF, 58°F, indoor dinner',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isGenerating ? null : _generateOutfits,
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(_isGenerating ? 'Generating...' : 'Generate Outfits'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Generated Outfits
          Expanded(
            child: _isGenerating
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      _GeneratedOutfitCard(
                        title: 'Outfit Option 1',
                        confidence: 91,
                      ),
                      SizedBox(height: 16),
                      _GeneratedOutfitCard(
                        title: 'Outfit Option 2',
                        confidence: 87,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _generateOutfits() {
    setState(() {
      _isGenerating = true;
    });

    // Simulate API call
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isGenerating = false;
      });
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }
}

// PACKING SCREEN
class PackingScreen extends StatefulWidget {
  const PackingScreen({super.key});

  @override
  State<PackingScreen> createState() => _PackingScreenState();
}

class _PackingScreenState extends State<PackingScreen> {
  final TextEditingController _destinationController = TextEditingController();
  bool _showResults = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Packing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LivePackingScanScreen(),
                ),
              );
            },
            tooltip: 'Live Scan Mode',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Trip Details Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trip Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _destinationController,
                    decoration: const InputDecoration(
                      labelText: 'Destination',
                      hintText: 'e.g., New York',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Duration (days)',
                      hintText: 'e.g., 3',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Temperature Range',
                      hintText: 'e.g., 40-55°F',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.thermostat),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _optimizePacking,
                      icon: const Icon(Icons.lightbulb),
                      label: const Text('Optimize Packing'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_showResults) ...[
            const SizedBox(height: 16),

            // Results Card
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      '12 Unique Outfit Combinations',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _PackingStatChip(label: '8 Items', icon: Icons.checkroom),
                        _PackingStatChip(label: '78% Full', icon: Icons.luggage),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Recommended Items
            Text(
              'Recommended Items',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...List.generate(5, (index) => const _PackingItemCard()),
          ],
        ],
      ),
    );
  }

  void _optimizePacking() {
    setState(() {
      _showResults = true;
    });
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }
}

// CAMERA UPLOAD SCREEN
class CameraUploadScreen extends StatelessWidget {
  const CameraUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Item'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Camera Upload',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Take a photo or upload from gallery',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        // TODO: Implement camera
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ItemTaggingScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Implement gallery picker
                      },
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Choose from Gallery'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ITEM TAGGING SCREEN (After photo capture)
class ItemTaggingScreen extends StatelessWidget {
  const ItemTaggingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
      ),
      body: Column(
        children: [
          // Image Preview
          Container(
            height: 300,
            width: double.infinity,
            color: Colors.grey[300],
            child: const Icon(Icons.image, size: 100),
          ),

          // AI Detection Results
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              'AI Detection Complete',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _AttributeRow(label: 'Category', value: 'Navy Blazer'),
                        _AttributeRow(label: 'Formality', value: '7/10'),
                        _AttributeRow(label: 'Temperature', value: '50-70°F'),
                        _AttributeRow(label: 'Style', value: 'Smart Casual'),
                        _AttributeRow(label: 'Layering', value: 'Yes'),
                        _AttributeRow(label: 'Colors', value: 'Cool tones'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Item added to closet!')),
                      );
                    },
                    child: const Text('Add to Closet'),
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

// CLOSET HEALTH SCREEN
class ClosetHealthScreen extends StatelessWidget {
  const ClosetHealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Closet Health'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sustainability Score',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: 0.75,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '75% - Great job!',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Items Not Worn in 90 Days',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const _UnwornItemCard(
            itemName: 'Grey Cardigan',
            lastWorn: '120 days ago',
            estimatedValue: '\$45',
          ),
          const _UnwornItemCard(
            itemName: 'Black Dress Shoes',
            lastWorn: '95 days ago',
            estimatedValue: '\$80',
          ),
          const _UnwornItemCard(
            itemName: 'White Button-Up',
            lastWorn: '98 days ago',
            estimatedValue: '\$35',
          ),
        ],
      ),
    );
  }
}

// LIVE PACKING SCAN SCREEN
class LivePackingScanScreen extends StatefulWidget {
  const LivePackingScanScreen({super.key});

  @override
  State<LivePackingScanScreen> createState() => _LivePackingScanScreenState();
}

class _LivePackingScanScreenState extends State<LivePackingScanScreen> {
  bool _itemScanned = false;
  bool _itemAccepted = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Packing Scan'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera viewfinder placeholder
          Center(
            child: Container(
              color: Colors.grey[900],
              child: const Center(
                child: Icon(
                  Icons.camera_alt,
                  size: 100,
                  color: Colors.white54,
                ),
              ),
            ),
          ),

          // Scan result overlay
          if (_itemScanned)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _itemAccepted ? Colors.green[900] : Colors.red[900],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Icon(
                      _itemAccepted ? Icons.check_circle : Icons.cancel,
                      size: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _itemAccepted ? '✅ Accepted' : '❌ Rejected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Heavy Wool Sweater',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    if (_itemAccepted)
                      const _ScanMetric(label: 'Compatibility', value: '0.88')
                    else
                      const _ScanMetric(label: 'Redundancy', value: 'High'),
                    const SizedBox(height: 8),
                    Text(
                      _itemAccepted
                          ? 'Improves combination space'
                          : 'Exceeds packing efficiency threshold',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // Scan button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.large(
                onPressed: () {
                  setState(() {
                    _itemScanned = true;
                    _itemAccepted = !_itemAccepted; // Toggle for demo
                  });
                  Future.delayed(const Duration(seconds: 3), () {
                    if (mounted) {
                      setState(() {
                        _itemScanned = false;
                      });
                    }
                  });
                },
                backgroundColor: Colors.white,
                child: const Icon(Icons.camera, size: 32, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// REUSABLE WIDGETS

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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

class _OutfitPreviewCard extends StatelessWidget {
  const _OutfitPreviewCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 12),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Icon(Icons.checkroom, size: 40)),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Date Night', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('2 days ago', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _ClothingItemCard extends StatelessWidget {
  const _ClothingItemCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.checkroom, size: 50)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Navy Blazer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('Worn 5x', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratedOutfitCard extends StatelessWidget {
  final String title;
  final int confidence;

  const _GeneratedOutfitCard({
    required this.title,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Chip(
                  label: Text('$confidence%'),
                  backgroundColor: Colors.green[100],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Outfit items placeholder
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _OutfitItemChip(label: 'Navy Blazer'),
                _OutfitItemChip(label: 'Cream Sweater'),
                _OutfitItemChip(label: 'Dark Jeans'),
                _OutfitItemChip(label: 'Brown Boots'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {},
                child: const Text('Accept Outfit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutfitItemChip extends StatelessWidget {
  final String label;

  const _OutfitItemChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.checkroom, size: 16),
      label: Text(label),
    );
  }
}

class _PackingStatChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _PackingStatChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _PackingItemCard extends StatelessWidget {
  const _PackingItemCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          color: Colors.grey[300],
          child: const Icon(Icons.checkroom),
        ),
        title: const Text('Lightweight Thermal'),
        subtitle: const Text('Compatibility: 0.88 • Low volume'),
        trailing: const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }
}

class _AttributeRow extends StatelessWidget {
  final String label;
  final String value;

  const _AttributeRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _UnwornItemCard extends StatelessWidget {
  final String itemName;
  final String lastWorn;
  final String estimatedValue;

  const _UnwornItemCard({
    required this.itemName,
    required this.lastWorn,
    required this.estimatedValue,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          color: Colors.grey[300],
          child: const Icon(Icons.checkroom),
        ),
        title: Text(itemName),
        subtitle: Text('Last worn: $lastWorn'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              estimatedValue,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('Est. resale', style: TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _ScanMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ScanMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white70),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}