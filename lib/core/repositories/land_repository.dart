import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../database/local_db.dart';
import '../services/supabase_admin_service.dart';

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

  /// Delete a land and its associated image
  Future<void> deleteLand(String id) async {
    // Attempt to delete image from storage first
    try {
      await deleteLandImage(id);
    } catch (e) {
      debugPrint('Failed to delete land image: $e');
    }
    await _supabase.from('lands').delete().eq('id', id);
  }

  /// Delete land image from storage
  Future<void> deleteLandImage(String landId) async {
    final path = '$landId/image.jpg';
    await _supabase.storage.from('lands').remove([path]);
  }

  /// Update a land
  Future<void> updateLand(String id, {String? name, double? sizeHectares, int? treeCount, String? stakeholderId, String? imageUrl}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (sizeHectares != null) updates['size_hectares'] = sizeHectares;
    if (treeCount != null) updates['tree_count'] = treeCount;
    if (stakeholderId != null) updates['stakeholder_id'] = stakeholderId;
    if (imageUrl != null) updates['image_url'] = imageUrl;

    if (imageUrl == '') {
      // If imageUrl is empty string, it means the photo was removed
      try {
        await deleteLandImage(id);
      } catch (e) {
        debugPrint('Failed to delete old image when removing photo: $e');
      }
    }
    
    if (updates.isEmpty) return;
    await _supabase.from('lands').update(updates).eq('id', id);
  }

  /// Upload land image to Supabase Storage and return the public URL
  Future<String?> uploadLandImage(String landId, String filePath, List<int> imageBytes, String extension) async {
    try {
      final fileName = '${landId}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final storagePath = 'covers/$fileName';
      // Upload using bytes for cross-platform compatibility
      await _supabase.storage.from('land_images').uploadBinary(storagePath, Uint8List.fromList(imageBytes));
      return _supabase.storage.from('land_images').getPublicUrl(storagePath);
    } catch (e) {
      return null;
    }
  }

  // ==========================================
  // LAND FINANCES OPERATIONS
  // ==========================================

  /// Get specific land finances from server
  Future<List<LandFinanceModel>> getLandFinances(String landId) async {
    try {
      final response = await _supabase
          .from('land_finances')
          .select()
          .eq('land_id', landId)
          .order('period_year', ascending: false)
          .order('period_month', ascending: false);
      return response.map<LandFinanceModel>((e) => LandFinanceModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get specific land finance by month/year from local or server
  Future<LandFinanceModel?> getLandFinanceByMonth(String landId, int month, int year) async {
    try {
      final response = await _supabase
          .from('land_finances')
          .select()
          .eq('land_id', landId)
          .eq('period_month', month)
          .eq('period_year', year)
          .maybeSingle();
      if (response != null) return LandFinanceModel.fromJson(response);
    } catch (e) {
      // Ignored
    }
    // Check locally if server failed or not found online
    final locals = await LocalDatabase.instance.getAllFinances();
    try {
      return locals.firstWhere((l) => l.landId == landId && l.periodMonth == month && l.periodYear == year);
    } catch (_) {
      return null;
    }
  }

  /// Sync all pending local finances to Supabase server
  Future<int> syncPendingFinances() async {
    final pending = await LocalDatabase.instance.getPendingFinances();
    int syncedCount = 0;
    
    for (final fin in pending) {
      try {
        final payload = fin.toServerJson();
        // UPSERT using conflict on land_id, period_month, period_year
        await _supabase.from('land_finances').upsert(
            payload, onConflict: 'land_id, period_month, period_year');
        await LocalDatabase.instance.markFinanceAsSynced(fin.id);
        syncedCount++;
      } catch (e) {
        debugPrint('Gagal sinkron data margin ${fin.id}: $e');
      }
    }
    return syncedCount;
  }

  /// Get all finances locally (admin)
  Future<List<LandFinanceModel>> getAllFinancesLocally() async {
     return await LocalDatabase.instance.getAllFinances();
  }

  /// Get all finances from server (admin)
  Future<List<LandFinanceModel>> getAllFinancesFromServer() async {
    try {
      final response = await _supabase
          .from('land_finances')
          .select()
          .order('period_year', ascending: false)
          .order('period_month', ascending: false);
      
      final data = response.map<LandFinanceModel>((e) => LandFinanceModel.fromJson(e)).toList();
      // Cache it
      for (var f in data) {
         await LocalDatabase.instance.insertFinance(f.copyWith(syncStatus: 'synced'));
      }
      return data;
    } catch (e) {
      return await getAllFinancesLocally();
    }
  }

  /// Save a finance record locally (marked pending) and trigger sync later
  Future<void> upsertFinance(LandFinanceModel finance) async {
    final pendingFinance = finance.copyWith(syncStatus: 'pending');
    await LocalDatabase.instance.insertFinance(pendingFinance);
    // Optionally trigger sync right away if online
    syncPendingFinances().catchError((e) {
      debugPrint('Auto-sync finances failed (non-blocking): $e');
      return 0;
    });
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
    // We should delete from auth.users via admin API to completely wipe the user
    try {
      await SupabaseAdminService.adminClient.auth.admin.deleteUser(userId);
    } catch (e) {
      debugPrint('Admin delete user failed, fallback to public table delete: $e');
      await _supabase.from('users').delete().eq('id', userId);
    }
  }

  /// Create a new user (Admin ONLY)
  Future<void> createUserByAdmin(String email, String password, String name, String role) async {
    // 1. Create auth user bypassing email confirmation using Service Role Key
    final adminAuth = SupabaseAdminService.adminClient.auth.admin;
    final res = await adminAuth.createUser(
      AdminUserAttributes(
        email: email,
        password: password,
        emailConfirm: true, // Auto confirm
        userMetadata: {
          'name': name,
          'role': role,
        },
      ),
    );

    // Note: Since Supabase sometimes does not have the trigger `handle_new_user` 
    // we explicitly upsert into the public `users` table to ensure the user exists.
    if (res.user != null) {
      try {
        await _supabase.from('users').upsert({
          'id': res.user!.id,
          'email': email,
          'name': name,
          'role': role,
        });
      } catch (e) {
        debugPrint('Upsert failed, falling back to update: $e');
        await updateUser(res.user!.id, name: name, role: role);
      }
    }
  }
}
