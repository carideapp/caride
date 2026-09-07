import 'dart:async';
import 'dart:io';
import 'package:caride/core/config/app_env.dart';
import 'package:caride/features/home_map/data/mapbox_search_service.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:caride/features/fleet_manager/controllers/fleet_manager_controller.dart';
import 'package:caride/features/fleet_manager/auth/controllers/fleet_auth_controller.dart';
import 'package:caride/features/fleet_manager/auth/data/fleet_auth_repository.dart';
import 'package:caride/features/fleet_manager/widgets/fleet_document_picker.dart';

/// Screen for managing registered fleet business entity info, operating states, and uploading verification documents.
class FleetBusinessInfoScreen extends StatefulWidget {
  const FleetBusinessInfoScreen({super.key});

  @override
  State<FleetBusinessInfoScreen> createState() => _FleetBusinessInfoScreenState();
}

class _FleetBusinessInfoScreenState extends State<FleetBusinessInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _businessType; // 'individual' or 'company'
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _companyNameController;
  late final TextEditingController _rcNumberController;
  late final TextEditingController _addressController;

  // Google Places API Autocomplete State
  late final MapboxSearchService _searchService;
  List<MapboxPlace> _addressSuggestions = [];
  bool _isSearchingAddress = false;
  Timer? _addressDebounceTimer;

  String _gender = 'Male';
  String _identityDocumentType = 'NIN Slip';
  File? _identityDocumentFile;
  File? _companyLogoFile;
  File? _cacDocumentFile;
  List<String> _selectedStates = ['FCT (Abuja)'];

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

  static const _genderOptions = ['Male', 'Female', 'Other'];
  static const _idDocumentTypes = [
    'NIN Slip',
    'International Passport',
    'Voter\'s Card',
    'Driver\'s License',
  ];

  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _searchService = MapboxSearchService(AppEnv.googleMapsApiKey);
    final profile = fleetManagerController.currentProfile;

    _businessType = profile?.businessType == 'company' ? 'company' : 'individual';
    _fullNameController = TextEditingController(text: profile?.fullName ?? '');
    _phoneController = TextEditingController(text: profile?.phone ?? '');
    _companyNameController = TextEditingController(text: profile?.businessName ?? '');
    _rcNumberController = TextEditingController(text: profile?.registrationNumber ?? '');
    _addressController = TextEditingController(text: profile?.address ?? '');

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
    if (_selectedStates.isEmpty) _selectedStates = ['FCT (Abuja)'];

    if (profile?.gender != null && profile!.gender!.isNotEmpty) {
      _gender = profile.gender!;
    }
    if (profile?.identityDocumentType != null && profile!.identityDocumentType!.isNotEmpty) {
      _identityDocumentType = profile.identityDocumentType!;
    }
  }

  @override
  void dispose() {
    _addressDebounceTimer?.cancel();
    _fullNameController.dispose();
    _phoneController.dispose();
    _companyNameController.dispose();
    _rcNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onAddressChanged(String query) {
    _addressDebounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _addressSuggestions = [];
        _isSearchingAddress = false;
      });
      return;
    }

    _addressDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isSearchingAddress = true);
      try {
        final results = await _searchService.searchPlaces(query.trim());
        if (!mounted) return;
        setState(() {
          _addressSuggestions = results;
          _isSearchingAddress = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _addressSuggestions = [];
          _isSearchingAddress = false;
        });
      }
    });
  }

  void _toggleState(String stateName) {
    setState(() {
      if (_selectedStates.contains(stateName)) {
        if (_selectedStates.length > 1) {
          _selectedStates.remove(stateName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('At least one operating state is required.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
        }
      } else {
        _selectedStates.add(stateName);
      }
    });
  }

  void _addStateFromDropdown(String? stateName) {
    if (stateName == null || stateName.isEmpty) return;
    setState(() {
      if (!_selectedStates.contains(stateName)) {
        _selectedStates.add(stateName);
      }
    });
  }

  Future<void> _handleSave() async {
    setState(() => _errorMessage = null);
    final current = fleetManagerController.currentProfile;
    final isCompany = _businessType == 'company';

    // 1. Validate Text Form Fields
    if (_fullNameController.text.trim().isEmpty) {
      const msg = 'Please enter your Full Name.';
      setState(() => _errorMessage = msg);
      _showErrorSnackBar(msg);
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      const msg = 'Please enter your Phone Number.';
      setState(() => _errorMessage = msg);
      _showErrorSnackBar(msg);
      return;
    }

    if (isCompany && _companyNameController.text.trim().isEmpty) {
      const msg = 'Please enter your Registered Company Name.';
      setState(() => _errorMessage = msg);
      _showErrorSnackBar(msg);
      return;
    }

    if (isCompany && _rcNumberController.text.trim().isEmpty) {
      const msg = 'Please enter your CAC / RC Registration Number.';
      setState(() => _errorMessage = msg);
      _showErrorSnackBar(msg);
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      final msg = isCompany
          ? 'Please enter your Full Company Address.'
          : 'Please enter your Residential / Operating Address.';
      setState(() => _errorMessage = msg);
      _showErrorSnackBar(msg);
      return;
    }

    // 2. Validate Operating States
    if (_selectedStates.isEmpty) {
      const msg = 'Please select at least one operating state.';
      setState(() => _errorMessage = msg);
      _showErrorSnackBar(msg);
      return;
    }

    // 3. Validate Identity Document (Required for all)
    final hasIdentityDoc = _identityDocumentFile != null ||
        (current?.identityDocumentUrl != null && current!.identityDocumentUrl!.isNotEmpty);
    if (!hasIdentityDoc) {
      final msg = 'Please upload a clear copy of your Identity Document ($_identityDocumentType).';
      setState(() => _errorMessage = msg);
      _showErrorSnackBar(msg);
      return;
    }

    // 4. Validate Company Documents (Logo & CAC required if Company)
    if (isCompany) {
      final hasLogo = _companyLogoFile != null ||
          (current?.logoUrl != null && current!.logoUrl!.isNotEmpty);
      if (!hasLogo) {
        const msg = 'Please upload your Official Company Logo.';
        setState(() => _errorMessage = msg);
        _showErrorSnackBar(msg);
        return;
      }

      final hasCacDoc = _cacDocumentFile != null ||
          (current?.cacDocumentUrl != null && current!.cacDocumentUrl!.isNotEmpty);
      if (!hasCacDoc) {
        const msg = 'Please upload your CAC Registration Document.';
        setState(() => _errorMessage = msg);
        _showErrorSnackBar(msg);
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? '';

      // Upload newly selected files if present
      String? identityUrl = current?.identityDocumentUrl;
      String? cacUrl = current?.cacDocumentUrl;
      String? logoUrl = current?.logoUrl;

      if (_identityDocumentFile != null) {
        identityUrl = await fleetAuthRepository.uploadFleetDocument(
          uid: uid,
          docName: 'identity_doc',
          file: _identityDocumentFile!,
        );
      }

      if (isCompany && _companyLogoFile != null) {
        logoUrl = await fleetAuthRepository.uploadFleetDocument(
          uid: uid,
          docName: 'company_logo',
          file: _companyLogoFile!,
        );
      }

      if (isCompany && _cacDocumentFile != null) {
        cacUrl = await fleetAuthRepository.uploadFleetDocument(
          uid: uid,
          docName: 'cac_doc',
          file: _cacDocumentFile!,
        );
      }

      final updatedProfile = (current ??
              FleetProfile(
                fleetId: uid,
                ownerUid: uid,
                businessName: isCompany ? _companyNameController.text.trim() : _fullNameController.text.trim(),
                phone: _phoneController.text.trim(),
                email: user?.email ?? '',
              ))
          .copyWith(
        businessType: _businessType,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        gender: _gender,
        businessName: isCompany ? _companyNameController.text.trim() : _fullNameController.text.trim(),
        registrationNumber: isCompany ? _rcNumberController.text.trim() : '',
        address: _addressController.text.trim(),
        state: _selectedStates.first,
        operatingStates: _selectedStates,
        city: _selectedStates.first,
        operatingCities: _selectedStates,
        logoUrl: isCompany ? logoUrl : null,
        identityDocumentType: _identityDocumentType,
        identityDocumentUrl: identityUrl,
        identityDocumentStatus: 'pending',
        cacDocumentUrl: isCompany ? cacUrl : null,
        cacDocumentStatus: isCompany ? 'pending' : null,
        verificationStatus: 'pending',
        isVerified: false,
        updatedAt: DateTime.now(),
      );

      // Save to Fleet Controller & Firestore
      await fleetManagerController.saveFleetProfile(updatedProfile);

      // Also sync draft
      fleetAuthController.businessType = _businessType;
      fleetAuthController.fullName = _fullNameController.text.trim();
      fleetAuthController.phone = _phoneController.text.trim();
      fleetAuthController.gender = _gender;
      fleetAuthController.companyName = isCompany ? _companyNameController.text.trim() : '';
      fleetAuthController.rcNumber = isCompany ? _rcNumberController.text.trim() : '';
      fleetAuthController.companyAddress = _addressController.text.trim();
      fleetAuthController.identityDocumentType = _identityDocumentType;
      await fleetAuthController.saveSignupDraft();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Business details and verification documents submitted! Status is pending approval from admin.',
          ),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

      context.pop();
    } catch (e) {
      if (!mounted) return;
      final humanError = 'Failed to update business details. Please check network connection and retry.';
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
    final isCompany = _businessType == 'company';
    final profile = fleetManagerController.currentProfile;

    // Filter available states for dropdown that are not already selected
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
                      'Business Info & Documents',
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

            // ── Form Content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // In-view Error Banner
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

                      // ── Section 1: Entity Structure Selection (Matching Onboarding) ──
                      _buildSectionTitle('Operating Entity Structure', isDark),
                      const SizedBox(height: 6),
                      Text(
                        'Select how your fleet operations are legally registered in Nigeria.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Individual Card
                      _buildBusinessTypeCard(
                        title: 'Individual Operator',
                        description: 'I operate vehicles independently under my personal name.',
                        icon: Icons.person_rounded,
                        isSelected: _businessType == 'individual',
                        isDark: isDark,
                        onTap: () {
                          setState(() => _businessType = 'individual');
                        },
                      ),
                      const SizedBox(height: 12),

                      // Company Card
                      _buildBusinessTypeCard(
                        title: 'Registered Company',
                        description: 'I operate a registered transport or vehicle rental business.',
                        icon: Icons.domain_rounded,
                        isSelected: _businessType == 'company',
                        isDark: isDark,
                        onTap: () {
                          setState(() => _businessType = 'company');
                        },
                      ),

                      const SizedBox(height: 28),

                      // ── Section 2: Personal / Representative Details ──
                      _buildSectionTitle(
                        isCompany ? 'Representative Details' : 'Owner Details',
                        isDark,
                      ),
                      const SizedBox(height: 14),

                      _buildFieldLabel('Full Name *', isDark),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _fullNameController,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required' : null,
                        decoration: _pillInputDecoration('e.g. Adebayo Ogunlesi', Icons.person_outline_rounded, isDark),
                      ),
                      const SizedBox(height: 16),

                      _buildFieldLabel('Phone Number *', isDark),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone Number is required' : null,
                        decoration: _pillInputDecoration('e.g. +234 801 234 5678', Icons.phone_outlined, isDark),
                      ),
                      const SizedBox(height: 16),

                      _buildFieldLabel('Gender', isDark),
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
                            value: _gender,
                            isExpanded: true,
                            dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                            items: _genderOptions
                                .map((g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(g, style: TextStyle(color: primaryTextColor, fontSize: 15)),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _gender = val);
                            },
                          ),
                        ),
                      ),

                      // ── Section 3: Company Details (If Company) ──
                      if (isCompany) ...[
                        const SizedBox(height: 28),
                        _buildSectionTitle('Company Information', isDark),
                        const SizedBox(height: 14),

                        _buildFieldLabel('Company Name *', isDark),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _companyNameController,
                          style: TextStyle(color: primaryTextColor, fontSize: 15),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Company Name is required' : null,
                          decoration: _pillInputDecoration('e.g. Apex Luxury Motors Ltd', Icons.business_rounded, isDark),
                        ),
                        const SizedBox(height: 16),

                        _buildFieldLabel('CAC / RC Number *', isDark),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _rcNumberController,
                          style: TextStyle(color: primaryTextColor, fontSize: 15),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'RC Number is required' : null,
                          decoration: _pillInputDecoration('e.g. RC 1234567', Icons.badge_outlined, isDark),
                        ),
                        const SizedBox(height: 16),

                        _buildFieldLabel('Full Company Address *', isDark),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _addressController,
                          style: TextStyle(color: primaryTextColor, fontSize: 15),
                          onChanged: _onAddressChanged,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Company Address is required' : null,
                          decoration: _pillInputDecoration('e.g. Plot 12, Garki II, Abuja', Icons.pin_drop_outlined, isDark),
                        ),
                        _buildAddressSuggestionsWidget(isDark, primaryTextColor),
                      ] else ...[
                        const SizedBox(height: 16),
                        _buildFieldLabel('Residential / Operating Address *', isDark),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _addressController,
                          style: TextStyle(color: primaryTextColor, fontSize: 15),
                          onChanged: _onAddressChanged,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Operating Address is required' : null,
                          decoration: _pillInputDecoration('e.g. 14 Crescent Road, Wuse 2', Icons.pin_drop_outlined, isDark),
                        ),
                        _buildAddressSuggestionsWidget(isDark, primaryTextColor),
                      ],

                      const SizedBox(height: 28),

                      // ── Section 4: Operating States Multi-Select ──
                      _buildSectionTitle('Operating States (Multiple Selection)', isDark),
                      const SizedBox(height: 4),
                      Text(
                        'Select all Nigerian states where your vehicles and chauffeurs will be available for dispatch.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Add State Dropdown List ──
                      _buildFieldLabel('Add Operating State from Dropdown', isDark),
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
                      const SizedBox(height: 16),

                      // ── Selected States Display ──
                      _buildFieldLabel('Selected Operating States (${_selectedStates.length}) *', isDark),
                      const SizedBox(height: 8),
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

                      const SizedBox(height: 16),

                      // ── Popular States Quick-Select ──
                      _buildFieldLabel('Quick Add Major States', isDark),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _popularStates.map((st) {
                          final isSelected = _selectedStates.contains(st);
                          return InkWell(
                            onTap: () => _toggleState(st),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

                      const SizedBox(height: 28),

                      // ── Section 5: Required Verification Documents ──
                      _buildSectionTitle('Required Verification Documents', isDark),
                      const SizedBox(height: 6),
                      Text(
                        'Upload clear, legible identity and regulatory credentials for admin review.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildFieldLabel('Identity Document Type *', isDark),
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
                            value: _identityDocumentType,
                            isExpanded: true,
                            dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                            items: _idDocumentTypes
                                .map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t, style: TextStyle(color: primaryTextColor, fontSize: 15)),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _identityDocumentType = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      FleetDocumentPicker(
                        title: 'Upload $_identityDocumentType',
                        description: 'Ensure your full name, photo, and ID number are clearly visible.',
                        initialFile: _identityDocumentFile,
                        initialUrl: profile?.identityDocumentUrl,
                        onFileSelected: (file) => setState(() => _identityDocumentFile = file),
                        onFileRemoved: () => setState(() => _identityDocumentFile = null),
                      ),
                      const SizedBox(height: 20),

                      if (isCompany) ...[
                        FleetDocumentPicker(
                          title: 'Upload Company Logo',
                          description: 'Official company or agency brand logo (PNG / JPG).',
                          initialFile: _companyLogoFile,
                          initialUrl: profile?.logoUrl,
                          onFileSelected: (file) => setState(() => _companyLogoFile = file),
                          onFileRemoved: () => setState(() => _companyLogoFile = null),
                        ),
                        const SizedBox(height: 20),
                        FleetDocumentPicker(
                          title: 'Upload CAC Registration Document',
                          description: 'Official CAC Certificate or Status Report for your company.',
                          initialFile: _cacDocumentFile,
                          initialUrl: profile?.cacDocumentUrl,
                          onFileSelected: (file) => setState(() => _cacDocumentFile = file),
                          onFileRemoved: () => setState(() => _cacDocumentFile = null),
                        ),
                        const SizedBox(height: 20),
                      ],

                      const SizedBox(height: 24),

                      // ── Save & Submit Button (Green Pill) ──
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
                                  'Save & Submit for Approval',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessTypeCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.brand.withValues(alpha: 0.08) : const Color(0xFFF0FDF4))
              : (isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.brand
                : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brand.withValues(alpha: 0.15)
                    : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.brand : const Color(0xFF6B7280),
                size: 24,
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
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isSelected
                          ? AppColors.brand
                          : (isDark ? Colors.white : const Color(0xFF111827)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.brand : const Color(0xFFD1D5DB),
                  width: 2,
                ),
                color: isSelected ? AppColors.brand : Colors.transparent,
              ),
              child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : Colors.black,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildFieldLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.textPrimaryDark : const Color(0xFF374151),
      ),
    );
  }

  InputDecoration _pillInputDecoration(String hint, IconData prefixIcon, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF9CA3AF),
        fontSize: 14,
      ),
      filled: true,
      fillColor: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
      prefixIcon: Icon(prefixIcon, color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280), size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: AppColors.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  Widget _buildAddressSuggestionsWidget(bool isDark, Color primaryTextColor) {
    if (_isSearchingAddress) {
      return const Padding(
        padding: EdgeInsets.only(top: 8, left: 12),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
            ),
            SizedBox(width: 8),
            Text(
              'Searching address via Google Places API...',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (_addressSuggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: _addressSuggestions.map((place) {
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            leading: const Icon(Icons.location_on_outlined, color: AppColors.brand, size: 20),
            title: Text(
              place.placeName,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryTextColor),
            ),
            onTap: () {
              setState(() {
                _addressController.text = place.placeName;
                _addressSuggestions = [];
              });
            },
          );
        }).toList(),
      ),
    );
  }
}
