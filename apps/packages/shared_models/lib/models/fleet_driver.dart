enum FleetDriverStatus {
  invited,
  active,
  suspended,
  removed;

  String get label {
    switch (this) {
      case FleetDriverStatus.invited:
        return 'Invited';
      case FleetDriverStatus.active:
        return 'Active';
      case FleetDriverStatus.suspended:
        return 'Suspended';
      case FleetDriverStatus.removed:
        return 'Removed';
    }
  }

  static FleetDriverStatus fromString(String? val) {
    if (val == null) return FleetDriverStatus.active;
    return FleetDriverStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => FleetDriverStatus.active,
    );
  }
}

class FleetDriver {
  const FleetDriver({
    required this.id,
    this.driverUid = '',
    this.fleetId = '',
    required this.fullName,
    required this.phone,
    this.username,
    this.email = '',
    String? photoUrl,
    String? profilePhotoUrl,
    this.licenseNumber,
    this.status = FleetDriverStatus.active,
    this.assignedVehicleId,
    this.assignedVehicleTitle,
    this.rating = 0.0,
    this.completedTrips = 0,
    this.joinedAt,
  }) : photoUrl = photoUrl ?? profilePhotoUrl;

  final String id;
  final String driverUid;
  final String fleetId;
  final String fullName;
  final String phone;
  final String? username;
  final String email;
  final String? photoUrl;
  final String? licenseNumber;
  final FleetDriverStatus status;
  final String? assignedVehicleId;
  final String? assignedVehicleTitle;
  final double rating;
  final int completedTrips;
  final DateTime? joinedAt;

  String? get profilePhotoUrl => photoUrl;

  bool get isActive => status == FleetDriverStatus.active;

  FleetDriver copyWith({
    String? id,
    String? driverUid,
    String? fleetId,
    String? fullName,
    String? phone,
    String? username,
    String? email,
    String? photoUrl,
    String? licenseNumber,
    FleetDriverStatus? status,
    String? assignedVehicleId,
    String? assignedVehicleTitle,
    double? rating,
    int? completedTrips,
    DateTime? joinedAt,
  }) {
    return FleetDriver(
      id: id ?? this.id,
      driverUid: driverUid ?? this.driverUid,
      fleetId: fleetId ?? this.fleetId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      username: username ?? this.username,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      status: status ?? this.status,
      assignedVehicleId: assignedVehicleId ?? this.assignedVehicleId,
      assignedVehicleTitle: assignedVehicleTitle ?? this.assignedVehicleTitle,
      rating: rating ?? this.rating,
      completedTrips: completedTrips ?? this.completedTrips,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'driverUid': driverUid,
      'fleetId': fleetId,
      'fullName': fullName,
      'phone': phone,
      'username': username,
      'email': email,
      'photoUrl': photoUrl,
      'licenseNumber': licenseNumber,
      'status': status.name,
      'assignedVehicleId': assignedVehicleId,
      'assignedVehicleTitle': assignedVehicleTitle,
      'rating': rating,
      'completedTrips': completedTrips,
      'joinedAt': joinedAt?.toIso8601String(),
    };
  }

  factory FleetDriver.fromMap(Map<String, dynamic> map, [String? docId]) {
    return FleetDriver(
      id: docId ?? map['id'] as String? ?? '',
      driverUid: map['driverUid'] as String? ?? '',
      fleetId: map['fleetId'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      username: map['username'] as String?,
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      licenseNumber: map['licenseNumber'] as String?,
      status: FleetDriverStatus.fromString(map['status'] as String?),
      assignedVehicleId: map['assignedVehicleId'] as String?,
      assignedVehicleTitle: map['assignedVehicleTitle'] as String?,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      completedTrips: (map['completedTrips'] as num?)?.toInt() ?? 0,
      joinedAt: map['joinedAt'] != null
          ? DateTime.tryParse(map['joinedAt'].toString())
          : null,
    );
  }
}
