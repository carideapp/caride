enum RentalVehicleCategory {
  sedan,
  suv,
  luxury,
  bus,
  van,
  truck,
  convertible;

  String get label {
    switch (this) {
      case RentalVehicleCategory.sedan:
        return 'Sedan';
      case RentalVehicleCategory.suv:
        return 'SUV';
      case RentalVehicleCategory.luxury:
        return 'Luxury / VIP';
      case RentalVehicleCategory.bus:
        return 'Bus';
      case RentalVehicleCategory.van:
        return 'Van / Minivan';
      case RentalVehicleCategory.truck:
        return 'Truck';
      case RentalVehicleCategory.convertible:
        return 'Convertible';
    }
  }

  static RentalVehicleCategory fromString(String? val) {
    if (val == null) return RentalVehicleCategory.sedan;
    return RentalVehicleCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => RentalVehicleCategory.sedan,
    );
  }
}

enum RentalVehicleStatus {
  available,
  rented,
  maintenance,
  inactive;

  String get label {
    switch (this) {
      case RentalVehicleStatus.available:
        return 'Available';
      case RentalVehicleStatus.rented:
        return 'Rented';
      case RentalVehicleStatus.maintenance:
        return 'Maintenance';
      case RentalVehicleStatus.inactive:
        return 'Inactive';
    }
  }

  static RentalVehicleStatus fromString(String? val) {
    if (val == null) return RentalVehicleStatus.available;
    return RentalVehicleStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => RentalVehicleStatus.available,
    );
  }
}

class RentalVehicle {
  const RentalVehicle({
    required this.id,
    required this.fleetId,
    required this.ownerUid,
    required this.make,
    required this.model,
    required this.year,
    required this.category,
    required this.transmission,
    required this.seats,
    required this.plateNumber,
    this.fuelType = 'Petrol',
    this.color = '',
    this.images = const [],
    this.city = 'Abuja',
    this.dailySelfDriveRate = 0.0,
    this.dailyWithDriverRate = 0.0,
    this.hourlyChauffeurRate = 0.0,
    this.cautionDeposit = 0.0,
    this.features = const [],
    this.status = RentalVehicleStatus.available,
    this.assignedDefaultDriverId,
    this.assignedDefaultDriverName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String fleetId;
  final String ownerUid;
  final String make;
  final String model;
  final int year;
  final RentalVehicleCategory category;
  final String transmission; // 'Automatic' | 'Manual'
  final String fuelType;
  final int seats;
  final String color;
  final String plateNumber;
  final List<String> images;
  final String city;
  final double dailySelfDriveRate;
  final double dailyWithDriverRate;
  final double hourlyChauffeurRate;
  final double cautionDeposit;
  final List<String> features;
  final RentalVehicleStatus status;
  final String? assignedDefaultDriverId;
  final String? assignedDefaultDriverName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName => '$year $make $model'.trim();

  String get primaryImageUrl => images.isNotEmpty ? images.first : '';

  bool get isAvailable => status == RentalVehicleStatus.available;

  RentalVehicle copyWith({
    String? id,
    String? fleetId,
    String? ownerUid,
    String? make,
    String? model,
    int? year,
    RentalVehicleCategory? category,
    String? transmission,
    String? fuelType,
    int? seats,
    String? color,
    String? plateNumber,
    List<String>? images,
    String? city,
    double? dailySelfDriveRate,
    double? dailyWithDriverRate,
    double? hourlyChauffeurRate,
    double? cautionDeposit,
    List<String>? features,
    RentalVehicleStatus? status,
    String? assignedDefaultDriverId,
    String? assignedDefaultDriverName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RentalVehicle(
      id: id ?? this.id,
      fleetId: fleetId ?? this.fleetId,
      ownerUid: ownerUid ?? this.ownerUid,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      category: category ?? this.category,
      transmission: transmission ?? this.transmission,
      fuelType: fuelType ?? this.fuelType,
      seats: seats ?? this.seats,
      color: color ?? this.color,
      plateNumber: plateNumber ?? this.plateNumber,
      images: images ?? this.images,
      city: city ?? this.city,
      dailySelfDriveRate: dailySelfDriveRate ?? this.dailySelfDriveRate,
      dailyWithDriverRate: dailyWithDriverRate ?? this.dailyWithDriverRate,
      hourlyChauffeurRate: hourlyChauffeurRate ?? this.hourlyChauffeurRate,
      cautionDeposit: cautionDeposit ?? this.cautionDeposit,
      features: features ?? this.features,
      status: status ?? this.status,
      assignedDefaultDriverId:
          assignedDefaultDriverId ?? this.assignedDefaultDriverId,
      assignedDefaultDriverName:
          assignedDefaultDriverName ?? this.assignedDefaultDriverName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fleetId': fleetId,
      'ownerUid': ownerUid,
      'make': make,
      'model': model,
      'year': year,
      'category': category.name,
      'transmission': transmission,
      'fuelType': fuelType,
      'seats': seats,
      'color': color,
      'plateNumber': plateNumber,
      'images': images,
      'city': city,
      'dailySelfDriveRate': dailySelfDriveRate,
      'dailyWithDriverRate': dailyWithDriverRate,
      'hourlyChauffeurRate': hourlyChauffeurRate,
      'cautionDeposit': cautionDeposit,
      'features': features,
      'status': status.name,
      'assignedDefaultDriverId': assignedDefaultDriverId,
      'assignedDefaultDriverName': assignedDefaultDriverName,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory RentalVehicle.fromMap(Map<String, dynamic> map, [String? docId]) {
    return RentalVehicle(
      id: docId ?? map['id'] as String? ?? '',
      fleetId: map['fleetId'] as String? ?? '',
      ownerUid: map['ownerUid'] as String? ?? '',
      make: map['make'] as String? ?? '',
      model: map['model'] as String? ?? '',
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      category: RentalVehicleCategory.fromString(map['category'] as String?),
      transmission: map['transmission'] as String? ?? 'Automatic',
      fuelType: map['fuelType'] as String? ?? 'Petrol',
      seats: (map['seats'] as num?)?.toInt() ?? 4,
      color: map['color'] as String? ?? '',
      plateNumber: map['plateNumber'] as String? ?? '',
      images: (map['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      city: map['city'] as String? ?? 'Abuja',
      dailySelfDriveRate:
          (map['dailySelfDriveRate'] as num?)?.toDouble() ?? 0.0,
      dailyWithDriverRate:
          (map['dailyWithDriverRate'] as num?)?.toDouble() ?? 0.0,
      hourlyChauffeurRate:
          (map['hourlyChauffeurRate'] as num?)?.toDouble() ?? 0.0,
      cautionDeposit: (map['cautionDeposit'] as num?)?.toDouble() ?? 0.0,
      features: (map['features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      status: RentalVehicleStatus.fromString(map['status'] as String?),
      assignedDefaultDriverId: map['assignedDefaultDriverId'] as String?,
      assignedDefaultDriverName: map['assignedDefaultDriverName'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }
}
