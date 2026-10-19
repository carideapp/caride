import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';
import 'package:intl/intl.dart';

/// Minimalist, spacy blog reader screen for educational "For you" articles.
///
/// Designed with generous line height, pill back button, category badge,
/// reading time indicator, and distraction-free typography for effortless readability.
class ForYouArticleDetailScreen extends StatelessWidget {
  const ForYouArticleDetailScreen({
    super.key,
    required this.article,
  });

  final ForYouArticle article;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final bodyTextColor =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final surfaceColor =
        isDark ? AppColors.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE2E8F0);

    final dateFormatted = article.createdAt != null
        ? DateFormat('MMMM dd, yyyy').format(article.createdAt!)
        : 'Recently published';

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Navigation Bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Circular back pill button (per AGENTS.md)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  Text(
                    'For You',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                  // Placeholder action pill (Share/Bookmark)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(
                      Icons.bookmark_border_rounded,
                      size: 20,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: borderColor),

            // ── Scrollable Article Body ─────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Badge + Read Time
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            article.category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brand,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '•  ${article.readTime}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Article Title
                    Text(
                      article.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                        letterSpacing: -0.5,
                        height: 1.25,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Published Date & Author metadata
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.brand,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              'C',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'CaRide Editorial  •  $dateFormatted',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // Large Hero Cover Image
                    if (article.coverImageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 230),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Image.network(
                            article.coverImageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholderHero(isDark),
                          ),
                        ),
                      )
                    else
                      _placeholderHero(isDark),

                    const SizedBox(height: 26),

                    // Short Summary / Lead Paragraph
                    if (article.shortDescription.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.brand.withValues(alpha: 0.08)
                              : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.brand.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 20,
                              color: AppColors.brand,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                article.shortDescription,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFF86EFAC)
                                      : const Color(0xFF166534),
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Full Article Body (Spacy typography)
                    _buildFormattedContent(
                      content: article.content,
                      primaryTextColor: primaryTextColor,
                      bodyTextColor: bodyTextColor,
                      isDark: isDark,
                      borderColor: borderColor,
                    ),

                    const SizedBox(height: 40),

                    // Footer signature
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Enjoyed this? Share with fellow CaRide passengers',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderHero(bool isDark) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 54,
          color: AppColors.brand,
        ),
      ),
    );
  }

  /// Parses paragraphs, markdown headings, and bullet points cleanly.
  Widget _buildFormattedContent({
    required String content,
    required Color primaryTextColor,
    required Color bodyTextColor,
    required bool isDark,
    required Color borderColor,
  }) {
    if (content.trim().isEmpty) {
      return Text(
        'Content coming soon...',
        style: TextStyle(
          fontSize: 15,
          color: bodyTextColor,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final paragraphs = content.split(RegExp(r'\n\s*\n'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((rawPara) {
        final para = rawPara.trim();
        if (para.isEmpty) return const SizedBox.shrink();

        // Check if heading (starts with ## or #)
        if (para.startsWith('### ') || para.startsWith('## ') || para.startsWith('# ')) {
          final headingText = para.replaceAll(RegExp(r'^#+\s*'), '');
          return Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: Text(
              headingText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
                letterSpacing: -0.3,
                height: 1.3,
              ),
            ),
          );
        }

        // Check if bullet point block
        if (para.contains('\n* ') || para.contains('\n- ') || para.startsWith('* ') || para.startsWith('- ')) {
          final lines = para.split('\n');
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines.map((line) {
                final cleanLine = line.replaceAll(RegExp(r'^[\*\-]\s*'), '').trim();
                if (cleanLine.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 8, right: 12),
                        decoration: const BoxDecoration(
                          color: AppColors.brand,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          cleanLine,
                          style: TextStyle(
                            fontSize: 15,
                            color: bodyTextColor,
                            height: 1.6,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        }

        // Standard body paragraph
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            para,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w400,
              color: bodyTextColor,
              height: 1.68,
              letterSpacing: 0.1,
            ),
          ),
        );
      }).toList(),
    );
  }
}
