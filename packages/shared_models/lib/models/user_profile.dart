import 'user_role.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.rating,
    this.completedRides,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? avatarUrl;
  final double? rating;
  final int? completedRides;
}
