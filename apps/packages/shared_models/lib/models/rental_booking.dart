enum RentalServiceType {
  selfDrive,
  withDriver,
  dropOff;

  String get label {
    switch (this) {
      case RentalServiceType.selfDrive:
        return 'Self Drive';
      case RentalServiceType.withDriver:
        return 'With Chauffeur';
      case RentalServiceType.dropOff:
        return 'Drop-Off / Transfer';
    }
  }

  static RentalServiceType fromString(String? val) {
    if (val == null) return RentalServiceType.withDriver;
    return RentalServiceType.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => RentalServiceType.withDriver,
    );
  }
}

enum RentalBookingStatus {
  pendingApproval,
  awaitingPayment,
  confirmed,
  inProgress,
  completed,
  cancelled,
  rejected;

  String get label {
    switch (this) {
      case RentalBookingStatus.pendingApproval:
        return 'Pending Approval';
      case RentalBookingStatus.awaitingPayment:
        return 'Awaiting Payment';
      case RentalBookingStatus.confirmed:
        return 'Confirmed / Dispatched';
      case RentalBookingStatus.inProgress:
        return 'In Progress';
      case RentalBookingStatus.completed:
        return 'Completed';
      case RentalBookingStatus.cancelled:
        return 'Cancelled';
      case RentalBookingStatus.rejected:
        return 'Declined';
    }
  }

  static RentalBookingStatus fromString(String? val) {
    if (val == null) return RentalBookingStatus.pendingApproval;
    return RentalBookingStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => RentalBookingStatus.pendingApproval,
    );
  }
}

/// Tracks the driver's on-trip progress for a rental booking.
enum RentalTripStatus {
  assigned,
  headingToPickup,
  inProgress,
  completed;

  String get label {
    switch (this) {
      case RentalTripStatus.assigned:
        return 'Assigned';
      case RentalTripStatus.headingToPickup:
        return 'Heading to Pickup';
      case RentalTripStatus.inProgress:
        return 'In Progress';
      case RentalTripStatus.completed:
        return 'Completed';
    }
  }

  static RentalTripStatus fromString(String? val) {
    if (val == null) return RentalTripStatus.assigned;
    return RentalTripStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => RentalTripStatus.assigned,
    );
  }
}

class RentalBooking {
  const RentalBooking({
    required this.id,
    required this.fleetId,
    required this.vehicleId,
    required this.vehicleTitle,
    required this.vehicleImage,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.serviceType,
    required this.startDate,
    required this.endDate,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.totalAmount,
    this.vehicleCategory = 'Sedan',
    this.customerPhoto,
    this.durationDays = 1,
    this.durationHours,
    this.pickupTime,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    this.cautionDeposit = 0.0,
    this.driverAllowance = 0.0,
    this.currency = '₦',
    this.status = RentalBookingStatus.pendingApproval,
    this.assignedDriverId,
    this.assignedDriverName,
    this.assignedDriverPhone,
    this.paymentStatus = 'pending',
    this.notes,
    this.rejectionReason,
    this.cancellationReason,
    this.paymentExpiresAt,
    this.startPin,
    this.startPinUsed = false,
    this.pickupPin,
    this.pickupPinUsed = false,
    this.returnPin,
    this.returnPinUsed = false,
    this.fleetCommissionPercent,
    this.fleetEarnings,
    this.rentalTripStatus,
    this.isRated = false,
    this.rating,
    this.reviewComment,
    this.driversLicenseNumber,
    this.driversLicenseUrl,
    this.identityDocumentType,
    this.identityDocumentUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String fleetId;
  final String vehicleId;
  final String vehicleTitle;
  final String vehicleImage;
  final String vehicleCategory;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? customerPhoto;
  final RentalServiceType serviceType;
  final DateTime startDate;
  final DateTime endDate;
  final int durationDays;
  final int? durationHours;
  final String? pickupTime;
  final String pickupLocation;
  final String dropoffLocation;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final double totalAmount;
  final double cautionDeposit;
  final double driverAllowance;
  final String currency;
  final RentalBookingStatus status;
  final String? assignedDriverId;
  final String? assignedDriverName;
  final String? assignedDriverPhone;
  final String paymentStatus; // 'pending' | 'paid' | 'refunded'
  final String? notes;
  final String? rejectionReason;
  final String? cancellationReason;

  /// Expiration timestamp for bookings in awaitingPayment status (e.g. 3 hours from approval).
  final DateTime? paymentExpiresAt;

  /// 4-digit PIN generated server-side at payment confirmation.
  /// Used by the driver to start the rental ride (chauffeur mode).
  final String? startPin;

  /// Whether the startPin has been consumed to start the ride.
  final bool startPinUsed;

  /// 4-digit PIN generated at payment for self-drive bookings.
  /// Displayed to the fleet manager; customer enters it to confirm pickup.
  final String? pickupPin;

  /// Whether the pickupPin has been used (booking moved to inProgress).
  final bool pickupPinUsed;

  /// 4-digit PIN generated when customer picks up the vehicle.
  /// Displayed to the fleet manager; customer enters it to confirm return.
  final String? returnPin;

  /// Whether the returnPin has been used (booking moved to completed).
  final bool returnPinUsed;

  /// Snapshot of the commission percentage applied at payment time.
  final double? fleetCommissionPercent;

  /// Net amount credited to the fleet wallet after commission deduction.
  final double? fleetEarnings;

  /// Driver's on-trip progress for chauffeur bookings.
  final RentalTripStatus? rentalTripStatus;

  /// Rating state for completed rentals
  final bool isRated;
  final double? rating;
  final String? reviewComment;

  /// Self-drive customer verification documents
  final String? driversLicenseNumber;
  final String? driversLicenseUrl;
  final String? identityDocumentType;
  final String? identityDocumentUrl;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isChauffeur => serviceType == RentalServiceType.withDriver;
  bool get isPending => status == RentalBookingStatus.pendingApproval;
  bool get isAwaitingPayment => status == RentalBookingStatus.awaitingPayment;
  bool get isPaid => paymentStatus.trim().toLowerCase() == 'paid';
  bool get isActive =>
      status == RentalBookingStatus.confirmed ||
      status == RentalBookingStatus.inProgress;
  bool get isDriverAssigned =>
      assignedDriverId != null && assignedDriverId!.isNotEmpty;
  bool get isPaymentExpired =>
      paymentExpiresAt != null && DateTime.now().isAfter(paymentExpiresAt!);

  RentalBooking copyWith({
    String? id,
    String? fleetId,
    String? vehicleId,
    String? vehicleTitle,
    String? vehicleImage,
    String? vehicleCategory,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerPhoto,
    RentalServiceType? serviceType,
    DateTime? startDate,
    DateTime? endDate,
    int? durationDays,
    int? durationHours,
    String? pickupTime,
    String? pickupLocation,
    String? dropoffLocation,
    double? pickupLat,
    double? pickupLng,
    double? dropoffLat,
    double? dropoffLng,
    double? totalAmount,
    double? cautionDeposit,
    double? driverAllowance,
    String? currency,
    RentalBookingStatus? status,
    String? assignedDriverId,
    String? assignedDriverName,
    String? assignedDriverPhone,
    String? paymentStatus,
    String? notes,
    String? rejectionReason,
    String? cancellationReason,
    DateTime? paymentExpiresAt,
    String? startPin,
    bool? startPinUsed,
    String? pickupPin,
    bool? pickupPinUsed,
    String? returnPin,
    bool? returnPinUsed,
    double? fleetCommissionPercent,
    double? fleetEarnings,
    RentalTripStatus? rentalTripStatus,
    bool? isRated,
    double? rating,
    String? reviewComment,
    String? driversLicenseNumber,
    String? driversLicenseUrl,
    String? identityDocumentType,
    String? identityDocumentUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RentalBooking(
      id: id ?? this.id,
      fleetId: fleetId ?? this.fleetId,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleTitle: vehicleTitle ?? this.vehicleTitle,
      vehicleImage: vehicleImage ?? this.vehicleImage,
      vehicleCategory: vehicleCategory ?? this.vehicleCategory,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerPhoto: customerPhoto ?? this.customerPhoto,
      serviceType: serviceType ?? this.serviceType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      durationDays: durationDays ?? this.durationDays,
      durationHours: durationHours ?? this.durationHours,
      pickupTime: pickupTime ?? this.pickupTime,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      totalAmount: totalAmount ?? this.totalAmount,
      cautionDeposit: cautionDeposit ?? this.cautionDeposit,
      driverAllowance: driverAllowance ?? this.driverAllowance,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedDriverName: assignedDriverName ?? this.assignedDriverName,
      assignedDriverPhone: assignedDriverPhone ?? this.assignedDriverPhone,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      notes: notes ?? this.notes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      paymentExpiresAt: paymentExpiresAt ?? this.paymentExpiresAt,
      startPin: startPin ?? this.startPin,
      startPinUsed: startPinUsed ?? this.startPinUsed,
      pickupPin: pickupPin ?? this.pickupPin,
      pickupPinUsed: pickupPinUsed ?? this.pickupPinUsed,
      returnPin: returnPin ?? this.returnPin,
      returnPinUsed: returnPinUsed ?? this.returnPinUsed,
      fleetCommissionPercent: fleetCommissionPercent ?? this.fleetCommissionPercent,
      fleetEarnings: fleetEarnings ?? this.fleetEarnings,
      rentalTripStatus: rentalTripStatus ?? this.rentalTripStatus,
      isRated: isRated ?? this.isRated,
      rating: rating ?? this.rating,
      reviewComment: reviewComment ?? this.reviewComment,
      driversLicenseNumber: driversLicenseNumber ?? this.driversLicenseNumber,
      driversLicenseUrl: driversLicenseUrl ?? this.driversLicenseUrl,
      identityDocumentType: identityDocumentType ?? this.identityDocumentType,
      identityDocumentUrl: identityDocumentUrl ?? this.identityDocumentUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fleetId': fleetId,
      'vehicleId': vehicleId,
      'vehicleTitle': vehicleTitle,
      'vehicleImage': vehicleImage,
      'vehicleCategory': vehicleCategory,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerPhoto': customerPhoto,
      'serviceType': serviceType.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'durationDays': durationDays,
      'durationHours': durationHours,
      'pickupTime': pickupTime,
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'totalAmount': totalAmount,
      'cautionDeposit': cautionDeposit,
      'driverAllowance': driverAllowance,
      'currency': currency,
      'status': status.name,
      'assignedDriverId': assignedDriverId,
      'assignedDriverName': assignedDriverName,
      'assignedDriverPhone': assignedDriverPhone,
      'paymentStatus': paymentStatus,
      'notes': notes,
      'rejectionReason': rejectionReason,
      'cancellationReason': cancellationReason,
      'paymentExpiresAt': paymentExpiresAt?.toIso8601String(),
      'startPin': startPin,
      'startPinUsed': startPinUsed,
      'pickupPin': pickupPin,
      'pickupPinUsed': pickupPinUsed,
      'returnPin': returnPin,
      'returnPinUsed': returnPinUsed,
      'fleetCommissionPercent': fleetCommissionPercent,
      'fleetEarnings': fleetEarnings,
      'rentalTripStatus': rentalTripStatus?.name,
      'isRated': isRated,
      'rating': rating,
      'reviewComment': reviewComment,
      'driversLicenseNumber': driversLicenseNumber,
      'driversLicenseUrl': driversLicenseUrl,
      'identityDocumentType': identityDocumentType,
      'identityDocumentUrl': identityDocumentUrl,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory RentalBooking.fromMap(Map<String, dynamic> map, [String? docId]) {
    return RentalBooking(
      id: docId ?? map['id'] as String? ?? '',
      fleetId: map['fleetId'] as String? ?? '',
      vehicleId: map['vehicleId'] as String? ?? '',
      vehicleTitle: map['vehicleTitle'] as String? ?? '',
      vehicleImage: map['vehicleImage'] as String? ?? '',
      vehicleCategory: map['vehicleCategory'] as String? ?? 'Sedan',
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      customerPhone: map['customerPhone'] as String? ?? '',
      customerPhoto: map['customerPhoto'] as String?,
      serviceType: RentalServiceType.fromString(map['serviceType'] as String?),
      startDate: DateTime.tryParse(map['startDate']?.toString() ?? '') ??
          DateTime.now(),
      endDate: DateTime.tryParse(map['endDate']?.toString() ?? '') ??
          DateTime.now().add(const Duration(days: 1)),
      durationDays: (map['durationDays'] as num?)?.toInt() ?? 1,
      durationHours: (map['durationHours'] as num?)?.toInt(),
      pickupTime: map['pickupTime'] as String?,
      pickupLocation: map['pickupLocation'] as String? ?? '',
      dropoffLocation: map['dropoffLocation'] as String? ?? '',
      pickupLat: (map['pickupLat'] as num?)?.toDouble(),
      pickupLng: (map['pickupLng'] as num?)?.toDouble(),
      dropoffLat: (map['dropoffLat'] as num?)?.toDouble(),
      dropoffLng: (map['dropoffLng'] as num?)?.toDouble(),
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      cautionDeposit: (map['cautionDeposit'] as num?)?.toDouble() ?? 0.0,
      driverAllowance: (map['driverAllowance'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? '₦',
      status: RentalBookingStatus.fromString(map['status'] as String?),
      assignedDriverId: map['assignedDriverId'] as String?,
      assignedDriverName: map['assignedDriverName'] as String?,
      assignedDriverPhone: map['assignedDriverPhone'] as String?,
      paymentStatus: map['paymentStatus'] as String? ?? 'pending',
      notes: map['notes'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
      cancellationReason: map['cancellationReason'] as String?,
      paymentExpiresAt: map['paymentExpiresAt'] != null
          ? DateTime.tryParse(map['paymentExpiresAt'].toString())
          : null,
      startPin: map['startPin'] as String?,
      startPinUsed: map['startPinUsed'] as bool? ?? false,
      pickupPin: map['pickupPin'] as String?,
      pickupPinUsed: map['pickupPinUsed'] as bool? ?? false,
      returnPin: map['returnPin'] as String?,
      returnPinUsed: map['returnPinUsed'] as bool? ?? false,
      fleetCommissionPercent: (map['fleetCommissionPercent'] as num?)?.toDouble(),
      fleetEarnings: (map['fleetEarnings'] as num?)?.toDouble(),
      rentalTripStatus:
          RentalTripStatus.fromString(map['rentalTripStatus'] as String?),
      isRated: map['isRated'] as bool? ?? false,
      rating: (map['rating'] as num?)?.toDouble(),
      reviewComment: map['reviewComment'] as String?,
      driversLicenseNumber: map['driversLicenseNumber'] as String?,
      driversLicenseUrl: map['driversLicenseUrl'] as String?,
      identityDocumentType: map['identityDocumentType'] as String?,
      identityDocumentUrl: map['identityDocumentUrl'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }
}
