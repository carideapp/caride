import 'package:caride/features/profile/widgets/legal_document_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Rider Privacy Policy Screen with dynamic Firestore configuration.
class RiderPrivacyPolicyScreen extends StatelessWidget {
  const RiderPrivacyPolicyScreen({super.key});

  static const String _defaultPrivacy = '''
CARIDE SMARTTRANSIT LTD - PRIVACY POLICY

1. DATA COLLECTION
We collect personal information necessary to deliver safe, negotiated, and reliable transport services, including:
- Account details: Full name, phone number, email address, profile picture.
- Location data: Real-time GPS location collected during ride booking and active trips.
- Payment information: Card tokens, transaction receipts, wallet records.

2. USAGE OF INFORMATION
Your data is processed to:
- Connect you with nearby matched drivers based on your fare proposals.
- Calculate trip distances, fares, and navigation routes.
- Verify user identity, prevent fraudulent transactions, and enhance safety.
- Communicate trip updates, payment receipts, and customer service responses.

3. INFORMATION SHARING
- Drivers receive your name, pickup location, destination, and rating during active bookings.
- We do not sell your personal data to third parties.

4. DATA SECURITY & STORAGE
We employ industry-standard encryption standards to secure your personal data against unauthorized access.

5. YOUR RIGHTS
You can request access, corrections, or deletion of your personal account data at any time by contacting privacy@caride.ng.
''';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 14, bottom: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('config')
                    .doc('legalSettings')
                    .snapshots(),
                builder: (context, snapshot) {
                  final customPrivacy = snapshot.data?.data()?['riderPrivacy'] as String?;
                  final textContent = (customPrivacy != null && customPrivacy.trim().isNotEmpty)
                      ? customPrivacy
                      : _defaultPrivacy;

                  return LegalDocumentView(
                    title: 'Privacy Policy',
                    subtitle: 'Passenger Data Practices & Privacy Rights',
                    icon: Icons.privacy_tip_outlined,
                    rawContent: textContent,
                    badgeLabel: 'Rider Privacy',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
