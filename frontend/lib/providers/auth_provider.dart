import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../repositories/profile_repository.dart';
import '../models/profile.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final ProfileRepository _profileRepository = ProfileRepository();

  User? _currentUser;
  Profile? _currentProfile;
  bool _isLoading = false;
  bool _isLoadingProfile = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  Profile? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _initAuth();
  }

  void _initAuth() {
    _currentUser = _authService.currentUser;
    if (_currentUser != null) {
      _loadProfile();
    }

    // Listen to auth state changes
    _authService.authStateChanges.listen((AuthState state) {
      _currentUser = state.session?.user;
      if (_currentUser != null) {
        _loadProfile();
      } else {
        _currentProfile = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadProfile() async {
    if (_currentUser == null || _isLoadingProfile) return;
    
    _isLoadingProfile = true;
    
    try {
      _currentProfile = await _profileRepository.getDefaultProfile(_currentUser!.id);
      
      // If no profile exists, create one (only if still null after check)
      if (_currentProfile == null) {
        final newProfile = Profile(
          id: '',
          userId: _currentUser!.id,
          name: _currentUser!.email?.split('@')[0] ?? 'User',
          isChild: false,
          clothingSizePreferences: {},
          createdAt: DateTime.now(),
        );
        
        try {
          _currentProfile = await _profileRepository.createProfile(newProfile);
        } catch (e) {
          // If creation fails (likely duplicate), try to fetch again
          if (e.toString().contains('duplicate') || e.toString().contains('unique')) {
            _currentProfile = await _profileRepository.getDefaultProfile(_currentUser!.id);
          } else {
            rethrow;
          }
        }
      }
      
      _isLoadingProfile = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load profile: $e';
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.signUp(
        email: email,
        password: password,
        name: name,
      );

      if (response.user != null) {
        _currentUser = response.user;
        // Don't await - let auth state listener handle profile creation
        // This prevents duplicate creation from signup and listener
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.signIn(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _currentUser = response.user;
        // Auth state listener will handle profile loading
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _currentUser = null;
      _currentProfile = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to sign out: $e';
      notifyListeners();
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is AuthException) {
      return error.message;
    }
    return error.toString();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

/// Singleton auth service.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Stream of auth state changes.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.onAuthStateChange;
});

/// Current user (nullable).
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(data: (state) => state.session?.user);
});
