import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:caride/features/fleet_manager/controllers/fleet_manager_controller.dart';

/// Screen displaying approved Fleet Business Information and verified KYC documents summary,
/// with an "Edit Business Info" action navigating to the editing form.
class FleetViewBusinessInfoScreen extends StatelessWidget {
  const FleetViewBusinessInfoScreen({super.key});

  void _showImageZoomDialog(BuildContext context, String url, String title, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.65,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.brand,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Icon(Icons.broken_image_rounded, size: 48, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final cardBgColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
      body: SafeArea(
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

            final isCompany = profile.businessType == 'company';

            return Column(
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
                          border: Border.all(color: borderColor),
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
                          'Business Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => context.push(FleetRoutePaths.businessInfo),
                        icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.brand),
                        label: const Text(
                          'Edit',
                          style: TextStyle(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable Summary Content ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Verified Partner Banner ──
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.brand.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: AppColors.brand,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.verified_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Verified Business Partner',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF065F46),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Your commercial business entity and regulatory credentials are fully approved.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white70 : const Color(0xFF047857),
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ── Section 1: Entity Structure ──
                        Text(
                          'Operating Entity',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCompany ? Icons.domain_rounded : Icons.person_rounded,
                                  color: AppColors.brand,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isCompany ? 'Registered Corporate Company' : 'Individual Operator',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isCompany
                                          ? 'Registered commercial vehicle transport or leasing company.'
                                          : 'Independently operated vehicle owner & fleet operator.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Approved',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ── Section 2: Company Details / Registered Info ──
                        Text(
                          isCompany ? 'Company Details' : 'Operating Address',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isCompany) ...[
                                _buildSummaryItem(
                                  label: 'COMPANY NAME',
                                  value: profile.businessName.isNotEmpty ? profile.businessName : 'N/A',
                                  primaryTextColor: primaryTextColor,
                                  secondaryTextColor: secondaryTextColor,
                                ),
                                const Divider(height: 24),
                                _buildSummaryItem(
                                  label: 'CAC / RC REGISTRATION NUMBER',
                                  value: profile.registrationNumber.isNotEmpty ? profile.registrationNumber : 'N/A',
                                  primaryTextColor: primaryTextColor,
                                  secondaryTextColor: secondaryTextColor,
                                  isMonospace: true,
                                ),
                                const Divider(height: 24),
                                _buildSummaryItem(
                                  label: 'FULL COMPANY OFFICE ADDRESS',
                                  value: profile.address.isNotEmpty ? profile.address : 'N/A',
                                  primaryTextColor: primaryTextColor,
                                  secondaryTextColor: secondaryTextColor,
                                ),
                              ] else ...[
                                _buildSummaryItem(
                                  label: 'RESIDENTIAL / OPERATING ADDRESS',
                                  value: profile.address.isNotEmpty ? profile.address : 'No operating address specified',
                                  primaryTextColor: primaryTextColor,
                                  secondaryTextColor: secondaryTextColor,
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ── Section 3: Verified Verification Documents ──
                        Text(
                          'Verification Documents',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Officially verified regulatory and identification credentials.',
                          style: TextStyle(fontSize: 13, color: secondaryTextColor),
                        ),
                        const SizedBox(height: 12),

                        // Document: Identity Document
                        _buildDocumentCard(
                          context: context,
                          title: profile.identityDocumentType != null && profile.identityDocumentType!.isNotEmpty
                              ? profile.identityDocumentType!
                              : 'Identity Document',
                          imageUrl: profile.identityDocumentUrl,
                          status: profile.identityDocumentUrl != null ? 'Verified' : 'Missing',
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                          borderColor: borderColor,
                          cardBgColor: cardBgColor,
                        ),
                        const SizedBox(height: 12),

                        // Document: Company Logo (if company)
                        if (isCompany && profile.logoUrl != null && profile.logoUrl!.isNotEmpty) ...[
                          _buildDocumentCard(
                            context: context,
                            title: 'Official Company Logo',
                            imageUrl: profile.logoUrl,
                            status: 'Approved',
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            borderColor: borderColor,
                            cardBgColor: cardBgColor,
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Document: CAC Document (if company)
                        if (isCompany) ...[
                          _buildDocumentCard(
                            context: context,
                            title: 'CAC Registration Document',
                            imageUrl: profile.cacDocumentUrl,
                            status: profile.cacDocumentUrl != null ? 'Verified' : 'Missing',
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            borderColor: borderColor,
                            cardBgColor: cardBgColor,
                          ),
                          const SizedBox(height: 12),
                        ],

                        const SizedBox(height: 20),

                        // ── Edit Button (Green Pill) ──
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
                            icon: const Icon(Icons.edit_note_rounded, size: 20),
                            label: const Text(
                              'Edit Business Details & Documents',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () => context.push(FleetRoutePaths.businessInfo),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    bool isMonospace = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: secondaryTextColor,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: isMonospace ? 'monospace' : null,
            color: primaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentCard({
    required BuildContext context,
    required String title,
    required String? imageUrl,
    required String status,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
    required Color cardBgColor,
  }) {
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: hasImage ? () => _showImageZoomDialog(context, imageUrl, title, isDark) : null,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: hasImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.description_outlined, color: Color(0xFF9CA3AF), size: 24),
                      ),
                    )
                  : const Icon(Icons.description_outlined, color: Color(0xFF9CA3AF), size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasImage ? 'Document uploaded & verified' : 'No document file',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'Verified' || status == 'Approved'
                  ? AppColors.brand.withValues(alpha: 0.12)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: status == 'Verified' || status == 'Approved'
                    ? AppColors.brand
                    : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
