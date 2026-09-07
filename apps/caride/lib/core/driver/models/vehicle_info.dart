import 'package:cloud_firestore/cloud_firestore.dart';

import '../verification/driver_verification_config.dart';

class VehicleInfo {
  const VehicleInfo({
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.plateNumber,
    required this.vehicleType,
    required this.seatCount,
    this.vehiclePhotoUrl = '',
  });

  final String make;
  final String model;
  final int year;
  final String color;
  final String plateNumber;
  /// 'regular' | 'comfort' | 'luxury' | 'courier'
  final String vehicleType;
  final int seatCount;
  final String vehiclePhotoUrl;

  String get displayName => '$year $make $model';

  factory VehicleInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return VehicleInfo.fromMap(doc.data() ?? {});
  }

  factory VehicleInfo.fromMap(Map<String, dynamic> data) {
    return VehicleInfo(
      make: (data['make'] as String?) ?? '',
      model: (data['model'] as String?) ?? '',
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      color: (data['color'] as String?) ?? '',
      plateNumber: (data['plateNumber'] as String?) ?? '',
      vehicleType: normalizeVehicleType(data['vehicleType'] as String?),
      seatCount:
          (data['seatCount'] as num?)?.toInt() ??
          seatCountForVehicleType(data['vehicleType'] as String?),
      vehiclePhotoUrl: (data['vehiclePhotoUrl'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'plateNumber': plateNumber,
      'vehicleType': vehicleType,
      'seatCount': seatCount,
      'vehiclePhotoUrl': vehiclePhotoUrl,
    };
  }
}
