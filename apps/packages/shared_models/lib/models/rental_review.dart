class RentalReview {
  final String id;
  final String bookingId;
  final String vehicleId;
  final String vehicleTitle;
  final String customerId;
  final String customerName;
  final String? customerPhoto;
  final String fleetId;
  final double rating;
  final String comment;
  final int likeCount;
  final List<String> likedByUids;
  final DateTime? createdAt;

  const RentalReview({
    required this.id,
    required this.bookingId,
    required this.vehicleId,
    required this.vehicleTitle,
    required this.customerId,
    required this.customerName,
    this.customerPhoto,
    required this.fleetId,
    required this.rating,
    required this.comment,
    this.likeCount = 0,
    this.likedByUids = const [],
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookingId': bookingId,
      'vehicleId': vehicleId,
      'vehicleTitle': vehicleTitle,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhoto': customerPhoto,
      'fleetId': fleetId,
      'rating': rating,
      'comment': comment,
      'likeCount': likeCount,
      'likedByUids': likedByUids,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory RentalReview.fromMap(Map<String, dynamic> map, String id) {
    DateTime? created;
    final c = map['createdAt'];
    if (c != null) {
      if (c is String) {
        created = DateTime.tryParse(c);
      } else {
        try {
          created = (c as dynamic).toDate();
        } catch (_) {}
      }
    }

    final rawLikes = map['likedByUids'];
    final List<String> parsedLikedBy = rawLikes is List
        ? rawLikes.map((e) => e.toString()).toList()
        : const [];

    return RentalReview(
      id: id,
      bookingId: (map['bookingId'] as String?) ?? '',
      vehicleId: (map['vehicleId'] as String?) ?? '',
      vehicleTitle: (map['vehicleTitle'] as String?) ?? '',
      customerId: (map['customerId'] as String?) ?? '',
      customerName: (map['customerName'] as String?) ?? 'Customer',
      customerPhoto: map['customerPhoto'] as String?,
      fleetId: (map['fleetId'] as String?) ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      comment: (map['comment'] as String?) ?? '',
      likeCount: (map['likeCount'] as num?)?.toInt() ?? parsedLikedBy.length,
      likedByUids: parsedLikedBy,
      createdAt: created,
    );
  }
}
