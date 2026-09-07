import 'package:cloud_firestore/cloud_firestore.dart';

class RideModel {
  const RideModel({
    required this.id,
    required this.customerUid,
    required this.status,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.rideType,
    required this.customerOffer,
    required this.paymentMethod,
    this.driverUid,
    this.driverName,
    this.driverRating,
    this.pickupName,
    this.dropoffName,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    this.amountNaira,
    this.finalFare,
    this.paymentStatus,
    this.ratedAt,
    this.customerRating,
    this.customerRatingComment,
    this.customerRatedAt,
    this.createdAt,
    this.updatedAt,
    this.acceptedAt,
    this.cancelledAt,
    this.startCode,
    this.receiverName,
    this.receiverPhone,
    this.deliveryPin,
  });

  final String id;
  final String customerUid;
  final String status;
  final String pickupLabel;
  final String dropoffLabel;
  final String rideType;
  final double customerOffer;
  final String paymentMethod;
  final String? driverUid;
  final String? driverName;
  final double? driverRating;
  final String? pickupName;
  final String? dropoffName;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final double? amountNaira;
  final double? finalFare;
  final String? paymentStatus;
  final DateTime? ratedAt;
  final int? customerRating;
  final String? customerRatingComment;
  final DateTime? customerRatedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? acceptedAt;
  final DateTime? cancelledAt;
  final String? startCode;
  final String? receiverName;
  final String? receiverPhone;
  /// 4-digit PIN for delivery confirmation at dropoff (Send Items only).
  final String? deliveryPin;

  factory RideModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return RideModel.fromMap(id: doc.id, data: doc.data() ?? {});
  }

  RideModel copyWith({
    String? id,
    String? customerUid,
    String? status,
    String? pickupLabel,
    String? dropoffLabel,
    String? rideType,
    double? customerOffer,
    String? paymentMethod,
    String? driverUid,
    String? driverName,
    double? driverRating,
    String? pickupName,
    String? dropoffName,
    double? pickupLat,
    double? pickupLng,
    double? dropoffLat,
    double? dropoffLng,
    double? amountNaira,
    double? finalFare,
    String? paymentStatus,
    DateTime? ratedAt,
    int? customerRating,
    String? customerRatingComment,
    DateTime? customerRatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? acceptedAt,
    DateTime? cancelledAt,
    String? startCode,
    String? receiverName,
    String? receiverPhone,
    String? deliveryPin,
  }) {
    return RideModel(
      id: id ?? this.id,
      customerUid: customerUid ?? this.customerUid,
      status: status ?? this.status,
      pickupLabel: pickupLabel ?? this.pickupLabel,
      dropoffLabel: dropoffLabel ?? this.dropoffLabel,
      rideType: rideType ?? this.rideType,
      customerOffer: customerOffer ?? this.customerOffer,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      driverUid: driverUid ?? this.driverUid,
      driverName: driverName ?? this.driverName,
      driverRating: driverRating ?? this.driverRating,
      pickupName: pickupName ?? this.pickupName,
      dropoffName: dropoffName ?? this.dropoffName,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      amountNaira: amountNaira ?? this.amountNaira,
      finalFare: finalFare ?? this.finalFare,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      ratedAt: ratedAt ?? this.ratedAt,
      customerRating: customerRating ?? this.customerRating,
      customerRatingComment: customerRatingComment ?? this.customerRatingComment,
      customerRatedAt: customerRatedAt ?? this.customerRatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      startCode: startCode ?? this.startCode,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      deliveryPin: deliveryPin ?? this.deliveryPin,
    );
  }

  factory RideModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final rawCustomerRating = data['customerRating'];
    final int? customerRating = switch (rawCustomerRating) {
      int v => v,
      num v => v.round(),
      _ => null,
    };
    return RideModel(
      id: id,
      customerUid: (data['customerUid'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'requested',
      pickupLabel:
          (data['pickupLabel'] as String?) ??
          (data['pickupName'] as String?) ??
          '',
      dropoffLabel:
          (data['dropoffLabel'] as String?) ??
          (data['dropoffName'] as String?) ??
          '',
      rideType: (data['rideType'] as String?) ?? 'Regular',
      customerOffer: (data['customerOffer'] as num?)?.toDouble() ?? 0,
      paymentMethod: (data['paymentMethod'] as String?) ?? 'cash',
      driverUid: data['driverUid'] as String?,
      driverName: data['driverName'] as String?,
      driverRating: (data['driverRating'] as num?)?.toDouble(),
      pickupName: data['pickupName'] as String?,
      dropoffName: data['dropoffName'] as String?,
      pickupLat: (data['pickupLat'] as num?)?.toDouble(),
      pickupLng: (data['pickupLng'] as num?)?.toDouble(),
      dropoffLat: (data['dropoffLat'] as num?)?.toDouble(),
      dropoffLng: (data['dropoffLng'] as num?)?.toDouble(),
      amountNaira: (data['amountNaira'] as num?)?.toDouble(),
      finalFare: (data['finalFare'] as num?)?.toDouble(),
      paymentStatus: data['paymentStatus'] as String?,
      ratedAt: (data['ratedAt'] as Timestamp?)?.toDate(),
      customerRating: customerRating,
      customerRatingComment: data['customerRatingComment'] as String?,
      customerRatedAt: (data['customerRatedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      startCode: data['startCode'] as String?,
      receiverName: data['receiverName'] as String?,
      receiverPhone: data['receiverPhone'] as String?,
      deliveryPin: data['deliveryPin'] as String?,
    );
  }
}
