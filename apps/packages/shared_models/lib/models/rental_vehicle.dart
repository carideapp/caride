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
    this.assignedDefaultDriverPhone,
    this.rentalMode = 'both',
    this.isArmored = false,
    this.armorLevel,
    this.hasSecurityEscortOption = false,
    this.securityEscortDailyRate = 0.0,
    this.hasDropOffOption = false,
    this.dropOffRate = 0.0,
    this.allowsInterstate = true,
    this.interstateDailySurcharge = 0.0,
    this.driverOvernightAllowance = 0.0,
    this.overtimeHourlyRate = 0.0,
    this.minChauffeurHours = 3,
    this.fuelPolicy = 'dry_lease',
    this.blackoutDates = const [],
    this.description = '',
    this.rating,
    this.tripCount = 0,
    this.reviewCount = 0,
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
  final String description;
  final double dailySelfDriveRate;
  final double dailyWithDriverRate;
  final double hourlyChauffeurRate;
  final double cautionDeposit;
  final List<String> features;
  final RentalVehicleStatus status;
  final String? assignedDefaultDriverId;
  final String? assignedDefaultDriverName;
  final String? assignedDefaultDriverPhone;

  /// Service mode: 'both' | 'chauffeur_only' | 'self_drive_only'
  final String rentalMode;

  /// Armored / Bulletproof specification
  final bool isArmored;
  final String? armorLevel; // e.g. 'B4', 'B6', 'B7'

  /// Armed security escort availability
  final bool hasSecurityEscortOption;
  final double securityEscortDailyRate;

  /// One-way drop-off / Airport transfer configuration
  final bool hasDropOffOption;
  final double dropOffRate;

  /// Inter-state travel configuration
  final bool allowsInterstate;
  final double interstateDailySurcharge;
  final double driverOvernightAllowance;

  /// Chauffeur-specific hourly rates & rules
  final double overtimeHourlyRate;
  final int minChauffeurHours;

  /// Fuel lease policy: 'dry_lease' (renter pays) | 'wet_lease' (fuel included)
  final String fuelPolicy;

  /// Fleet manager manual maintenance / blackout dates (ISO 'YYYY-MM-DD')
  final List<String> blackoutDates;

  /// Optional live customer reviews & completed rentals metrics
  final double? rating;
  final int tripCount;
  final int reviewCount;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName => '$year $make $model'.trim();

  String get primaryImageUrl => images.isNotEmpty ? images.first : '';

  bool get isAvailable => status == RentalVehicleStatus.available;

  bool get isChauffeurOnly => rentalMode == 'chauffeur_only';
  bool get isSelfDriveOnly => rentalMode == 'self_drive_only';
  bool get allowsSelfDrive => rentalMode != 'chauffeur_only';
  bool get allowsChauffeur => rentalMode != 'self_drive_only';
  bool get allowsDropOff => (hasDropOffOption || dropOffRate > 0) && dropOffRate > 0;

  double get lowestAvailableRate {
    final rates = <double>[];
    if (dailySelfDriveRate > 0) rates.add(dailySelfDriveRate);
    if (dailyWithDriverRate > 0) rates.add(dailyWithDriverRate);
    if (dropOffRate > 0) rates.add(dropOffRate);
    if (rates.isEmpty) return 0.0;
    return rates.reduce((a, b) => a < b ? a : b);
  }

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
    String? description,
    double? dailySelfDriveRate,
    double? dailyWithDriverRate,
    double? hourlyChauffeurRate,
    double? cautionDeposit,
    List<String>? features,
    RentalVehicleStatus? status,
    String? assignedDefaultDriverId,
    String? assignedDefaultDriverName,
    String? assignedDefaultDriverPhone,
    String? rentalMode,
    bool? isArmored,
    String? armorLevel,
    bool? hasSecurityEscortOption,
    double? securityEscortDailyRate,
    bool? hasDropOffOption,
    double? dropOffRate,
    bool? allowsInterstate,
    double? interstateDailySurcharge,
    double? driverOvernightAllowance,
    double? overtimeHourlyRate,
    int? minChauffeurHours,
    String? fuelPolicy,
    List<String>? blackoutDates,
    double? rating,
    int? tripCount,
    int? reviewCount,
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
      description: description ?? this.description,
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
      assignedDefaultDriverPhone:
          assignedDefaultDriverPhone ?? this.assignedDefaultDriverPhone,
      rentalMode: rentalMode ?? this.rentalMode,
      isArmored: isArmored ?? this.isArmored,
      armorLevel: armorLevel ?? this.armorLevel,
      hasSecurityEscortOption:
          hasSecurityEscortOption ?? this.hasSecurityEscortOption,
      securityEscortDailyRate:
          securityEscortDailyRate ?? this.securityEscortDailyRate,
      hasDropOffOption: hasDropOffOption ?? this.hasDropOffOption,
      dropOffRate: dropOffRate ?? this.dropOffRate,
      allowsInterstate: allowsInterstate ?? this.allowsInterstate,
      interstateDailySurcharge:
          interstateDailySurcharge ?? this.interstateDailySurcharge,
      driverOvernightAllowance:
          driverOvernightAllowance ?? this.driverOvernightAllowance,
      overtimeHourlyRate: overtimeHourlyRate ?? this.overtimeHourlyRate,
      minChauffeurHours: minChauffeurHours ?? this.minChauffeurHours,
      fuelPolicy: fuelPolicy ?? this.fuelPolicy,
      blackoutDates: blackoutDates ?? this.blackoutDates,
      rating: rating ?? this.rating,
      tripCount: tripCount ?? this.tripCount,
      reviewCount: reviewCount ?? this.reviewCount,
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
      'description': description,
      'dailySelfDriveRate': dailySelfDriveRate,
      'dailyWithDriverRate': dailyWithDriverRate,
      'hourlyChauffeurRate': hourlyChauffeurRate,
      'cautionDeposit': cautionDeposit,
      'features': features,
      'status': status.name,
      'assignedDefaultDriverId': assignedDefaultDriverId,
      'assignedDefaultDriverName': assignedDefaultDriverName,
      'assignedDefaultDriverPhone': assignedDefaultDriverPhone,
      'rentalMode': rentalMode,
      'isArmored': isArmored,
      'armorLevel': armorLevel,
      'hasSecurityEscortOption': hasSecurityEscortOption,
      'securityEscortDailyRate': securityEscortDailyRate,
      'hasDropOffOption': hasDropOffOption,
      'dropOffRate': dropOffRate,
      'allowsInterstate': allowsInterstate,
      'interstateDailySurcharge': interstateDailySurcharge,
      'driverOvernightAllowance': driverOvernightAllowance,
      'overtimeHourlyRate': overtimeHourlyRate,
      'minChauffeurHours': minChauffeurHours,
      'fuelPolicy': fuelPolicy,
      'blackoutDates': blackoutDates,
      if (rating != null) 'rating': rating,
      'tripCount': tripCount,
      'reviewCount': reviewCount,
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
      images: _parseImages(map),
      city: map['city'] as String? ?? 'Abuja',
      description: map['description'] as String? ?? '',
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
      assignedDefaultDriverPhone: map['assignedDefaultDriverPhone'] as String?,
      rentalMode: map['rentalMode'] as String? ?? 'both',
      isArmored: map['isArmored'] as bool? ?? false,
      armorLevel: map['armorLevel'] as String?,
      hasSecurityEscortOption:
          map['hasSecurityEscortOption'] as bool? ?? false,
      securityEscortDailyRate:
          (map['securityEscortDailyRate'] as num?)?.toDouble() ?? 0.0,
      hasDropOffOption: map['hasDropOffOption'] as bool? ??
          (((map['dropOffRate'] as num?)?.toDouble() ?? 0.0) > 0),
      dropOffRate: (map['dropOffRate'] as num?)?.toDouble() ??
          (map['dropoffRate'] as num?)?.toDouble() ??
          (map['airportDropOffRate'] as num?)?.toDouble() ??
          0.0,
      allowsInterstate: map['allowsInterstate'] as bool? ?? true,
      interstateDailySurcharge:
          (map['interstateDailySurcharge'] as num?)?.toDouble() ?? 0.0,
      driverOvernightAllowance:
          (map['driverOvernightAllowance'] as num?)?.toDouble() ?? 0.0,
      overtimeHourlyRate:
          (map['overtimeHourlyRate'] as num?)?.toDouble() ?? 0.0,
      minChauffeurHours: (map['minChauffeurHours'] as num?)?.toInt() ?? 3,
      fuelPolicy: map['fuelPolicy'] as String? ?? 'dry_lease',
      blackoutDates: (map['blackoutDates'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      rating: (map['rating'] as num?)?.toDouble() ??
          (map['averageRating'] as num?)?.toDouble() ??
          (map['avgRating'] as num?)?.toDouble() ??
          (map['vehicleRating'] as num?)?.toDouble() ??
          (map['stars'] as num?)?.toDouble(),
      tripCount: (map['tripCount'] as num?)?.toInt() ??
          (map['completedTrips'] as num?)?.toInt() ??
          (map['totalTrips'] as num?)?.toInt() ??
          (map['rentalsCount'] as num?)?.toInt() ??
          0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ??
          (map['reviewsCount'] as num?)?.toInt() ??
          (map['totalReviews'] as num?)?.toInt() ??
          0,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  /// Resilient image parser that extracts valid URLs from `List<String>`, `List<Map>`,
  /// single string, and multiple legacy field names ('images', 'photos', 'photoUrls', etc.).
  static List<String> _parseImages(Map<String, dynamic> map) {
    final urls = <String>[];

    void extractFromItem(dynamic item) {
      if (item == null) return;
      if (item is String) {
        final trimmed = item.trim();
        if (trimmed.isNotEmpty) {
          // If the item contains a stringified map or JSON e.g. "{url: https://...}"
          if (trimmed.startsWith('{') && trimmed.contains('http')) {
            final match = RegExp(r'https?://[^\s, }"\x27]+').firstMatch(trimmed);
            if (match != null) {
              final extracted = match.group(0)!;
              if (!urls.contains(extracted)) urls.add(extracted);
              return;
            }
          }
          if (!urls.contains(trimmed)) urls.add(trimmed);
        }
      } else if (item is Map) {
        final possibleKeys = [
          'url',
          'downloadUrl',
          'imageUrl',
          'photoUrl',
          'uri',
          'link',
          'path',
        ];
        for (final key in possibleKeys) {
          if (item[key] != null && item[key].toString().trim().isNotEmpty) {
            extractFromItem(item[key]);
            return;
          }
        }
      }
    }

    void extractFromField(dynamic fieldVal) {
      if (fieldVal == null) return;
      if (fieldVal is List) {
        for (final el in fieldVal) {
          extractFromItem(el);
        }
      } else {
        extractFromItem(fieldVal);
      }
    }

    // Inspect all potential photo and image fields in Firestore documents
    extractFromField(map['images']);
    extractFromField(map['photos']);
    extractFromField(map['imageUrls']);
    extractFromField(map['photoUrls']);
    extractFromField(map['vehiclePhotos']);
    extractFromField(map['coverPhoto']);
    extractFromField(map['coverImageUrl']);
    extractFromField(map['imageUrl']);
    extractFromField(map['photoUrl']);

    return urls;
  }
}
