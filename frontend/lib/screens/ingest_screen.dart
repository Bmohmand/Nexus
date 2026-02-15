import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../providers/items_provider.dart';
import '../providers/search_provider.dart';
import '../services/api_client.dart';

/// Ingest screen: capture or pick an image, upload to Supabase Storage,
/// then send to the FastAPI pipeline for AI context extraction + embedding.
class IngestScreen extends ConsumerStatefulWidget {
  const IngestScreen({super.key});

  @override
  ConsumerState<IngestScreen> createState() => _IngestScreenState();
}

class _IngestScreenState extends ConsumerState<IngestScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _fileName;
  bool _isProcessing = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _fileName = file.name;
        _result = null;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Failed to pick image: $e');
    }
  }

  Future<void> _processImage() async {
    if (_imageBytes == null) return;
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      // Step 1: Upload to Supabase Storage
      final supabase = ref.read(supabaseServiceProvider);
      final uniqueName =
          '${DateTime.now().millisecondsSinceEpoch}_$_fileName';
      final imageUrl = await supabase.uploadImage(uniqueName, _imageBytes!);

      // Step 2: Send URL to FastAPI for AI processing
      final apiClient = ref.read(apiClientProvider);
      final result = await apiClient.ingestByUrl(imageUrl: imageUrl);

      setState(() {
        _result = result;
        _isProcessing = false;
      });

      // Invalidate the items list so it refreshes
      ref.invalidate(itemsProvider);
    } catch (e) {
      String message = 'Processing failed: $e';
      if (e is StorageException &&
          (e.message.contains('Bucket not found') || e.message.contains('404'))) {
        message =
            "Storage bucket '$kStorageBucketName' not found. Create it in Supabase: "
            "Dashboard → Storage → New bucket. Name: $kStorageBucketName. Set to Public.";
      } else if (e is DioException &&
          (e.type == DioExceptionType.connectionError ||
              e.message?.contains('connection error') == true ||
              e.message?.contains('XMLHttpRequest') == true)) {
        message =
            "Cannot reach the AI server. Start the FastAPI backend (e.g. uvicorn server.main:app --reload --port 8000 from the backend folder). "
            "If it runs on another host/port, set API_BASE_URL in .env (e.g. API_BASE_URL=http://192.168.1.10:8000).";
      }
      setState(() {
        _error = message;
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Item')),
      body: _result != null
          ? _buildResultView(theme)
          : _imageBytes != null
              ? _buildPreviewView(theme)
              : _buildPickerView(theme),
    );
  }

  Widget _buildPickerView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo,
              size: 80, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text('Add to your Vault',
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Take a photo or upload from gallery'),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Choose from Gallery'),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewView(ThemeData theme) {
    return Column(
      children: [
        // Image preview
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            color: Colors.black,
            child: Image.memory(_imageBytes!, fit: BoxFit.contain),
          ),
        ),
        // Action bar
        Expanded(
          flex: 1,
          child: Center(
            child: _isProcessing
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('AI is analyzing your item...'),
                    ],
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _processImage,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Analyze & Add to Vault'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() {
                            _imageBytes = null;
                            _fileName = null;
                          }),
                          child: const Text('Choose Different Image'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!,
                              style: TextStyle(
                                  color: theme.colorScheme.error)),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Image preview (smaller)
        if (_imageBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_imageBytes!,
                height: 200, fit: BoxFit.cover, width: double.infinity),
          ),
        const SizedBox(height: 16),

        // AI Detection Results
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
                    Text('AI Detection Complete',
                        style: theme.textTheme.titleMedium),
                  ],
                ),
                const Divider(height: 24),
                _attr('Name', _result?['name']),
                _attr('Domain', _result?['domain']),
                _attr('Category', _result?['category']),
                _attr('Utility', _result?['utility_summary']),
                if (_result?['semantic_tags'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: (_result!['semantic_tags'] as List)
                          .map((t) => Chip(
                                label: Text(t.toString(),
                                    style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/vault');
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Item added to vault!')),
              );
            },
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Widget _attr(String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              value.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
