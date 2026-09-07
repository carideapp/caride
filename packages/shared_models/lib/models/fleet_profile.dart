class FleetProfile {
  const FleetProfile({
    required this.fleetId,
    required this.ownerUid,
    required this.businessName,
    required this.phone,
    required this.email,
    this.businessType = 'individual',
    this.fullName = '',
    this.gender,
    this.profilePictureUrl,
    this.registrationNumber = '',
    this.address = '',
    this.state = 'FCT (Abuja)',
    this.operatingStates = const ['FCT (Abuja)'],
    this.city = 'Abuja',
    this.operatingCities = const ['Abuja'],
    this.logoUrl,
    this.identityDocumentType,
    this.identityDocumentUrl,
    this.identityDocumentStatus = 'pending',
    this.cacDocumentUrl,
    this.cacDocumentStatus,
    this.verificationStatus = 'pending',
    this.rejectionReason,
    this.referredByCode,
    this.isVerified = false,
    this.rating = 5.0,
    this.totalVehicles = 0,
    this.totalEarnings = 0.0,
    this.walletBalance = 0.0,
    this.securityPin,
    this.bankName,
    this.accountNumber,
    this.accountName,
    this.driverIds = const [],
    this.isDeleted = false,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String fleetId;
  final String ownerUid;
  final String businessName;
  final String phone;
  final String email;
  final String businessType; // 'individual' or 'company'
  final String fullName; // Owner / Representative Full Name
  final String? gender;
  final String? profilePictureUrl;
  final String registrationNumber;
  final String address;
  final String state;
  final List<String> operatingStates;
  final String city;
  final List<String> operatingCities;
  final String? logoUrl;
  final String? identityDocumentType;
  final String? identityDocumentUrl;
  final String identityDocumentStatus; // 'pending', 'approved', 'rejected'
  final String? cacDocumentUrl;
  final String? cacDocumentStatus;
  final String verificationStatus; // 'pending', 'approved', 'rejected', 'suspended'
  final String? rejectionReason;
  final String? referredByCode;
  final bool isVerified;
  final double rating;
  final int totalVehicles;
  final double totalEarnings;
  final double walletBalance;
  final String? securityPin;

  // Legacy banking parameters (preserved for backward compatibility)
  final String? bankName;
  final String? accountNumber;
  final String? accountName;
  final List<String> driverIds;

  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isApproved => verificationStatus == 'approved' || isVerified;
  bool get isPending => verificationStatus == 'pending' && !isVerified;
  bool get isRejected => verificationStatus == 'rejected';
  bool get isSuspended => verificationStatus == 'suspended';
  bool get isCompany => businessType == 'company';
  bool get isIndividual => businessType == 'individual';
  bool get hasSecurityPin => securityPin != null && securityPin!.trim().isNotEmpty;

  FleetProfile copyWith({
    String? fleetId,
    String? ownerUid,
    String? businessName,
    String? phone,
    String? email,
    String? businessType,
    String? fullName,
    String? gender,
    String? profilePictureUrl,
    String? registrationNumber,
    String? address,
    String? state,
    List<String>? operatingStates,
    String? city,
    List<String>? operatingCities,
    String? logoUrl,
    String? identityDocumentType,
    String? identityDocumentUrl,
    String? identityDocumentStatus,
    String? cacDocumentUrl,
    String? cacDocumentStatus,
    String? verificationStatus,
    String? rejectionReason,
    String? referredByCode,
    bool? isVerified,
    double? rating,
    int? totalVehicles,
    double? totalEarnings,
    double? walletBalance,
    String? securityPin,
    String? bankName,
    String? accountNumber,
    String? accountName,
    List<String>? driverIds,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FleetProfile(
      fleetId: fleetId ?? this.fleetId,
      ownerUid: ownerUid ?? this.ownerUid,
      businessName: businessName ?? this.businessName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      businessType: businessType ?? this.businessType,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      address: address ?? this.address,
      state: state ?? this.state,
      operatingStates: operatingStates ?? this.operatingStates,
      city: city ?? this.city,
      operatingCities: operatingCities ?? this.operatingCities,
      logoUrl: logoUrl ?? this.logoUrl,
      identityDocumentType: identityDocumentType ?? this.identityDocumentType,
      identityDocumentUrl: identityDocumentUrl ?? this.identityDocumentUrl,
      identityDocumentStatus: identityDocumentStatus ?? this.identityDocumentStatus,
      cacDocumentUrl: cacDocumentUrl ?? this.cacDocumentUrl,
      cacDocumentStatus: cacDocumentStatus ?? this.cacDocumentStatus,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      referredByCode: referredByCode ?? this.referredByCode,
      isVerified: isVerified ?? this.isVerified,
      rating: rating ?? this.rating,
      totalVehicles: totalVehicles ?? this.totalVehicles,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      walletBalance: walletBalance ?? this.walletBalance,
      securityPin: securityPin ?? this.securityPin,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      driverIds: driverIds ?? this.driverIds,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    final effectiveStates = operatingStates.isNotEmpty
        ? operatingStates
        : (operatingCities.isNotEmpty ? operatingCities : [state]);

    return {
      'fleetId': fleetId,
      'ownerUid': ownerUid,
      'businessName': businessName,
      'phone': phone,
      'email': email,
      'businessType': businessType,
      'fullName': fullName,
      'gender': gender,
      'profilePictureUrl': profilePictureUrl,
      'registrationNumber': registrationNumber,
      'address': address,
      'state': effectiveStates.isNotEmpty ? effectiveStates.first : state,
      'operatingStates': effectiveStates,
      'city': effectiveStates.isNotEmpty ? effectiveStates.first : city,
      'operatingCities': effectiveStates,
      'logoUrl': logoUrl,
      'identityDocumentType': identityDocumentType,
      'identityDocumentUrl': identityDocumentUrl,
      'identityDocumentStatus': identityDocumentStatus,
      'cacDocumentUrl': cacDocumentUrl,
      'cacDocumentStatus': cacDocumentStatus,
      'verificationStatus': verificationStatus,
      'rejectionReason': rejectionReason,
      'referredByCode': referredByCode,
      'isVerified': isVerified,
      'rating': rating,
      'totalVehicles': totalVehicles,
      'totalEarnings': totalEarnings,
      'walletBalance': walletBalance,
      'securityPin': securityPin,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'driverIds': driverIds,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory FleetProfile.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawStates = (map['operatingStates'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        (map['operatingCities'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        (map['state'] != null && (map['state'] as String).isNotEmpty
            ? (map['state'] as String)
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList()
            : (map['city'] != null && (map['city'] as String).isNotEmpty
                ? (map['city'] as String)
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList()
                : const ['FCT (Abuja)']));

    final primaryState = map['state'] as String? ??
        map['city'] as String? ??
        (rawStates.isNotEmpty ? rawStates.first : 'FCT (Abuja)');

    return FleetProfile(
      fleetId: docId ?? map['fleetId'] as String? ?? '',
      ownerUid: map['ownerUid'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      businessType: map['businessType'] as String? ?? 'individual',
      fullName: map['fullName'] as String? ?? '',
      gender: map['gender'] as String?,
      profilePictureUrl: map['profilePictureUrl'] as String? ?? map['photoUrl'] as String?,
      registrationNumber: map['registrationNumber'] as String? ?? '',
      address: map['address'] as String? ?? '',
      state: primaryState,
      operatingStates: rawStates,
      city: primaryState,
      operatingCities: rawStates,
      logoUrl: map['logoUrl'] as String?,
      identityDocumentType: map['identityDocumentType'] as String?,
      identityDocumentUrl: map['identityDocumentUrl'] as String?,
      identityDocumentStatus: map['identityDocumentStatus'] as String? ?? 'pending',
      cacDocumentUrl: map['cacDocumentUrl'] as String?,
      cacDocumentStatus: map['cacDocumentStatus'] as String?,
      verificationStatus: map['verificationStatus'] as String? ?? (map['isVerified'] == true ? 'approved' : 'pending'),
      rejectionReason: map['rejectionReason'] as String?,
      referredByCode: map['referredByCode'] as String?,
      isVerified: map['isVerified'] as bool? ?? false,
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      totalVehicles: (map['totalVehicles'] as num?)?.toInt() ?? 0,
      totalEarnings: (map['totalEarnings'] as num?)?.toDouble() ?? 0.0,
      walletBalance: (map['walletBalance'] as num?)?.toDouble() ??
          (map['totalEarnings'] as num?)?.toDouble() ??
          0.0,
      securityPin: map['securityPin'] as String?,
      bankName: map['bankName'] as String?,
      accountNumber: map['accountNumber'] as String?,
      accountName: map['accountName'] as String?,
      driverIds: (map['driverIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isDeleted: map['isDeleted'] as bool? ?? false,
      deletedAt: map['deletedAt'] != null
          ? DateTime.tryParse(map['deletedAt'].toString())
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }
}
