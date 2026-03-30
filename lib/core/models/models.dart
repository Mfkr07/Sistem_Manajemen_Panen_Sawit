import 'package:uuid/uuid.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String role; // 'admin' or 'stakeholder'

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'stakeholder',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'role': role,
  };
}

class LandModel {
  final String id;
  final String name;
  final double sizeHectares;
  final String stakeholderId;
  final DateTime? createdAt;

  LandModel({
    String? id,
    required this.name,
    required this.sizeHectares,
    required this.stakeholderId,
    this.createdAt,
  }) : id = id ?? const Uuid().v4();

  factory LandModel.fromJson(Map<String, dynamic> json) {
    return LandModel(
      id: json['id'],
      name: json['name'] ?? '',
      sizeHectares: double.parse(json['size_hectares'].toString()),
      stakeholderId: json['stakeholder_id'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size_hectares': sizeHectares,
    'stakeholder_id': stakeholderId,
  };
}

class HarvestModel {
  final String id;
  final String landId;
  final String? landName; // For display purposes only (joined from lands table or cache)
  final double weightKg;
  final DateTime harvestDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus; // 'synced' or 'pending' — local only, never sent to server

  HarvestModel({
    String? id,
    required this.landId,
    this.landName,
    required this.weightKg,
    required this.harvestDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 'pending',
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory HarvestModel.fromJson(Map<String, dynamic> json) {
    return HarvestModel(
      id: json['id'],
      landId: json['land_id'] ?? '',
      landName: json['land_name'] ?? json['lands']?['name'],
      weightKg: double.parse(json['weight_kg'].toString()),
      harvestDate: DateTime.parse(json['harvest_date']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      syncStatus: json['sync_status'] ?? 'synced',
    );
  }

  /// Full JSON including sync_status — for local storage only
  Map<String, dynamic> toJson() => {
    'id': id,
    'land_id': landId,
    'land_name': landName,
    'weight_kg': weightKg,
    'harvest_date': harvestDate.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'sync_status': syncStatus,
  };

  /// JSON for Supabase server — excludes sync_status and land_name
  Map<String, dynamic> toServerJson() {
    return {
      'id': id,
      'land_id': landId,
      'weight_kg': weightKg,
      'harvest_date': harvestDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  HarvestModel copyWith({
    String? id,
    String? landId,
    String? landName,
    double? weightKg,
    DateTime? harvestDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return HarvestModel(
      id: id ?? this.id,
      landId: landId ?? this.landId,
      landName: landName ?? this.landName,
      weightKg: weightKg ?? this.weightKg,
      harvestDate: harvestDate ?? this.harvestDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
