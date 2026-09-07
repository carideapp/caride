import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

enum LegalBlockType {
  sectionHeader,
  subHeader,
  paragraph,
  bulletItem,
  calloutBox,
}

class LegalBlock {
  final LegalBlockType type;
  final String text;

  const LegalBlock({
    required this.type,
    required this.text,
  });
}

/// Parses plain text or markdown legal text into structured visual blocks.
List<LegalBlock> parseLegalText(String content) {
  final lines = content.split('\n');
  final blocks = <LegalBlock>[];
  final StringBuffer currentParagraph = StringBuffer();

  void flushParagraph() {
    if (currentParagraph.isNotEmpty) {
      final text = currentParagraph.toString().trim();
      if (text.isNotEmpty) {
        blocks.add(LegalBlock(type: LegalBlockType.paragraph, text: text));
      }
      currentParagraph.clear();
    }
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) {
      flushParagraph();
      continue;
    }

    // Header matching (e.g., "1. OUR PLATFORM", "1.1 Tech", "SECTION 1", "## Title", ALL CAPS headers)
    final isMainSectionHeader = RegExp(r'^\d+\.\s+[A-Z0-9\s\,\-\&\(\)]+$').hasMatch(line) ||
        RegExp(r'^SECTION\s+\d+', caseSensitive: false).hasMatch(line) ||
        RegExp(r'^#\s+').hasMatch(line) ||
        (line.length >= 3 && line.length <= 60 && line.toUpperCase() == line && !line.startsWith('*') && !line.startsWith('-') && !line.startsWith('•'));

    final isSubHeader = RegExp(r'^\d+\.\d+\s+').hasMatch(line) ||
        RegExp(r'^##+\s+').hasMatch(line) ||
        RegExp(r'^\d+\.\s+[A-Za-z]').hasMatch(line);

    final isBullet = line.startsWith('*') ||
        line.startsWith('•') ||
        line.startsWith('-') ||
        RegExp(r'^\([a-z0-9]+\)\s+').hasMatch(line);

    final isCallout = line.startsWith('>') ||
        line.toLowerCase().startsWith('welcome to') ||
        line.toLowerCase().startsWith('important:') ||
        line.toUpperCase() == 'ACCEPTANCE';

    if (isMainSectionHeader) {
      flushParagraph();
      blocks.add(LegalBlock(
        type: LegalBlockType.sectionHeader,
        text: line.replaceAll(RegExp(r'^#+\s*'), ''),
      ));
    } else if (isSubHeader) {
      flushParagraph();
      blocks.add(LegalBlock(
        type: LegalBlockType.subHeader,
        text: line.replaceAll(RegExp(r'^#+\s*'), ''),
      ));
    } else if (isBullet) {
      flushParagraph();
      final cleanText = line
          .replaceAll(RegExp(r'^[\*\•\-]\s*'), '')
          .replaceAll(RegExp(r'^\([a-z0-9]+\)\s*'), '');
      blocks.add(LegalBlock(type: LegalBlockType.bulletItem, text: cleanText));
    } else if (isCallout) {
      flushParagraph();
      final cleanText = line.replaceAll(RegExp(r'^>\s*'), '');
      blocks.add(LegalBlock(type: LegalBlockType.calloutBox, text: cleanText));
    } else {
      if (currentParagraph.isNotEmpty) {
        currentParagraph.write(' ');
      }
      currentParagraph.write(line);
    }
  }

  flushParagraph();
  return blocks;
}

/// Executive, responsive legal document view with structured sections, badges, and clean typography.
class LegalDocumentView extends StatelessWidget {
  const LegalDocumentView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.rawContent,
    this.lastUpdated = '13 August 2026',
    this.badgeLabel = 'Official Policy',
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String rawContent;
  final String lastUpdated;
  final String badgeLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blocks = parseLegalText(rawContent);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero Card Banner
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.brand.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: AppColors.brand,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandGlass,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppColors.brand.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  badgeLabel,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.brand,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: AppTextStyles.headlineSmall.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Divider(
                  color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Updated: $lastUpdated',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 14,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'CaRide Legal',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.brand,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Render Document Blocks
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: blocks.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final block = blocks[index];
              return _buildBlock(context, block, isDark);
            },
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildBlock(BuildContext context, LegalBlock block, bool isDark) {
    switch (block.type) {
      case LegalBlockType.sectionHeader:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                block.text,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.slate900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 2,
                width: 24,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        );

      case LegalBlockType.subHeader:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: 2),
          child: Text(
            block.text,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.brand,
            ),
          ),
        );

      case LegalBlockType.bulletItem:
        return Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  block.text,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );

      case LegalBlockType.calloutBox:
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.brand,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  block.text,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
              ),
            ],
          ),
        );

      case LegalBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            block.text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              height: 1.6,
            ),
          ),
        );
    }
  }
}
