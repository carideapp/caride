import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:caride/features/chat/data/chat_repository.dart';
import 'package:caride/features/fleet_manager/controllers/fleet_manager_controller.dart';
import 'package:caride/features/fleet_manager/presentation/screens/chat/fleet_conversation_screen.dart';

/// Redesigned Fleet Booking Detail Screen matching the CaRide design-system.md standards.
class FleetBookingDetailScreen extends StatefulWidget {
  const FleetBookingDetailScreen({super.key, required this.booking});

  final RentalBooking booking;

  @override
  State<FleetBookingDetailScreen> createState() =>
      _FleetBookingDetailScreenState();
}

class _FleetBookingDetailScreenState extends State<FleetBookingDetailScreen> {
  late RentalBooking _booking;
  String _customerPhone = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _customerPhone = widget.booking.customerPhone;
    _fetchCustomerPhone();
  }

  Future<void> _fetchCustomerPhone() async {
    if (_booking.customerId.isEmpty) return;
    try {
      final custDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(_booking.customerId)
          .get();
      if (custDoc.exists) {
        final data = custDoc.data();
        final phone = (data?['phone'] ?? data?['phoneNumber']) as String?;
        if (phone != null && phone.trim().isNotEmpty && mounted) {
          setState(() {
            _customerPhone = phone.trim();
          });
          return;
        }
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_booking.customerId)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final phone = (data?['phone'] ?? data?['phoneNumber']) as String?;
        if (phone != null && phone.trim().isNotEmpty && mounted) {
          setState(() {
            _customerPhone = phone.trim();
          });
          return;
        }
      }
    } catch (_) {}
  }

  String _formatCustomerPhone(String rawPhone, bool isPaid) {
    final phone = rawPhone.trim();
    if (phone.isEmpty) return 'Not provided';
    if (isPaid) return phone;
    if (phone.length <= 4) return '****';
    return '${phone.substring(0, phone.length - 4)}****';
  }

  Future<void> _handleCallCustomer() async {
    final phone = _customerPhone.trim().isNotEmpty
        ? _customerPhone.trim()
        : _booking.customerPhone.trim();

    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Customer phone number is not available.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open phone dialer.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  Future<void> _handleChatCustomer() async {
    final customerPhone = _customerPhone.trim().isNotEmpty
        ? _customerPhone.trim()
        : _booking.customerPhone.trim();

    try {
      await ChatRepository().startOrGetRentalThread(
        bookingId: _booking.id,
        fleetId: _booking.fleetId,
        fleetName: fleetManagerController.currentProfile?.businessName ?? 'Fleet Partner',
        customerUid: _booking.customerId,
        customerName: _booking.customerName,
        vehicleTitle: _booking.vehicleTitle,
        customerPhoto: _booking.customerPhoto,
        vehicleImage: _booking.vehicleImage,
        fleetOwnerUid: fleetManagerController.currentProfile?.ownerUid,
        fleetLogo: fleetManagerController.currentProfile?.logoUrl,
      );
    } catch (e) {
      debugPrint('[FleetBookingDetailScreen] Init chat thread error: $e');
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FleetConversationScreen(
          threadId: 'rental_${_booking.id}',
          customerName: _booking.customerName,
          customerUid: _booking.customerId,
          customerPhone: customerPhone,
          vehicleTitle: _booking.vehicleTitle,
          bookingId: _booking.id,
        ),
      ),
    );
  }

  void _showAssignDriverModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drivers = fleetManagerController.drivers;
    FleetDriver? selectedDriver = drivers
        .where((d) => d.id == _booking.assignedDriverId)
        .firstOrNull;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48, height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _booking.isDriverAssigned ? 'Reassign Driver' : 'Assign Fleet Driver',
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (drivers.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                          SizedBox(width: 10),
                          Expanded(child: Text('No drivers linked to your fleet yet.', style: TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<FleetDriver>(
                          value: selectedDriver,
                          hint: const Text('Choose a driver', style: TextStyle(fontSize: 14)),
                          isExpanded: true,
                          dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                          items: drivers.map((d) {
                            return DropdownMenuItem(
                              value: d,
                              child: Text('${d.fullName} (${d.phone})', style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setModalState(() => selectedDriver = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      onPressed: selectedDriver == null ? null : () async {
                        Navigator.pop(ctx);
                        final messenger = ScaffoldMessenger.of(this.context);
                        setState(() => _isProcessing = true);
                        try {
                          final driverUidToAssign = selectedDriver!.driverUid.isNotEmpty
                              ? selectedDriver!.driverUid
                              : selectedDriver!.id;
                          await fleetManagerController.assignDriverToBooking(
                            _booking.id,
                            assignedDriverId: driverUidToAssign,
                            assignedDriverName: selectedDriver!.fullName,
                            assignedDriverPhone: selectedDriver!.phone,
                          );
                          if (!mounted) return;
                          setState(() {
                            _booking = _booking.copyWith(
                              assignedDriverId: driverUidToAssign,
                              assignedDriverName: selectedDriver!.fullName,
                              assignedDriverPhone: selectedDriver!.phone,
                              rentalTripStatus: RentalTripStatus.assigned,
                            );
                          });
                          messenger.showSnackBar(SnackBar(
                            content: const Text('Driver assigned! They have been notified.'),
                            backgroundColor: AppColors.brand,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ));
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ));
                        } finally {
                          if (mounted) setState(() => _isProcessing = false);
                        }
                      },
                      child: const Text('Save & Assign Driver', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showApproveModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogCtx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 16,
            bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 48, height: 4, decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.brand, size: 28),
              ),
              const SizedBox(height: 16),
              Text('Approve Booking', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 8),
              Text(
                'Approve this rental and notify the customer to complete payment?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => _isProcessing = true);
                    try {
                      await fleetManagerController.approveBookingForPayment(_booking.id);
                      if (!mounted) return;
                      setState(() => _booking = _booking.copyWith(status: RentalBookingStatus.awaitingPayment));
                      messenger.showSnackBar(SnackBar(
                        content: const Text('Booking approved! Customer notified to pay.'),
                        backgroundColor: AppColors.brand,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ));
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ));
                    } finally {
                      if (mounted) setState(() => _isProcessing = false);
                    }
                  },
                  child: const Text('Yes, Approve Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Cancel', style: TextStyle(color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280))),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeclineModal() {
    final reasonController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogCtx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Decline Booking',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Are you sure you want to decline booking for ${_booking.vehicleTitle}?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Reason (e.g. vehicle booked offline)',
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _isProcessing = true);
                  try {
                    await fleetManagerController.declineBooking(
                      _booking.id,
                      reason: reasonController.text.trim(),
                    );
                    if (!mounted) return;
                    setState(() => _booking = _booking.copyWith(status: RentalBookingStatus.cancelled));
                    messenger.showSnackBar(SnackBar(
                      content: const Text('Booking declined.'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ));
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ));
                  } finally {
                    if (mounted) setState(() => _isProcessing = false);
                  }
                },
                child: const Text('Yes, Decline Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text('Cancel', style: TextStyle(color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final dateFormat = DateFormat('EEE, MMM dd, yyyy • hh:mm a');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _booking.id.isNotEmpty
          ? FirebaseFirestore.instance
              .collection('rental_bookings')
              .doc(_booking.id)
              .snapshots()
          : null,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data();
          if (data != null) {
            _booking = RentalBooking.fromMap(data, _booking.id);
          }
        }

        final effectiveStartPin = (_booking.startPin != null &&
                _booking.startPin!.trim().isNotEmpty)
            ? _booking.startPin!.trim()
            : ((_booking.pickupPin != null &&
                    _booking.pickupPin!.trim().isNotEmpty)
                ? _booking.pickupPin!.trim()
                : null);

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
          body: SafeArea(
            child: Column(
              children: [
            // Top Bar with Circular Back Button & Title
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Order Details',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vehicle Info Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _booking.vehicleImage.isNotEmpty
                                ? Image.network(
                                    _booking.vehicleImage,
                                    width: 80,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _placeholder(),
                                  )
                                : _placeholder(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _booking.vehicleTitle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.brand.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _booking.serviceType.label,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.brand,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Customer Details
                    _buildSectionCard(
                      title: 'Customer Information',
                      isDark: isDark,
                      primaryTextColor: primaryTextColor,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.brand.withValues(alpha: 0.12),
                              backgroundImage: (_booking.customerPhoto != null &&
                                      _booking.customerPhoto!.isNotEmpty)
                                  ? NetworkImage(_booking.customerPhoto!)
                                  : null,
                              child: (_booking.customerPhoto == null ||
                                      _booking.customerPhoto!.isEmpty)
                                  ? Text(
                                      _booking.customerName.trim().isNotEmpty
                                          ? _booking.customerName
                                              .trim()
                                              .substring(0, 1)
                                              .toUpperCase()
                                          : 'C',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.brand,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _booking.customerName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatCustomerPhone(
                                      _customerPhone,
                                      _booking.paymentStatus.trim().toLowerCase() == 'paid',
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Call Customer',
                              icon: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.phone_rounded,
                                  color: AppColors.brand,
                                  size: 19,
                                ),
                              ),
                              onPressed: _handleCallCustomer,
                            ),
                            IconButton(
                              tooltip: 'Chat with Customer',
                              icon: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: AppColors.brand,
                                  size: 19,
                                ),
                              ),
                              onPressed: _handleChatCustomer,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Self-Drive Verification Details Card (View-Only for Fleet Manager)
                    if (_booking.serviceType == RentalServiceType.selfDrive ||
                        _booking.driversLicenseNumber != null) ...[
                      _buildSectionCard(
                        title: 'Self-Drive Identity & License Verification',
                        isDark: isDark,
                        primaryTextColor: primaryTextColor,
                        children: [
                          _buildRow(
                            'Driver\'s License No.',
                            (_booking.driversLicenseNumber != null &&
                                    _booking.driversLicenseNumber!.isNotEmpty)
                                ? _booking.driversLicenseNumber!
                                : 'Not provided',
                            isDark,
                          ),
                          _buildRow(
                            'Government ID Type',
                            (_booking.identityDocumentType != null &&
                                    _booking.identityDocumentType!.isNotEmpty)
                                ? _booking.identityDocumentType!
                                : 'Not specified',
                            isDark,
                          ),
                          const SizedBox(height: 8),
                          _buildDocumentPreviewTile(
                            label: 'Driver\'s License Photo',
                            imageUrl: _booking.driversLicenseUrl,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                          ),
                          const SizedBox(height: 8),
                          _buildDocumentPreviewTile(
                            label: '${_booking.identityDocumentType ?? "Government ID"} Photo',
                            imageUrl: _booking.identityDocumentUrl,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Vehicle Pickup / Trip Start PIN Card (Fleet Manager View) ──────
                    if (effectiveStartPin != null && effectiveStartPin.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                              : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.brand.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.brand.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.pin_rounded, color: AppColors.brand, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _booking.serviceType == RentalServiceType.selfDrive
                                            ? 'Vehicle Pickup PIN'
                                            : 'Trip Start PIN',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF111827),
                                        ),
                                      ),
                                      if (_booking.startPinUsed || _booking.pickupPinUsed)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.brand.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'Verified',
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
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _booking.serviceType == RentalServiceType.selfDrive
                                  ? 'Provide this 4-digit PIN to the customer when handing over the vehicle keys, or verify it when entered in their app.'
                                  : 'Share or verify this 4-digit PIN with the customer / driver to authorize and start the rental trip.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF111827) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    effectiveStartPin,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 8,
                                      color: AppColors.brand,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 20, color: AppColors.brand),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: effectiveStartPin));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${_booking.serviceType == RentalServiceType.selfDrive ? "Pickup" : "Start"} PIN copied to clipboard',
                                          ),
                                          backgroundColor: AppColors.brand,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Self-Drive Return PIN Card (Fleet Manager View) ───────
                    if (_booking.returnPin != null && _booking.returnPin!.trim().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF451A03).withValues(alpha: 0.3) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.vpn_key_rounded, color: Color(0xFFD97706), size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Vehicle Return PIN',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF111827),
                                        ),
                                      ),
                                      if (_booking.returnPinUsed)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'Verified',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFD97706),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'The customer must enter this PIN in their app when returning the vehicle to complete the booking and credit your wallet.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF111827) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _booking.returnPin!,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 8,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 20, color: Color(0xFFD97706)),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: _booking.returnPin!));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Return PIN copied to clipboard')),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Schedule Details
                    _buildSectionCard(
                      title: 'Rental Schedule',
                      isDark: isDark,
                      primaryTextColor: primaryTextColor,
                      children: [
                        _buildRow('Pickup Date', dateFormat.format(_booking.startDate), isDark),
                        _buildRow('Return Date', dateFormat.format(_booking.endDate), isDark),
                        _buildRow('Duration', '${_booking.durationDays} Day(s)', isDark),
                        _buildRow('Pickup Location', _booking.pickupLocation, isDark),
                        if (_booking.dropoffLocation.isNotEmpty)
                          _buildRow('Dropoff Location', _booking.dropoffLocation, isDark),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Financial Breakdown
                    _buildSectionCard(
                      title: 'Financial Breakdown',
                      isDark: isDark,
                      primaryTextColor: primaryTextColor,
                      children: [
                        _buildRow('Rental Rate', NgnFormat.currency(_booking.totalAmount - _booking.cautionDeposit - _booking.driverAllowance), isDark),
                        if (_booking.driverAllowance > 0)
                          _buildRow('Driver Allowance', NgnFormat.currency(_booking.driverAllowance), isDark),
                        if (_booking.cautionDeposit > 0)
                          _buildRow('Caution Deposit', NgnFormat.currency(_booking.cautionDeposit), isDark),
                        Divider(height: 18, color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                        _buildRow('Gross Total', NgnFormat.currency(_booking.totalAmount), isDark),
                        if (_booking.fleetCommissionPercent != null) ...[
                          _buildRow(
                            'Platform Commission (${_booking.fleetCommissionPercent!.toStringAsFixed(0)}%)',
                            '− ${NgnFormat.currency((_booking.totalAmount - _booking.cautionDeposit) * (_booking.fleetCommissionPercent! / 100))}',
                            isDark,
                            valueColor: AppColors.error,
                          ),
                          Divider(height: 18, color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                          _buildRow(
                            _booking.serviceType == RentalServiceType.selfDrive
                                ? 'Your Earnings (on return)'
                                : 'Your Earnings (credited)',
                            NgnFormat.currency(_booking.fleetEarnings ?? 0),
                            isDark,
                            isHighlight: true,
                          ),
                        ] else
                          _buildRow('Your Earnings', NgnFormat.currency(_booking.totalAmount), isDark, isHighlight: true),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Status-Aware Action Section ──────────────────────
                    _buildActionSection(isDark),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
);
  }

  Widget _buildActionSection(bool isDark) {
    final status = _booking.status;

    if (status == RentalBookingStatus.pendingApproval) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              onPressed: _isProcessing ? null : _showApproveModal,
              child: const Text('Approve Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              onPressed: _isProcessing ? null : _showDeclineModal,
              child: const Text('Decline Booking', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );
    }

    if (status == RentalBookingStatus.awaitingPayment) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Row(
          children: [
            Icon(Icons.schedule_rounded, color: Color(0xFFD97706), size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Waiting for customer to complete payment. You can assign a driver once payment is received.',
                style: TextStyle(fontSize: 13, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    if (status == RentalBookingStatus.confirmed) {
      if (_booking.isChauffeur) {
        return Column(
          children: [
            if (!_booking.isDriverAssigned)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: AppColors.brand, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Payment received! Now assign a chauffeur driver.',
                        style: TextStyle(fontSize: 12, color: AppColors.brand, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                onPressed: _isProcessing ? null : _showAssignDriverModal,
                child: Text(
                  _booking.isDriverAssigned ? 'Reassign Driver' : 'Assign Chauffeur Driver',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      } else {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Payment confirmed. Customer self-drive rental.',
                  style: TextStyle(fontSize: 13, color: AppColors.brand, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }
    }

    if (status == RentalBookingStatus.inProgress) {
      final tripStatusDesc = _booking.rentalTripStatus == RentalTripStatus.headingToPickup
          ? 'Driver heading to pickup location'
          : 'Trip is in progress';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tripStatusDesc,
                style: const TextStyle(fontSize: 13, color: AppColors.brand, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    if (status == RentalBookingStatus.completed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 22),
            SizedBox(width: 12),
            Text('Trip completed successfully.', style: TextStyle(fontSize: 13, color: AppColors.brand, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (status == RentalBookingStatus.cancelled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.error, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text('This booking was declined or cancelled.', style: TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSectionCard({
    required String title,
    required bool isDark,
    required Color primaryTextColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
            ),
          ),
          Divider(height: 20, color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, bool isDark, {bool isHighlight = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
                color: valueColor ?? (isHighlight
                    ? AppColors.brand
                    : (isDark ? Colors.white : const Color(0xFF111827))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 80,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.directions_car, color: AppColors.brand, size: 28),
    );
  }

  Widget _buildDocumentPreviewTile({
    required String label,
    required String? imageUrl,
    required bool isDark,
    required Color primaryTextColor,
  }) {
    final hasUrl = imageUrl != null && imageUrl.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          if (hasUrl)
            GestureDetector(
              onTap: () => _openImagePreviewModal(context, imageUrl, label),
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderDoc(),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Tap to view',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 8),
                  Text(
                    'No document photo uploaded',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openImagePreviewModal(BuildContext context, String imageUrl, String title) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _placeholderDoc() {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: const Center(
        child: Icon(Icons.description_outlined, color: Color(0xFF9CA3AF), size: 32),
      ),
    );
  }
}
