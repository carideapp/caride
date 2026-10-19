import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:caride/features/fleet_manager/controllers/fleet_manager_controller.dart';
import 'package:caride/features/fleet_manager/auth/controllers/fleet_auth_controller.dart';

/// Screen for managing fleet operational territories and vehicle dispatch coverage states.
class FleetOperatingStatesScreen extends StatefulWidget {
  const FleetOperatingStatesScreen({super.key});

  @override
  State<FleetOperatingStatesScreen> createState() => _FleetOperatingStatesScreenState();
}

class _FleetOperatingStatesScreenState extends State<FleetOperatingStatesScreen> {
  List<String> _selectedStates = ['FCT (Abuja)'];
  String? _errorMessage;
  bool _isSaving = false;

  static const _popularStates = [
    'FCT (Abuja)',
    'Lagos',
    'Rivers',
    'Oyo',
    'Kano',
    'Enugu',
    'Edo',
    'Delta',
    'Imo',
    'Kaduna',
    'Cross River',
    'Akwa Ibom',
    'Anambra',
    'Ogun',
  ];

  static const _allNigerianStates = [
    'Abia',
    'Adamawa',
    'Akwa Ibom',
    'Anambra',
    'Bauchi',
    'Bayelsa',
    'Benue',
    'Borno',
    'Cross River',
    'Delta',
    'Ebonyi',
    'Edo',
    'Ekiti',
    'Enugu',
    'FCT (Abuja)',
    'Gombe',
    'Imo',
    'Jigawa',
    'Kaduna',
    'Kano',
    'Katsina',
    'Kebbi',
    'Kogi',
    'Kwara',
    'Lagos',
    'Nasarawa',
    'Niger',
    'Ogun',
    'Ondo',
    'Osun',
    'Oyo',
    'Plateau',
    'Rivers',
    'Sokoto',
    'Taraba',
    'Yobe',
    'Zamfara',
  ];

  @override
  void initState() {
    super.initState();
    final profile = fleetManagerController.currentProfile;

    if (profile?.operatingStates != null && profile!.operatingStates.isNotEmpty) {
      _selectedStates = profile.operatingStates
          .map((s) => s == 'Abuja' ? 'FCT (Abuja)' : s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
    } else if (profile?.state != null && profile!.state.isNotEmpty) {
      _selectedStates = profile.state
          .split(',')
          .map((s) => s.trim() == 'Abuja' ? 'FCT (Abuja)' : s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
    }

    if (_selectedStates.isEmpty) {
      _selectedStates = ['FCT (Abuja)'];
    }
  }

  void _toggleState(String stateName) {
    setState(() {
      _errorMessage = null;
      if (_selectedStates.contains(stateName)) {
        if (_selectedStates.length > 1) {
          _selectedStates.remove(stateName);
        } else {
          const msg = 'At least one operating state is required for dispatch coverage.';
          _errorMessage = msg;
          _showErrorSnackBar(msg);
        }
      } else {
        _selectedStates.add(stateName);
      }
    });
  }

  void _addStateFromDropdown(String? stateName) {
    if (stateName == null || stateName.isEmpty) return;
    setState(() {
      _errorMessage = null;
      if (!_selectedStates.contains(stateName)) {
        _selectedStates.add(stateName);
      }
    });
  }

  Future<void> _handleSave() async {
    setState(() => _errorMessage = null);

    if (_selectedStates.isEmpty) {
      const msg = 'Please select at least one operating state.';
      setState(() => _errorMessage = msg);
      _showErrorSnackBar(msg);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? '';
      final current = fleetManagerController.currentProfile;

      final updatedProfile = (current ??
              FleetProfile(
                fleetId: uid,
                ownerUid: uid,
                businessName: 'CaRide Fleet Partner',
                phone: '',
                email: user?.email ?? '',
              ))
          .copyWith(
        state: _selectedStates.first,
        operatingStates: _selectedStates,
        city: _selectedStates.first,
        operatingCities: _selectedStates,
        updatedAt: DateTime.now(),
      );

      // Save to Fleet Controller & Firestore
      await fleetManagerController.saveFleetProfile(updatedProfile);

      // Also persist to draft state
      await fleetAuthController.saveSignupDraft();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Operating states updated successfully!'),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

      context.pop();
    } catch (e) {
      if (!mounted) return;
      const humanError = 'Failed to update operating states. Please check your connection and retry.';
      setState(() => _errorMessage = humanError);
      _showErrorSnackBar(humanError);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black;

    final dropdownAvailableStates = _allNigerianStates
        .where((s) => !_selectedStates.contains(s))
        .toList();

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
                      'Operating States',
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

            // ── Content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dual In-View Error Banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF3F1414) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Action Required',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.error,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : const Color(0xFF991B1B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                              onPressed: () => setState(() => _errorMessage = null),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    Text(
                      'Operating States (Multiple Selection)',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select all Nigerian states where your vehicles and chauffeurs will be available for dispatch.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Add State Dropdown List ──
                    Text(
                      'Add Operating State from Dropdown',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimaryDark : const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: null,
                          hint: Row(
                            children: [
                              const Icon(Icons.add_location_alt_outlined, size: 20, color: AppColors.brand),
                              const SizedBox(width: 10),
                              Text(
                                'Select state to add...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                          isExpanded: true,
                          dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                          items: dropdownAvailableStates
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s, style: TextStyle(color: primaryTextColor, fontSize: 15)),
                                  ))
                              .toList(),
                          onChanged: _addStateFromDropdown,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Selected States Display ──
                    Text(
                      'Selected Operating States (${_selectedStates.length}) *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimaryDark : const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: _selectedStates.map((stateName) {
                        return Container(
                          padding: const EdgeInsets.only(left: 14, right: 6, top: 6, bottom: 6),
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                stateName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _toggleState(stateName),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.white24,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // ── Popular States Quick-Select ──
                    Text(
                      'Quick Add Major States',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimaryDark : const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _popularStates.map((st) {
                        final isSelected = _selectedStates.contains(st);
                        return InkWell(
                          onTap: () => _toggleState(st),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.brand.withValues(alpha: 0.15)
                                  : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.brand
                                    : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                  color: isSelected ? AppColors.brand : const Color(0xFF9CA3AF),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  st,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.brand
                                        : (isDark ? Colors.white70 : const Color(0xFF374151)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 36),

                    // ── Save Button (Green Pill) ──
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: _isSaving ? null : _handleSave,
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text(
                                'Save Operating States',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
