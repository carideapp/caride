import 'package:cloud_firestore/cloud_firestore.dart';

class DriverProfile {
  const DriverProfile({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.profilePhotoUrl,
    required this.role,
    required this.isEmailVerified,
    required this.profileCompleted,
    required this.approvalStatus,
    required this.walletBalance,
    required this.tier,
    required this.completedRides,
    required this.averageRating,
    required this.totalRatings,
    required this.referralCode,
    required this.referralEarnings,
    this.username = '',
    this.country = 'Nigeria',
    this.state = '',
    this.coverPhotoUrl,
    this.linkedFleetIds = const [],
    this.referredByCode,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String email;
  final String fullName;
  final String phone;
  final String username;
  final String country;
  final String state;
  final String profilePhotoUrl;
  final String? coverPhotoUrl;
  final List<String> linkedFleetIds;
  final String role;
  final bool isEmailVerified;
  final bool profileCompleted;
  /// 'draft' | 'pending' | 'approved' | 'rejected'
  final String approvalStatus;
  final String? rejectionReason;
  final double walletBalance;
  // Tier system
  final String tier;
  final int completedRides;
  final double averageRating;
  final int totalRatings;
  // Referral system
  final String referralCode;
  final double referralEarnings;
  final String? referredByCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isDraft => approvalStatus == 'draft';
  bool get isPending => approvalStatus == 'pending';
  bool get isApproved => approvalStatus == 'approved';
  bool get isRejected => approvalStatus == 'rejected';
  double get rating => averageRating;

  factory DriverProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return DriverProfile.fromMap(uid: doc.id, data: doc.data() ?? {});
  }

  factory DriverProfile.fromMap({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    return DriverProfile(
      uid: uid,
      email: (data['email'] as String?) ?? '',
      fullName: (data['fullName'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      username: (data['username'] as String?) ?? '',
      country: (data['country'] as String?) ?? 'Nigeria',
      state: (data['state'] as String?) ?? '',
      profilePhotoUrl: (data['profilePhotoUrl'] as String?) ?? '',
      coverPhotoUrl: (data['coverPhotoUrl'] as String?) ?? (data['businessCoverPhotoUrl'] as String?),
      linkedFleetIds: (data['linkedFleetIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      role: (data['role'] as String?) ?? 'driver',
      isEmailVerified: (data['isEmailVerified'] as bool?) ?? false,
      profileCompleted: (data['profileCompleted'] as bool?) ?? false,
      approvalStatus: (data['approvalStatus'] as String?) ?? 'draft',
      rejectionReason: data['rejectionReason'] as String?,
      walletBalance: (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
      tier: (data['tier'] as String?) ?? 'bronze',
      completedRides: (data['completedRides'] as int?) ?? 0,
      averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: (data['totalRatings'] as int?) ?? 0,
      referralCode: (data['referralCode'] as String?) ?? '',
      referralEarnings: (data['referralEarnings'] as num?)?.toDouble() ?? 0.0,
      referredByCode: data['referredByCode'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'username': username,
      'country': country,
      'state': state,
      'profilePhotoUrl': profilePhotoUrl,
      'coverPhotoUrl': coverPhotoUrl,
      'linkedFleetIds': linkedFleetIds,
      'role': role,
      'isEmailVerified': isEmailVerified,
      'profileCompleted': profileCompleted,
      'approvalStatus': approvalStatus,
      'rejectionReason': rejectionReason,
      'walletBalance': walletBalance,
      'tier': tier,
      'completedRides': completedRides,
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'referralCode': referralCode,
      'referralEarnings': referralEarnings,
      'referredByCode': referredByCode,
    };
  }
}
