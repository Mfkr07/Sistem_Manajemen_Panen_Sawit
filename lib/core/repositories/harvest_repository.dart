import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../database/local_db.dart';

final harvestRepositoryProvider = Provider((ref) => HarvestRepository());

class HarvestRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Sync all pending local harvests to Supabase server
  Future<int> syncPendingHarvests() async {
    final pendingHarvests = await LocalDatabase.instance.getPendingHarvests();
    int syncedCount = 0;
    
    for (final harvest in pendingHarvests) {
      try {
        final payload = harvest.toServerJson();
        await _supabase.from('harvests').upsert(payload);
        await LocalDatabase.instance.markAsSynced(harvest.id);
        syncedCount++;
      } catch (e) {
        print('Gagal sinkronisasi data ${harvest.id}: $e');
      }
    }
    return syncedCount;
  }

  /// Get all harvests from server (with land name joined)
  Future<List<HarvestModel>> getAllHarvestsFromServer() async {
    try {
      final response = await _supabase
          .from('harvests')
          .select('*, lands(name)')
          .order('harvest_date', ascending: false);
      return response.map<HarvestModel>((e) => HarvestModel.fromJson(e)).toList();
    } catch (e) {
      print('Gagal mengambil data dari server: $e');
      return [];
    }
  }

  /// Get harvests filtered by land IDs (for stakeholder)
  Future<List<HarvestModel>> getHarvestsByLandIds(List<String> landIds) async {
    if (landIds.isEmpty) return [];
    try {
      final response = await _supabase
          .from('harvests')
          .select('*, lands(name)')
          .inFilter('land_id', landIds)
          .order('harvest_date', ascending: false);
      return response.map<HarvestModel>((e) => HarvestModel.fromJson(e)).toList();
    } catch (e) {
      print('Gagal mengambil data panen stakeholder: $e');
      return [];
    }
  }

  /// Stream data from server realtime
  Stream<List<HarvestModel>> streamHarvests(String? specificLandId) {
    if (specificLandId != null) {
      return _supabase.from('harvests').stream(primaryKey: ['id'])
        .eq('land_id', specificLandId)
        .order('harvest_date')
        .map((data) => data.map((e) => HarvestModel.fromJson(e)).toList());
    }
    
    return _supabase.from('harvests').stream(primaryKey: ['id'])
      .order('harvest_date')
      .map((data) => data.map((e) => HarvestModel.fromJson(e)).toList());
  }

  /// Get harvests by date range (for export)
  Future<List<HarvestModel>> getHarvestsByDateRange(
    DateTime start, 
    DateTime end, 
    {String? landId, List<String>? landIds}
  ) async {
    var query = _supabase.from('harvests')
        .select('*, lands(name)')
        .gte('harvest_date', start.toIso8601String())
        .lte('harvest_date', end.toIso8601String());

    if (landId != null) {
      query = query.eq('land_id', landId);
    }
    if (landIds != null && landIds.isNotEmpty) {
      query = query.inFilter('land_id', landIds);
    }
    
    final response = await query.order('harvest_date', ascending: false);
    return response.map<HarvestModel>((e) => HarvestModel.fromJson(e)).toList();
  }
}
