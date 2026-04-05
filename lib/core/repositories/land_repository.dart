import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../database/local_db.dart';

final landRepositoryProvider = Provider((ref) => LandRepository());

class LandRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all lands (for admin)
  Future<List<LandModel>> getAllLands() async {
    try {
      final response = await _supabase
          .from('lands')
          .select()
          .order('name');
      final lands = response.map<LandModel>((e) => LandModel.fromJson(e)).toList();
      // Cache for offline use
      await LocalDatabase.instance.cacheLands(lands);
      return lands;
    } catch (e) {
      // Fallback to cached data
      return await LocalDatabase.instance.getCachedLands();
    }
  }

  /// Get lands by stakeholder ID
  Future<List<LandModel>> getLandsByStakeholder(String stakeholderId) async {
    try {
      final response = await _supabase
          .from('lands')
          .select()
          .eq('stakeholder_id', stakeholderId)
          .order('name');
      return response.map<LandModel>((e) => LandModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Add a new land
  Future<void> addLand(LandModel land) async {
    await _supabase.from('lands').insert(land.toJson());
  }

  /// Delete a land
  Future<void> deleteLand(String id) async {
    await _supabase.from('lands').delete().eq('id', id);
  }

  /// Update a land
  Future<void> updateLand(String id, {String? name, double? sizeHectares, String? stakeholderId}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (sizeHectares != null) updates['size_hectares'] = sizeHectares;
    if (stakeholderId != null) updates['stakeholder_id'] = stakeholderId;
    if (updates.isEmpty) return;
    await _supabase.from('lands').update(updates).eq('id', id);
  }

  /// Get all stakeholders (for admin to assign lands)
  Future<List<UserModel>> getAllStakeholders() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('role', 'stakeholder')
          .order('name');
      return response.map<UserModel>((e) => UserModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // ==========================================
  // USER / ACCOUNT MANAGEMENT (Admin only)
  // ==========================================

  /// Get all users (admin + stakeholder)
  Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .order('role')
          .order('name');
      return response.map<UserModel>((e) => UserModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Update user profile (name, role)
  Future<void> updateUser(String userId, {String? name, String? role}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (role != null) updates['role'] = role;
    if (updates.isEmpty) return;

    await _supabase.from('users').update(updates).eq('id', userId);
  }

  /// Delete user from users table
  Future<void> deleteUser(String userId) async {
    await _supabase.from('users').delete().eq('id', userId);
  }
}
