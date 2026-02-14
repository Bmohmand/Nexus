import 'package:flutter/material.dart';
import '../core/constants.dart';

/// Horizontal scrollable list of domain filter chips.
class DomainFilterChips extends StatelessWidget {
  final AssetDomain? selected;
  final ValueChanged<AssetDomain?> onSelected;

  const DomainFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  static const _displayDomains = [
    null, // "All"
    AssetDomain.clothing,
    AssetDomain.medical,
    AssetDomain.tech,
    AssetDomain.camping,
    AssetDomain.food,
    AssetDomain.misc,
  ];

  IconData _icon(AssetDomain? domain) {
    if (domain == null) return Icons.apps;
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
      case AssetDomain.misc:
        return Icons.category;
      default:
        return Icons.inventory_2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _displayDomains.map((domain) {
          final isSelected = selected == domain;
          final label = domain?.label ?? 'All';
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(_icon(domain), size: 16),
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => onSelected(domain),
            ),
          );
        }).toList(),
      ),
    );
  }
}
