import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

/// Screen displaying the Fleet Partner Privacy Policy configured by Admin.
class FleetPrivacyPolicyScreen extends StatelessWidget {
  const FleetPrivacyPolicyScreen({super.key});

  static const String _defaultPrivacy = '''
CARIDE - FLEET PARTNER PRIVACY POLICY

1. DATA COLLECTION & SCOPE
CaRide collects corporate registration documents, tax identifiers, vehicle telemetry, and chauffeur licensing data solely for platform dispatch, booking verification, and regulatory compliance under the Nigeria Data Protection Act (NDPA).

2. VEHICLE TELEMETRY & LOCATION DATA
- GPS and real-time location data are collected during active trips to facilitate navigation, dispatch accuracy, customer safety, and dispute resolution.
- Telemetry data is never sold or shared with unapproved third parties.

3. SECURITY & RETENTION
- Enterprise credentials, bank details, and financial settlement records are encrypted using industry-standard protocols.
- We retain partner data only for as long as necessary to fulfill contractual operations and legal accounting requirements.
''';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Navigation Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: primaryTextColor,
                      ),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Main Content from Firestore ──
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('config')
                    .doc('legalSettings')
                    .snapshots(),
                builder: (context, snapshot) {
                  final customText = snapshot.data?.data()?['fleetPrivacy'] as String?;
                  final textContent = (customText != null && customText.trim().isNotEmpty)
                      ? customText
                      : _defaultPrivacy;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Text(
                        textContent,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: isDark ? Colors.white70 : const Color(0xFF374151),
                        ),
                      ),
                    ),
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
