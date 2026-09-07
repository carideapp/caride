enum RentalServiceType {
  selfDrive,
  withDriver;

  String get label {
    switch (this) {
      case RentalServiceType.selfDrive:
        return 'Self Drive';
      case RentalServiceType.withDriver:
        return 'With Chauffeur';
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
  confirmed,
  inProgress,
  completed,
  cancelled,
  rejected;

  String get label {
    switch (this) {
      case RentalBookingStatus.pendingApproval:
        return 'Pending Approval';
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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isChauffeur => serviceType == RentalServiceType.withDriver;
  bool get isPending => status == RentalBookingStatus.pendingApproval;
  bool get isActive =>
      status == RentalBookingStatus.confirmed ||
      status == RentalBookingStatus.inProgress;

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
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }
}
