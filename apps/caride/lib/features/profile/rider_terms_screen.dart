import 'package:caride/features/profile/widgets/legal_document_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Rider Terms of Use Screen with dynamic Firestore configuration.
class RiderTermsScreen extends StatelessWidget {
  const RiderTermsScreen({super.key});

  static const String _defaultTerms = '''
CARIDE SMARTTRANSIT LTD - GENERAL TERMS OF USE

1. INTRODUCTION & SCOPE
Welcome to CaRide. By accessing or using our passenger application, you agree to comply with and be bound by these Terms of Use.

2. USER ELIGIBILITY & ACCOUNTS
- You must be at least 18 years old to create a CaRide rider account.
- Account details must remain accurate, complete, and up to date.
- You are responsible for maintaining the confidentiality of your account credentials.

3. RIDE REQUESTS & NEGOTIATED FARES
- Passengers propose fares for trip requests. Drivers may accept, decline, or submit counteroffers.
- You agree to pay the confirmed fare for completed trips, including any applicable tolls, taxes, or approved extras.

4. PASSENGER CONDUCT & OBLIGATIONS
- Treat all drivers, passengers, and community members with respect.
- Prohibited activities include violence, harassment, smoking, vehicle damage, or carrying illegal substances.
- Violations may result in immediate account suspension or termination.

5. CANCELLATIONS & FEES
- You may cancel a ride request prior to driver arrival.
- Repeated cancellations after driver dispatch may attract a standard cancellation fee to compensate drivers.

6. SAFETY & SUPPORT
- CaRide features emergency SOS sharing, live trip monitoring, and 24/7 support.
- Contact support immediately for lost items or safety concerns during a trip.
''';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: 'Terms of Use',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('config')
                .doc('legalSettings')
                .snapshots(),
            builder: (context, snapshot) {
              final customTerms = snapshot.data?.data()?['riderTerms'] as String?;
              final textContent = (customTerms != null && customTerms.trim().isNotEmpty)
                  ? customTerms
                  : _defaultTerms;

              return LegalDocumentView(
                title: 'Terms of Use',
                subtitle: 'Passenger Terms & Service Agreements',
                icon: Icons.gavel_rounded,
                rawContent: textContent,
                badgeLabel: 'Rider Terms',
              );
            },
          ),
        ),
      ),
    );
  }
}
