import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

/// Screen displaying the Vehicle Rental & Chauffeur Protocol configured by Admin.
class FleetRentalProtocolScreen extends StatelessWidget {
  const FleetRentalProtocolScreen({super.key});

  static const String _defaultProtocol = '''
CARIDE - VEHICLE RENTAL & CHAUFFEUR PROTOCOL

1. VEHICLE HANDOVER & INSPECTION STANDARDS
- Before releasing any rental vehicle (self-drive or chauffeur), an initial condition checklist including odometer reading, fuel level, and exterior/interior condition must be verified.
- Upon return, a joint inspection must be performed. Any noted damages or fuel deficiencies must be recorded promptly.

2. CHAUFFEUR OPERATIONS & PROFESSIONAL CONDUCT
- Assigned chauffeurs must maintain high standards of professionalism, punctuality, and clean attire.
- Chauffeurs must follow designated client routes and adhere strictly to all national and state speed limits and traffic laws.
- Unscheduled chauffeur substitutions or unexcused delays are strictly prohibited.

3. MAINTENANCE & ROADWORTHINESS
- Fleet partners must perform regular mechanical servicing, tire checks, and AC maintenance on all active vehicles.
- Vehicles experiencing mechanical faults during an active rental must be promptly replaced with an equivalent or superior category vehicle within 60 minutes.

4. EMERGENCIES & ACCIDENTS
- In the event of a collision or mechanical breakdown, chauffeurs/partners must ensure client safety, initiate emergency SOS if needed, and file an incident report within 24 hours.
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
                      'Rental & Chauffeur Protocol',
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
                  final customText = snapshot.data?.data()?['fleetRentalProtocol'] as String?;
                  final textContent = (customText != null && customText.trim().isNotEmpty)
                      ? customText
                      : _defaultProtocol;

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
