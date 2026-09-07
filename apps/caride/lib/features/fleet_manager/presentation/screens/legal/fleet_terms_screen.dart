import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

/// Screen displaying the Fleet Partner Terms of Use configured dynamically by Admin.
class FleetTermsScreen extends StatelessWidget {
  const FleetTermsScreen({super.key});

  static const String _defaultTerms = '''
CARIDE NIGERIA - FLEET PARTNER TERMS OF USE

1. INTRODUCTION & SCOPE
These Terms of Use govern the registration, listing, and commercial operations of Fleet Partners on the CaRide platform. By listing vehicles or managing chauffeurs on CaRide, you agree to comply with all terms herein.

2. FLEET PARTNER QUALIFICATION & COMPLIANCE
- All listed vehicles must have valid federal and state roadworthiness certifications, vehicle licenses, and commercial comprehensive or third-party insurance.
- Fleet Partners must verify that all assigned chauffeurs possess valid Nigerian driver's licenses and clear background vetting.

3. BOOKINGS & COMMISSION
- CaRide connects verified Fleet Partners with corporate and individual vehicle rental clients.
- Partner payouts are disbursed automatically to verified settlement bank accounts upon verified trip or booking completion.
- CaRide deducts standard agreed platform commission fees per rental transaction.

4. CANCELLATION, REFUND & FORFEITURE
- Fleet Partners must ensure designated vehicles are delivered in clean, fueled, and roadworthy condition at scheduled pickup times.
- Unauthorized cancellations or non-availability of confirmed vehicles may incur partner penalty deductions.

5. AMENDMENTS & GOVERNING LAW
CaRide reserves the right to modify these operational terms. Continued use of the platform constitutes acceptance of updated terms under the laws of the Federal Republic of Nigeria.
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
                      'Terms of Use',
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
                  final customText = snapshot.data?.data()?['fleetTerms'] as String?;
                  final textContent = (customText != null && customText.trim().isNotEmpty)
                      ? customText
                      : _defaultTerms;

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
