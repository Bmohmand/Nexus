import 'package:flutter/material.dart';
import '../models/closet_item.dart';
import '../repositories/closet_repository.dart';

class ClosetProvider with ChangeNotifier {
  final ClosetRepository _repository = ClosetRepository();

  List<ClosetItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  ItemCategory? _selectedCategory;

  List<ClosetItem> get items => _selectedCategory == null
      ? _items
      : _items.where((item) => item.category == _selectedCategory).toList();
  
  List<ClosetItem> get allItems => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ItemCategory? get selectedCategory => _selectedCategory;

  // Load all items for user
  Future<void> loadItems(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _items = await _repository.getUserItems(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load items: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new item
  Future<bool> addItem(ClosetItem item) async {
    try {
      final newItem = await _repository.insertItem(item);
      _items.insert(0, newItem); // Add to beginning of list
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add item: $e';
      notifyListeners();
      return false;
    }
  }

  // Update existing item
  Future<bool> updateItem(ClosetItem item) async {
    try {
      final updatedItem = await _repository.updateItem(item);
      final index = _items.indexWhere((i) => i.id == updatedItem.id);
      if (index != -1) {
        _items[index] = updatedItem;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update item: $e';
      notifyListeners();
      return false;
    }
  }

  // Delete item
  Future<bool> deleteItem(String itemId) async {
    try {
      await _repository.deleteItem(itemId);
      _items.removeWhere((item) => item.id == itemId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete item: $e';
      notifyListeners();
      return false;
    }
  }

  // Filter by category
  void filterByCategory(ItemCategory? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // Get items by category
  List<ClosetItem> getItemsByCategory(ItemCategory category) {
    return _items.where((item) => item.category == category).toList();
  }

  // Get unworn items
  Future<List<ClosetItem>> getUnwornItems(String userId, int days) async {
    try {
      return await _repository.getUnwornItems(userId, days);
    } catch (e) {
      _errorMessage = 'Failed to fetch unworn items: $e';
      notifyListeners();
      return [];
    }
  }

  // Get items by warmth rating
  Future<List<ClosetItem>> getItemsByWarmth(
    String userId,
    int minWarmth,
    int maxWarmth,
  ) async {
    try {
      return await _repository.getItemsByWarmth(userId, minWarmth, maxWarmth);
    } catch (e) {
      _errorMessage = 'Failed to fetch items by warmth: $e';
      notifyListeners();
      return [];
    }
  }

  // Update last worn date
  Future<void> updateLastWorn(String itemId, DateTime date) async {
    try {
      await _repository.updateLastWorn(itemId, date);
      final index = _items.indexWhere((item) => item.id == itemId);
      if (index != -1) {
        _items[index] = _items[index].copyWith(lastWorn: date);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to update last worn: $e';
      notifyListeners();
    }
  }

  // Clear all items (for logout)
  void clear() {
    _items = [];
    _selectedCategory = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
