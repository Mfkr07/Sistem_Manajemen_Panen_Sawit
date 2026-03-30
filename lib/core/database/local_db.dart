import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static const String _storageKey = 'offline_harvests';
  static const String _landsKey = 'cached_lands';

  LocalDatabase._init();

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  // ==================== HARVEST OPERATIONS ====================

  Future<void> insertHarvest(HarvestModel harvest) async {
    final harvests = await getAllHarvests();
    final index = harvests.indexWhere((h) => h.id == harvest.id);
    if (index >= 0) {
      harvests[index] = harvest;
    } else {
      harvests.add(harvest);
    }
    await _saveHarvests(harvests);
  }

  Future<void> updateHarvest(HarvestModel harvest) async {
    await insertHarvest(harvest); // Upsert logic
  }

  Future<void> deleteHarvest(String id) async {
    final harvests = await getAllHarvests();
    harvests.removeWhere((h) => h.id == id);
    await _saveHarvests(harvests);
  }

  Future<HarvestModel?> getHarvestById(String id) async {
    final harvests = await getAllHarvests();
    try {
      return harvests.firstWhere((h) => h.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<HarvestModel>> getPendingHarvests() async {
    final harvests = await getAllHarvests();
    return harvests.where((h) => h.syncStatus == 'pending').toList();
  }
  
  Future<List<HarvestModel>> getAllHarvests() async {
    final prefs = await _prefs;
    final String? jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return [];
    
    final List<dynamic> decoded = jsonDecode(jsonString);
    final data = decoded.map((json) => HarvestModel.fromJson(json)).toList();
    data.sort((a, b) => b.harvestDate.compareTo(a.harvestDate));
    return data;
  }

  Future<void> markAsSynced(String id) async {
    final harvests = await getAllHarvests();
    final index = harvests.indexWhere((h) => h.id == id);
    if (index >= 0) {
      harvests[index] = harvests[index].copyWith(syncStatus: 'synced');
      await _saveHarvests(harvests);
    }
  }

  Future<void> clearDatabase() async {
    final prefs = await _prefs;
    await prefs.remove(_storageKey);
  }

  Future<void> _saveHarvests(List<HarvestModel> harvests) async {
    final prefs = await _prefs;
    final jsonString = jsonEncode(harvests.map((h) => h.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  // ==================== LANDS CACHE ====================

  Future<void> cacheLands(List<LandModel> lands) async {
    final prefs = await _prefs;
    final jsonString = jsonEncode(lands.map((l) => l.toJson()).toList());
    await prefs.setString(_landsKey, jsonString);
  }

  Future<List<LandModel>> getCachedLands() async {
    final prefs = await _prefs;
    final String? jsonString = prefs.getString(_landsKey);
    if (jsonString == null) return [];

    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.map((json) => LandModel.fromJson(json)).toList();
  }
}
