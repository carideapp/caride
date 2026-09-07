import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Onboarding Screen with unified glass layout.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'Welcome to CaRide - Your Journey, Your Way.',
      'subtitle':
          "Get ready to experience hassle-free transportation. We've got everything you need to travel with ease. Let's get started",
      'image': 'lib/assets/1.png',
    },
    {
      'title': 'Select your preferred mode of transportation',
      'subtitle':
          'motorbike / scooter, or car - and order a ride with just a few taps',
      'image': 'lib/assets/2.png',
    },
    {
      'title': 'Say hello to convenient payments.',
      'subtitle':
          'Pay for your rides securely using CaRide Wallet, Bank transfer, Card, and USDT.',
      'image': 'lib/assets/3.png',
    },
  ];

  void _next() {
    if (_currentIndex < _onboardingData.length - 1) {
      _pageController.nextPage(
        duration: AppDurations.normal,
        curve: Curves.easeInOut,
      );
    } else {
      context.go(CustomerRoutePaths.welcome);
    }
  }

  void _skip() {
    context.go(CustomerRoutePaths.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLast = _currentIndex == _onboardingData.length - 1;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Column(
        children: [
          // Graphic section
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.elliptical(
                    MediaQuery.sizeOf(context).width,
                    70,
                  ),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  child: AnimatedSwitcher(
                    duration: AppDurations.normal,
                    child: Transform.scale(
                      scale: 0.8,
                      alignment: Alignment.bottomCenter,
                      child: Image.asset(
                        _onboardingData[_currentIndex]['image']!,
                        key: ValueKey<int>(_currentIndex),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Content section
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) =>
                          setState(() => _currentIndex = index),
                      itemCount: _onboardingData.length,
                      itemBuilder: (context, index) {
                        return Column(
                          children: [
                            Text(
                              _onboardingData[index]['title']!,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.headlineMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _onboardingData[index]['subtitle']!,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _onboardingData.length,
                      (index) => AnimatedContainer(
                        duration: AppDurations.fast,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentIndex == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentIndex == index
                              ? AppColors.brand
                              : (isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Buttons
                  Row(
                    children: [
                      if (!isLast)
                        Expanded(
                          child: GhostButton(
                            label: 'Skip',
                            onPressed: _skip,
                          ),
                        ),
                      if (!isLast) const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: PrimaryButton(
                          label: isLast ? 'Get Started' : 'Continue',
                          onPressed: _next,
                        ),
                      ),
                    ],
                  ),
                  const SafeArea(child: SizedBox(height: AppSpacing.md)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
