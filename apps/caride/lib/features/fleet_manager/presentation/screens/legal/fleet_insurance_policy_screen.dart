import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

/// Screen displaying the Insurance & Damage Liability Guidelines configured by Admin.
class FleetInsurancePolicyScreen extends StatelessWidget {
  const FleetInsurancePolicyScreen({super.key});

  static const String _defaultPolicy = '''
CARIDE - INSURANCE & DAMAGE LIABILITY GUIDELINES

1. MANDATORY COMMERCIAL INSURANCE
- All fleet vehicles listed on CaRide must maintain comprehensive or statutory commercial third-party insurance coverage through an accredited insurer.
- Policy documents, expiration dates, and vehicle registration numbers must be uploaded and kept current in the Fleet Manager portal.

2. DAMAGE REPORTING & ESCROW CLAIMS
- In case of client-caused damage, fleet managers must submit photographic evidence and an incident report within 24 hours of vehicle return.
- Security deposit claims will be reviewed by CaRide claims adjusters before disbursement.

3. THIRD-PARTY LIABILITIES & INDEMNIFICATION
- CaRide acts solely as an intermediary reservation and dispatch platform.
- Fleet Partners agree to indemnify and hold harmless CaRide against claims arising from unroadworthy vehicle defects or unauthorized driver actions.
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
                      'Insurance & Liability',
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
                  final customText = snapshot.data?.data()?['fleetInsurancePolicy'] as String?;
                  final textContent = (customText != null && customText.trim().isNotEmpty)
                      ? customText
                      : _defaultPolicy;

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
