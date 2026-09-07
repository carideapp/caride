import 'package:caride/features/profile/widgets/legal_document_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverTermsScreen extends StatelessWidget {
  const DriverTermsScreen({super.key});

  static const String _defaultTerms = '''
CARIDE SMARTTRANSIT LTD - DRIVER TERMS OF SERVICE

1. ABOUT CARIDE
CaRide is a technology mobility platform that connects passengers with independent drivers for transportation, courier, logistics, and rental services. CaRide does not employ drivers as employees unless stated otherwise by applicable law.

2. DRIVER ELIGIBILITY & REQUIREMENTS
Drivers using the Platform must:
- Be at least 18 years old and hold a valid Driver's Licence and National Identification Number (NIN).
- Maintain valid vehicle registration, proof of ownership or authorization, roadworthiness certificates, and commercial vehicle insurance.
- Keep registered vehicles safe, clean, and roadworthy at all times.
- Ensure that only the approved driver operates the vehicle registered to the account.

3. COMMISSIONS & DRIVER TIER SYSTEM
CaRide operates a performance tier commission structure:
- Bronze Tier (0–299 completed trips): 15% commission
- Silver Tier (300–599 completed trips, 4.0+ rating): 13% commission
- Gold Tier (600–899 completed trips, 4.5+ rating): 10% commission
- Platinum Tier (900+ completed trips, 4.7+ rating): 7% commission

4. NEGOTIATED FARES & PAYOUTS
- Passengers propose fares; drivers may accept, decline, or offer counterproposals.
- Driver earnings are credited to the CaRide Wallet after applicable commission deductions.
- Direct off-platform payment solicitations outside CaRide are strictly prohibited.

5. CANCELLATIONS & CODE OF CONDUCT
- Drivers must maintain professional, respectful conduct toward passengers.
- Repeated unexcused cancellations after trip acceptance may result in temporary tier downgrade or account investigation.
- Fraudulent activities, GPS manipulation, or duplicate account creation will result in immediate permanent account termination.

6. SAFETY & BACKGROUND LOCATION
- Driver background location is collected while Online to ensure live navigation, trip monitoring, SOS emergency safety, and accurate distance fare calculation.
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
        title: 'Terms of Service',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('config')
                .doc('legalSettings')
                .snapshots(),
            builder: (context, snapshot) {
              final customTerms = snapshot.data?.data()?['driverTerms'] as String?;
              final textContent = (customTerms != null && customTerms.trim().isNotEmpty)
                  ? customTerms
                  : _defaultTerms;

              return LegalDocumentView(
                title: 'Terms of Service',
                subtitle: 'Driver Partner Terms & Commission Policy',
                icon: Icons.gavel_rounded,
                rawContent: textContent,
                badgeLabel: 'Driver Terms',
              );
            },
          ),
        ),
      ),
    );
  }
}
