import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';
import '../../controllers/fleet_manager_controller.dart';

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
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
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
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    Text(
                      'Assign Fleet Driver',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (drivers.isEmpty) ...[
                      const Text('No drivers linked to your fleet yet.'),
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
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final messenger = ScaffoldMessenger.of(this.context);
                          setState(() => _isProcessing = true);
                          try {
                            await fleetManagerController.approveBooking(
                              _booking.id,
                              assignedDriverId: selectedDriver?.id,
                              assignedDriverName: selectedDriver?.fullName,
                              assignedDriverPhone: selectedDriver?.phone,
                            );
                            if (!mounted) return;
                            setState(() {
                              _booking = _booking.copyWith(
                                status: RentalBookingStatus.confirmed,
                                assignedDriverId: selectedDriver?.id,
                                assignedDriverName: selectedDriver?.fullName,
                                assignedDriverPhone: selectedDriver?.phone,
                              );
                            });
                            messenger.showSnackBar(
                              SnackBar(
                                content: const Text('Driver assigned and booking confirmed!'),
                                backgroundColor: AppColors.brand,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            );
                          } finally {
                            if (mounted) setState(() => _isProcessing = false);
                          }
                        },
                        child: const Text('Save & Dispatch Driver', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final dateFormat = DateFormat('EEE, MMM dd, yyyy • hh:mm a');

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
                        _buildRow('Customer Name', _booking.customerName, isDark),
                        _buildRow('Phone Number', _booking.customerPhone, isDark),
                      ],
                    ),
                    const SizedBox(height: 16),

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
                        _buildRow('Total Amount', NgnFormat.currency(_booking.totalAmount), isDark, isHighlight: true),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Action Button (Green Pill)
                    if (_booking.isChauffeur) ...[
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
                            _booking.assignedDriverId != null ? 'Reassign Driver' : 'Assign Chauffeur Driver',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildRow(String label, String value, bool isDark, {bool isHighlight = false}) {
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
                color: isHighlight
                    ? AppColors.brand
                    : (isDark ? Colors.white : const Color(0xFF111827)),
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
}
