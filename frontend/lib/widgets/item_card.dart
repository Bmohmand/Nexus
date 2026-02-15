import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/item.dart';
import '../core/constants.dart';

/// Grid card for displaying a ManifestItem in the Vault.
class ItemCard extends StatelessWidget {
  final ManifestItem item;
  final VoidCallback? onTap;

  const ItemCard({super.key, required this.item, this.onTap});

  IconData _domainIcon(AssetDomain domain) {
    switch (domain) {
      case AssetDomain.clothing:
        return Icons.checkroom;
      case AssetDomain.medical:
        return Icons.medical_services;
      case AssetDomain.tech:
        return Icons.devices;
      case AssetDomain.camping:
        return Icons.terrain;
      case AssetDomain.food:
        return Icons.restaurant;
      default:
        return Icons.inventory_2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or placeholder
            Expanded(
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => _placeholder(theme),
                      errorWidget: (_, __, ___) => _placeholder(theme),
                    )
                  : _placeholder(theme),
            ),
            // Metadata
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(_domainIcon(item.domain),
                          size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.category ?? item.domain.label,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.quantity > 1)
                        Text(
                          'x${item.quantity}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          _domainIcon(item.domain),
          size: 40,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
