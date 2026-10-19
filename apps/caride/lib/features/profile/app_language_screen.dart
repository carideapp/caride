import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimalist Customer App Language Screen adhering to CaRide Profile design standards.
class AppLanguageScreen extends StatefulWidget {
  const AppLanguageScreen({super.key});

  @override
  State<AppLanguageScreen> createState() => _AppLanguageScreenState();
}

class _AppLanguageScreenState extends State<AppLanguageScreen> {
  String _selectedLanguage = 'English';

  final List<String> _languages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Arabic',
    'Portuguese',
    'Mandarin Chinese',
    'Hindi',
    'Japanese',
    'Russian',
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('customer_app_language');
      if (lang != null && mounted) {
        setState(() => _selectedLanguage = lang);
      }
    } catch (_) {}
  }

  Future<void> _saveLanguage(String lang) async {
    setState(() => _selectedLanguage = lang);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_app_language', lang);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: 50,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top App Bar with Circular Back Button
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'App Language',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Grouped Language Options Card
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  children: List.generate(_languages.length, (index) {
                    final language = _languages[index];
                    final isSelected = language == _selectedLanguage;
                    final isLast = index == _languages.length - 1;

                    return Column(
                      children: [
                        InkWell(
                          onTap: () => _saveLanguage(language),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    language,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? AppColors.brand : primaryTextColor,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_rounded,
                                    color: AppColors.brand,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (!isLast) _buildDivider(isDark),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Divider(
        height: 1,
        color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
      ),
    );
  }
}
