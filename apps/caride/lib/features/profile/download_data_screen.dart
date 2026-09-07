import 'dart:async';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Download Data Screen.
class DownloadDataScreen extends StatefulWidget {
  const DownloadDataScreen({super.key});

  @override
  State<DownloadDataScreen> createState() => _DownloadDataScreenState();
}

class _DownloadDataScreenState extends State<DownloadDataScreen> {
  bool _requested = false;
  double _progress = 0.0;
  Timer? _timer;

  void _startMockDownload() {
    setState(() {
      _requested = true;
      _progress = 0.0;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) return;
      setState(() {
        _progress += 0.08;
        if (_progress >= 1.0) {
          _progress = 1.0;
          _timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
        title: 'Download My Data',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.brandGlass,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _progress >= 1.0 ? Icons.mark_email_read_outlined : Icons.insert_drive_file_outlined,
                    color: AppColors.brand,
                    size: 64,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  _progress >= 1.0 ? 'Data Request Sent' : 'Request a Copy of Your Data',
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _progress >= 1.0
                      ? 'We have compiled your personal data archive and sent the download link to your registered email address.'
                      : 'An archive file will be prepared containing your profile details, ride records, ratings history, transaction receipts, and customer support conversations.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_requested && _progress < 1.0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: LinearProgressIndicator(
                      value: _progress,
                      color: AppColors.brand,
                      backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade200,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Compiling archive: ${( _progress * 100 ).toStringAsFixed(0)}%',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else if (_progress >= 1.0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.brandGlass,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.brand, size: 16),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Check your inbox',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.brand,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                if (!_requested)
                  PrimaryButton(
                    label: 'Request Download',
                    onPressed: _startMockDownload,
                  )
                else if (_progress >= 1.0)
                  PrimaryButton(
                    label: 'Done',
                    onPressed: () => context.pop(),
                  )
                else
                  const PrimaryButton(
                    label: 'Preparing...',
                    onPressed: null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
