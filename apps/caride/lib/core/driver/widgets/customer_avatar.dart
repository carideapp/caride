import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class CustomerAvatar extends StatelessWidget {
  const CustomerAvatar({
    super.key,
    required this.customerUid,
    required this.fallbackLetter,
    this.radius = 20,
  });

  final String customerUid;
  final String fallbackLetter;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (customerUid.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
        child: Text(
          fallbackLetter.isNotEmpty ? fallbackLetter[0].toUpperCase() : 'C',
          style: TextStyle(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.9,
          ),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('customers')
          .doc(customerUid)
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final photoUrl = data?['photoUrl'] as String? ?? '';

        final fallbackWidget = Text(
          fallbackLetter.isNotEmpty ? fallbackLetter[0].toUpperCase() : 'C',
          style: TextStyle(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.9,
          ),
        );

        if (photoUrl.isNotEmpty) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
            backgroundImage: NetworkImage(photoUrl),
            onBackgroundImageError: (_, __) {},
            child: fallbackWidget,
          );
        }

        return CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
          child: fallbackWidget,
        );
      },
    );
  }
}
