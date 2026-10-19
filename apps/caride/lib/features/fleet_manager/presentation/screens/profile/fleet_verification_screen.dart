import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:caride/features/fleet_manager/controllers/fleet_manager_controller.dart';

/// Screen displaying partner verification / KYC status and document submissions.
class FleetVerificationScreen extends StatefulWidget {
  const FleetVerificationScreen({super.key});

  @override
  State<FleetVerificationScreen> createState() => _FleetVerificationScreenState();
}

class _FleetVerificationScreenState extends State<FleetVerificationScreen> {
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
                      'Partner Verification & KYC',
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

            // ── Main Content ──
            Expanded(
              child: ListenableBuilder(
                listenable: fleetManagerController,
                builder: (context, _) {
                  final profile = fleetManagerController.currentProfile ??
                      const FleetProfile(
                        fleetId: '',
                        ownerUid: '',
                        businessName: 'CaRide Fleet Partner',
                        phone: '',
                        email: '',
                      );

                  final isVerified = profile.isVerified || profile.verificationStatus == 'approved';
                  final isPending = profile.verificationStatus == 'pending' && !profile.isVerified;
                  final isCompany = profile.businessType == 'company';

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Status Banner Card ──
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isVerified
                                ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                                : isPending
                                    ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB))
                                    : (isDark ? const Color(0xFF3F1414) : const Color(0xFFFEF2F2)),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isVerified
                                  ? AppColors.brand.withValues(alpha: 0.4)
                                  : isPending
                                      ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                                      : AppColors.error.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isVerified
                                      ? AppColors.brand
                                      : isPending
                                          ? const Color(0xFFF59E0B)
                                          : AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isVerified
                                      ? Icons.verified_rounded
                                      : isPending
                                          ? Icons.schedule_rounded
                                          : Icons.error_outline_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isVerified
                                          ? 'Verified Fleet Partner'
                                          : isPending
                                              ? 'Verification in Progress'
                                              : 'Action Required',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: isVerified
                                            ? (isDark ? Colors.white : const Color(0xFF065F46))
                                            : isPending
                                                ? (isDark ? Colors.white : const Color(0xFF92400E))
                                                : (isDark ? Colors.white : const Color(0xFF991B1B)),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isVerified
                                          ? 'All commercial vehicle listings and chauffeur dispatch services are fully authorized.'
                                          : isPending
                                              ? 'Our compliance team is verifying your ${isCompany ? 'corporate CAC and identity' : 'identity'} credentials (typically 12-24 hours).'
                                              : (profile.rejectionReason ?? 'Please update your uploaded documents to proceed.'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.35,
                                        color: isVerified
                                            ? (isDark ? Colors.white70 : const Color(0xFF047857))
                                            : isPending
                                                ? (isDark ? Colors.white70 : const Color(0xFFB45309))
                                                : (isDark ? Colors.white70 : const Color(0xFFB91C1C)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Entity Structure Summary ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Operating Entity: ${isCompany ? 'Registered Company' : 'Individual Operator'}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: primaryTextColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                if (isVerified) {
                                  context.push(FleetRoutePaths.viewBusinessInfo);
                                } else {
                                  context.push(FleetRoutePaths.businessInfo);
                                }
                              },
                              child: Text(
                                isVerified ? 'View Details' : 'Edit Details',
                                style: const TextStyle(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Text(
                          'KYC Document Submissions',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Verified regulatory credentials for Nigerian fleet operations.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Document 1: Government Identity ──
                        _buildDocItem(
                          title: isCompany ? 'Representative Identity Document' : 'Government Identity Document',
                          subtitle: profile.identityDocumentUrl != null && profile.identityDocumentUrl!.isNotEmpty
                              ? '${profile.fullName.isNotEmpty ? '${profile.fullName} • ' : ''}${profile.identityDocumentType ?? 'ID Document'} • Uploaded'
                              : 'National ID (NIN) / Driver\'s License / Passport',
                          status: isVerified
                              ? 'Verified'
                              : (profile.identityDocumentUrl != null && profile.identityDocumentUrl!.isNotEmpty
                                  ? 'Under Review'
                                  : 'Missing'),
                          statusColor: isVerified
                              ? AppColors.brand
                              : (profile.identityDocumentUrl != null && profile.identityDocumentUrl!.isNotEmpty
                                  ? const Color(0xFFF59E0B)
                                  : AppColors.error),
                          icon: Icons.person_pin_rounded,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          onAction: () => context.push(
                            isVerified ? FleetRoutePaths.viewBusinessInfo : FleetRoutePaths.businessInfo,
                          ),
                        ),

                        // ── Document 2: CAC Incorporation (If Company) ──
                        if (isCompany) ...[
                          _buildDocItem(
                            title: 'CAC Incorporation Certificate',
                            subtitle: profile.registrationNumber.isNotEmpty
                                ? 'RC / BN: ${profile.registrationNumber}'
                                : 'Corporate Affairs Commission Document',
                            status: isVerified
                                ? 'Verified'
                                : (profile.cacDocumentUrl != null && profile.cacDocumentUrl!.isNotEmpty
                                    ? 'Under Review'
                                    : 'Missing'),
                            statusColor: isVerified
                                ? AppColors.brand
                                : (profile.cacDocumentUrl != null && profile.cacDocumentUrl!.isNotEmpty
                                    ? const Color(0xFFF59E0B)
                                    : AppColors.error),
                            icon: Icons.domain_rounded,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            onAction: () => context.push(
                              isVerified ? FleetRoutePaths.viewBusinessInfo : FleetRoutePaths.businessInfo,
                            ),
                          ),
                        ],

                        // ── Document 3: Operating States ──
                        _buildDocItem(
                          title: 'Operating Dispatch States',
                          subtitle: profile.operatingStates.isNotEmpty
                              ? profile.operatingStates.join(', ')
                              : 'No operating territory configured',
                          status: profile.operatingStates.isNotEmpty
                              ? '${profile.operatingStates.length} Active'
                              : 'Missing',
                          statusColor: profile.operatingStates.isNotEmpty
                              ? AppColors.brand
                              : AppColors.error,
                          icon: Icons.map_rounded,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          onAction: () => context.push(FleetRoutePaths.operatingStates),
                        ),

                        // ── Document 4: Residential / Office Address ──
                        _buildDocItem(
                          title: isCompany ? 'Registered Office Address' : 'Residentail / Office address',
                          subtitle: profile.address.isNotEmpty
                              ? profile.address
                              : 'No address specified',
                          status: profile.address.isNotEmpty ? 'Recorded' : 'Pending',
                          statusColor: profile.address.isNotEmpty ? AppColors.brand : const Color(0xFF9CA3AF),
                          icon: Icons.pin_drop_rounded,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          onAction: () => context.push(
                            isCompany
                                ? (isVerified ? FleetRoutePaths.viewBusinessInfo : FleetRoutePaths.businessInfo)
                                : FleetRoutePaths.profileDetails,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Quick Update CTA Button (Green Pill) ──
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            icon: Icon(
                              isVerified ? Icons.visibility_outlined : Icons.cloud_upload_outlined,
                              size: 20,
                            ),
                            label: Text(
                              isVerified ? 'View Business Info & Documents' : 'Update Business Info & Documents',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () => context.push(
                              isVerified ? FleetRoutePaths.viewBusinessInfo : FleetRoutePaths.businessInfo,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
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

  Widget _buildDocItem({
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required IconData icon,
    required bool isDark,
    required Color primaryTextColor,
    required VoidCallback onAction,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.brand, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
