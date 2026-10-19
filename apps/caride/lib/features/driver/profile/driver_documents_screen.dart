import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/driver/models/driver_document.dart';
import 'package:caride/core/driver/models/driver_profile.dart';
import 'package:caride/core/driver/models/vehicle_info.dart';
import 'package:caride/core/driver/verification/driver_verification_config.dart';
import 'package:caride/features/driver/auth/data/driver_profile_repository.dart';
import 'package:caride/features/driver/profile/data/driver_document_repository.dart';
import 'package:caride/features/driver/profile/driver_vehicle_photo_screen.dart';
import 'package:caride/features/driver/profile/driver_vehicle_registration_screen.dart';
import 'package:caride/features/driver/profile/driver_generic_document_upload_screen.dart';
import 'package:caride/features/driver/profile/driver_rider_permit_screen.dart';
import 'package:caride/features/driver/profile/guarantor_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverDocumentsScreen extends StatefulWidget {
  const DriverDocumentsScreen({super.key});

  @override
  State<DriverDocumentsScreen> createState() => _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends State<DriverDocumentsScreen> {
  final _documentRepo = DriverDocumentRepository();
  final _profileRepo = DriverProfileRepository();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);
    final uid = driverAuthController.currentUid;

    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Documents',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: StreamBuilder<DriverProfile?>(
            stream: _profileRepo.streamDriverProfile(uid),
            builder: (context, profileSnapshot) {
              final driverProfile = profileSnapshot.data;
              return StreamBuilder<VehicleInfo?>(
                stream: _profileRepo.streamVehicleInfo(uid),
                builder: (context, snapshot) {
                  final vehicle = snapshot.data;
                  if (vehicle == null) {
                    return ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.lg,
                      ),
                      children: [
                        EmptyState(
                          title: 'Vehicle information required',
                          message:
                              'Submit your vehicle information first before you upload verification documents.',
                          icon: Icons.drive_eta_rounded,
                          action: PrimaryButton(
                            label: 'Add Vehicle Info',
                            onPressed: () =>
                                context.push(DriverRoutePaths.profileVehicle),
                          ),
                        ),
                      ],
                    );
                  }

                  final requiredDocs = requiredDocumentsForVehicleType(
                    vehicle.vehicleType,
                    operatingState: driverProfile?.state,
                  );

              return StreamBuilder<List<DriverDocument>>(
                stream: _documentRepo.streamDocuments(uid),
                builder: (context, docsSnapshot) {
                  final docs = docsSnapshot.data ?? [];
                  final docMap = {for (final d in docs) d.documentType: d};

                  // Helper: for vehicle_photo tile, both front+back must be approved
                  bool isVehiclePhotoApproved() {
                    final front = docMap['vehicle_photo_front'];
                    final back = docMap['vehicle_photo_back'];
                    return front?.isApproved == true && back?.isApproved == true;
                  }

                  String? vehiclePhotoStatus() {
                    final front = docMap['vehicle_photo_front'];
                    final back = docMap['vehicle_photo_back'];
                    if (front == null && back == null) return null;
                    if (front?.isApproved == true && back?.isApproved == true) return 'approved';
                    if (front?.status == 'rejected' || back?.status == 'rejected') return 'rejected';
                    if (front != null || back != null) return 'pending';
                    return null;
                  }

                  final approvedCount = requiredDocs.where((item) {
                    if (item.type == 'vehicle_photo') return isVehiclePhotoApproved();
                    return docMap[item.type]?.isApproved == true;
                  }).length;

                  final completionRatio = requiredDocs.isEmpty ? 0.0 : approvedCount / requiredDocs.length;
                  final percentage = (completionRatio * 100).round();

                  return ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    children: [
                      // Header Progress Glass Card
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: borderColor),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Row(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: CircularProgressIndicator(
                                    value: completionRatio,
                                    strokeWidth: 6,
                                    backgroundColor: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                                  ),
                                ),
                                Text(
                                  '$percentage%',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppColors.slate900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Verification Progress',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : AppColors.slate900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$approvedCount of ${requiredDocs.length} documents approved. Upload remaining files to proceed.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Document Checklist Card Container
                      Container(
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: borderColor),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Column(
                          children: List.generate(requiredDocs.length, (i) {
                            final definition = requiredDocs[i];
                            final DriverDocument? doc = definition.type == 'vehicle_photo'
                                ? null
                                : docMap[definition.type];
                            final String? vehicleStatus = definition.type == 'vehicle_photo'
                                ? vehiclePhotoStatus()
                                : null;
                            
                            final isLast = i == requiredDocs.length - 1;

                            return Column(
                              children: [
                                _DocumentTile(
                                  definition: definition,
                                  doc: doc,
                                  overrideStatus: vehicleStatus,
                                ),
                                if (!isLast)
                                  Divider(
                                    height: 1,
                                    indent: 72,
                                    endIndent: 16,
                                    color: borderColor,
                                  ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    ),
  ),
);
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.definition,
    this.doc,
    this.overrideStatus,
  });

  final DriverDocumentDefinition definition;
  final DriverDocument? doc;
  /// When non-null, this status is used instead of doc?.status.
  final String? overrideStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final status = overrideStatus ?? doc?.status ?? 'not_uploaded';

    // Premium status display text and icon decorators
    final (statusLabel, statusColor, showWarning) = switch (status) {
      'approved' => ('Approved', AppColors.primaryGreen, false),
      'pending' => ('Under Review', const Color(0xFFF59E0B), false),
      'rejected' => ('Fix Document', const Color(0xFFEF4444), true),
      _ => ('Upload', isDark ? Colors.white60 : const Color(0xFF4A4D70), false),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (status == 'approved') {
            _showVerifiedBottomSheet(context);
            return;
          }
          if (definition.type == 'profile_photo') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DriverGenericDocumentUploadScreen(
                  documentType: 'profile_photo',
                  title: 'Profile Photo',
                  instruction: 'Upload a clear headshot selfie for your profile. Make sure your face is fully visible, well-lit, and in focus.',
                  correctAsset: 'lib/assets/profile_photo_correct.png',
                ),
              ),
            );
          } else if (definition.type == 'vehicle_photo') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DriverVehiclePhotoScreen(),
              ),
            );
          } else if (definition.type == 'vehicle_registration') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DriverVehicleRegistrationScreen(),
              ),
            );
          } else if (definition.type == 'rider_permit') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DriverRiderPermitScreen(),
              ),
            );
          } else if (definition.type == 'national_id') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DriverGenericDocumentUploadScreen(
                  documentType: 'national_id',
                  title: 'National ID',
                  instruction: 'Upload a clear picture of your NIN slip/card, Voter’s Card, or International Passport.',
                  correctAsset: 'lib/assets/national_id_correct.png',
                  fadedAsset: 'lib/assets/national_id_faded.png',
                  halfAsset: 'lib/assets/national_id_half.png',
                  blurAsset: 'lib/assets/national_id_blur.png',
                ),
              ),
            );
          } else if (definition.type == 'proof_of_address') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DriverGenericDocumentUploadScreen(
                  documentType: 'proof_of_address',
                  title: 'Proof of Address',
                  instruction: 'Upload a recent utility bill (electricity, water, waste), tenancy agreement, or verifiable address document.',
                  correctAsset: 'lib/assets/proof_of_address_correct.png',
                  fadedAsset: 'lib/assets/proof_of_address_faded.png',
                  halfAsset: 'lib/assets/proof_of_address_half.png',
                  blurAsset: 'lib/assets/proof_of_address_blur.png',
                ),
              ),
            );
          } else if (definition.type == 'proof_of_ownership') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DriverGenericDocumentUploadScreen(
                  documentType: 'proof_of_ownership',
                  title: 'Proof of Ownership',
                  instruction: 'Upload receipt of purchase, transfer document, or owner’s authorization letter if the car is not in your name.',
                  correctAsset: 'lib/assets/proof_of_ownership_correct.png',
                  fadedAsset: 'lib/assets/proof_of_ownership_faded.png',
                  halfAsset: 'lib/assets/proof_of_ownership_half.png',
                  blurAsset: 'lib/assets/proof_of_ownership_blur.png',
                ),
              ),
            );
          } else if (definition.type == 'road_worthiness') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DriverGenericDocumentUploadScreen(
                  documentType: 'road_worthiness',
                  title: 'Road Worthiness Certificate',
                  instruction: 'Upload your current Road Worthiness Certificate issued by the appropriate transport authority.',
                  correctAsset: 'lib/assets/road_worthiness_correct.png',
                  fadedAsset: 'lib/assets/proof_of_insurance_faded.png',
                  halfAsset: 'lib/assets/proof_of_insurance_half.png',
                  blurAsset: 'lib/assets/proof_of_insurance_blur.png',
                ),
              ),
            );
          } else if (definition.type == 'guarantor_info') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DriverGuarantorInfoScreen(),
              ),
            );
          } else if (definition.type == 'drivers_license') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DriverGenericDocumentUploadScreen(
                  documentType: 'drivers_license',
                  title: "Driver's Licence",
                  instruction: 'Take a selfie holding your driver license or ID next to your face. Make sure your face and information on your document are clearly visible.',
                  correctAsset: 'lib/assets/drivers_license_correct.png',
                  fadedAsset: 'lib/assets/drivers_license_faded.png',
                  halfAsset: 'lib/assets/drivers_license_half.png',
                  blurAsset: 'lib/assets/drivers_license_blur.png',
                ),
              ),
            );
          } else if (definition.type == 'proof_of_insurance') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DriverGenericDocumentUploadScreen(
                  documentType: 'proof_of_insurance',
                  title: 'Proof of Insurance',
                  instruction: 'Upload a picture of your active insurance certificate or cover note. Make sure all details are clearly visible.',
                  correctAsset: 'lib/assets/proof_of_insurance_correct.png',
                  fadedAsset: 'lib/assets/proof_of_insurance_faded.png',
                  halfAsset: 'lib/assets/proof_of_insurance_half.png',
                  blurAsset: 'lib/assets/proof_of_insurance_blur.png',
                ),
              ),
            );
          } else if (definition.type == 'lasdri_card') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DriverGenericDocumentUploadScreen(
                  documentType: 'lasdri_card',
                  title: 'LASDRI Card',
                  instruction: 'Upload a clear picture of your Lagos State Drivers Institute (LASDRI) recertification card.',
                  correctAsset: 'lib/assets/drivers_license_correct.png',
                  fadedAsset: 'lib/assets/drivers_license_faded.png',
                  halfAsset: 'lib/assets/drivers_license_half.png',
                  blurAsset: 'lib/assets/drivers_license_blur.png',
                ),
              ),
            );
          } else {
            context.push(
              Uri(
                path: DriverRoutePaths.documentUpload,
                queryParameters: {
                  'title': definition.label,
                  'type': definition.type,
                },
              ).toString(),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  // Icon indicator
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: status == 'approved'
                              ? AppColors.primaryGreen.withValues(alpha: 0.08)
                              : (isDark ? Colors.white54.withValues(alpha: 0.05) : const Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          definition.icon,
                          color: status == 'approved' ? AppColors.primaryGreen : (isDark ? Colors.white70 : const Color(0xFF4A4D70)),
                          size: 22,
                        ),
                      ),
                      if (status == 'approved')
                        const Positioned(
                          bottom: -2,
                          right: -2,
                          child: CircleAvatar(
                            radius: 8,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 7,
                              backgroundColor: AppColors.primaryGreen,
                              child: Icon(Icons.check_rounded, color: Colors.white, size: 10),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Texts
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          definition.label,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                        if (definition.description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            definition.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: mutedTextColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Action Button / Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: status == 'rejected'
                          ? const Color(0xFFEF4444)
                          : (status == 'pending'
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                              : (status == 'approved'
                                  ? AppColors.primaryGreen.withValues(alpha: 0.1)
                                  : (isDark ? Colors.white12 : const Color(0xFFF3F4F6)))),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (status == 'pending') ...[
                          const Icon(Icons.schedule_rounded, color: Color(0xFFF59E0B), size: 14),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: status == 'rejected'
                                ? Colors.white
                                : statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Rejected Reason Container Box
              if (showWarning && doc?.rejectionReason != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          doc!.rejectionReason!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFEF4444),
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showVerifiedBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.primaryGreen,
                  size: 36,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Document Verified',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.slate900,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your documents are already verified. You can start accepting rides.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey[300] : const Color(0xFF4A4D70),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Okay',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
