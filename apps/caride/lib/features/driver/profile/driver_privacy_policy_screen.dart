import 'package:caride/features/profile/widgets/legal_document_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverPrivacyPolicyScreen extends StatelessWidget {
  const DriverPrivacyPolicyScreen({super.key});

  static const String _defaultPrivacy = '''
CARIDE SMARTTRANSIT LTD - DRIVER PRIVACY POLICY

1. INFORMATION WE COLLECT
We collect personal information you provide during registration and online operation, including:
- Driver identity: Name, phone number, email address, profile picture, Driver's Licence, National Identification Number (NIN).
- Vehicle details: Proof of ownership, vehicle registration, roadworthiness certificates, insurance policies, vehicle photos.
- Location data: Precise GPS location collected while your app status is Online, active duty, or during trips.
- Payment & Earnings: Bank account details, wallet transactions, trip commission records.

2. HOW WE USE YOUR INFORMATION
Your information is used to:
- Verify identity, background checks, and commercial driving authorization.
- Match you with nearby passenger ride requests and courier pick-up orders.
- Calculate completed trip fares, driver commission tier levels (Bronze, Silver, Gold, Platinum), and issue payouts.
- Ensure community safety, monitor speed/route compliance, and investigate incident reports.

3. DATA SHARING WITH RIDERS & PARTNERS
- Riders receive your name, photo, vehicle make/model/color/license plate, phone number, and average rating during active bookings.
- We do not sell your personal data to third parties.

4. DATA SECURITY & BACKGROUND LOCATION
- Driver location data is collected in the background while your Driver App is set to Online to maintain live trip tracking, route assistance, and emergency SOS functionality.
- Industry-standard encryption safeguards all driver records.

5. YOUR PRIVACY RIGHTS
You may access, update, or request deletion of your driver profile data by contacting privacy@caride.ng.
''';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: 'Privacy Policy',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('config')
                .doc('legalSettings')
                .snapshots(),
            builder: (context, snapshot) {
              final customPrivacy = snapshot.data?.data()?['driverPrivacy'] as String?;
              final textContent = (customPrivacy != null && customPrivacy.trim().isNotEmpty)
                  ? customPrivacy
                  : _defaultPrivacy;

              return LegalDocumentView(
                title: 'Privacy Policy',
                subtitle: 'Driver Data Protections & Privacy Rights',
                icon: Icons.privacy_tip_outlined,
                rawContent: textContent,
                badgeLabel: 'Driver Privacy',
              );
            },
          ),
        ),
      ),
    );
  }
}
