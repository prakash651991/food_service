import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  User? _user;
  Map<String, dynamic>? _profile;

  AuthProvider() {
    _init();
  }

  User? get user => _user;
  Map<String, dynamic>? get profile => _profile;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _profile?['role'] == 'admin' || _profile?['role'] == 'super_admin';

  Future<void> _init() async {
    _supabase.auth.onAuthStateChange.listen((data) async {
      _user = data.session?.user;
      if (_user != null) {
        await fetchProfile();
      } else {
        _profile = null;
      }
      notifyListeners();
    });
  }

  Future<void> fetchProfile() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;
    _user = currentUser; // Ensure local _user is up to date immediately.
    
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', currentUser.id)
          .maybeSingle();
      _profile = data;
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
  }

  Future<void> updateProfile({String? address, String? landmark}) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;
    
    final updates = <String, dynamic>{};
    if (address != null) updates['address'] = address;
    if (landmark != null) updates['landmark'] = landmark;
    
    if (updates.isEmpty) return;
    
    try {
      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', currentUser.id);
      await fetchProfile(); // Refresh profile data after update
    } catch (e) {
      debugPrint("Error updating profile: $e");
      rethrow;
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String address,
    required String landmark,
    required String pincode,
    required String area,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone': phone,
        'address': address,
        'landmark': landmark,
        'pincode': pincode,
        'area': area,
      },
    );
    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
