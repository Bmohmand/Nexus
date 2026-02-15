import 'package:flutter/material.dart';

/// Live packing scan screen — point camera at items, AI evaluates in real time.
/// Placeholder: camera integration requires platform-specific setup.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _itemScanned = false;
  bool _itemAccepted = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Scan'),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, size: 80, color: Colors.white54),
                    SizedBox(height: 16),
                    Text(
                      'Point camera at an item',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Scan result overlay
          if (_itemScanned)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _itemAccepted ? Colors.green[900] : Colors.red[900],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(
                      _itemAccepted ? Icons.check_circle : Icons.cancel,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _itemAccepted ? 'ACCEPTED' : 'REJECTED',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _itemAccepted
                          ? 'Improves mission readiness'
                          : 'Redundant — already covered',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // Scan button
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.large(
                heroTag: 'scan_fab',
                onPressed: () {
                  setState(() {
                    _itemScanned = true;
                    _itemAccepted = !_itemAccepted;
                  });
                  Future.delayed(const Duration(seconds: 3), () {
                    if (mounted) {
                      setState(() => _itemScanned = false);
                    }
                  });
                },
                backgroundColor: Colors.white,
                child:
                    const Icon(Icons.camera, size: 32, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
