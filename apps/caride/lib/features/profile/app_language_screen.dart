import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Redesigned Customer App Language Screen.
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
    'Mandarin Chinese',
    'Hindi',
    'Arabic',
    'Bengali',
    'Portuguese',
    'Russian',
    'Japanese',
    'German',
    'French',
    'Urdu',
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: 'App Language',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.pagePadding),
            child: GlassContainer(
              padding: EdgeInsets.zero,
              child: ListView.separated(
                itemCount: _languages.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                ),
                itemBuilder: (context, index) {
                  final language = _languages[index];
                  final isSelected = language == _selectedLanguage;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _saveLanguage(language),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                language,
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isSelected) const Icon(Icons.check, color: AppColors.brand),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
