import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';

/// Reusable 3-month vehicle booking calendar matching CaRide design-system.md.
/// Visualizes booked (green), available (grey), maintenance/blackout (amber), and past dates.
class VehicleBookingCalendar extends StatefulWidget {
  const VehicleBookingCalendar({
    super.key,
    required this.bookings,
    this.blackoutDates = const [],
    this.selectedDates = const {},
    this.onDateTapped,
    this.isManagerMode = false,
  });

  /// Active or pending bookings that reserve vehicle dates.
  final List<RentalBooking> bookings;

  /// Manual fleet manager maintenance / blackout dates in 'YYYY-MM-DD' format.
  final List<String> blackoutDates;

  /// Currently selected dates (e.g. in booking form or manual blackout editing).
  final Set<String> selectedDates;

  /// Callback when a selectable day is tapped.
  final ValueChanged<DateTime>? onDateTapped;

  /// If true, shows manager options (e.g. maintenance toggle hints).
  final bool isManagerMode;

  @override
  State<VehicleBookingCalendar> createState() => _VehicleBookingCalendarState();
}

class _VehicleBookingCalendarState extends State<VehicleBookingCalendar> {
  late final PageController _pageController;
  late final DateTime _today;
  int _currentMonthIndex = 0;

  static const int _totalMonths = 3;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _getMonthForIndex(int index) {
    return DateTime(_today.year, _today.month + index, 1);
  }

  String _formatIso(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  bool _isDateBooked(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    for (final b in widget.bookings) {
      if (b.status == RentalBookingStatus.cancelled ||
          b.status == RentalBookingStatus.rejected ||
          b.status == RentalBookingStatus.completed) {
        continue;
      }
      final s = DateTime(b.startDate.year, b.startDate.month, b.startDate.day);
      final e = DateTime(b.endDate.year, b.endDate.month, b.endDate.day);
      if (!target.isBefore(s) && !target.isAfter(e)) {
        return true;
      }
    }
    return false;
  }

  RentalBooking? _getBookingForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    for (final b in widget.bookings) {
      if (b.status == RentalBookingStatus.cancelled ||
          b.status == RentalBookingStatus.rejected ||
          b.status == RentalBookingStatus.completed) {
        continue;
      }
      final s = DateTime(b.startDate.year, b.startDate.month, b.startDate.day);
      final e = DateTime(b.endDate.year, b.endDate.month, b.endDate.day);
      if (!target.isBefore(s) && !target.isAfter(e)) {
        return b;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    final currentMonth = _getMonthForIndex(_currentMonthIndex);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Calendar Top Navigation ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(currentMonth),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '3-Month Booking Horizon',
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: _currentMonthIndex > 0
                        ? primaryTextColor
                        : secondaryTextColor.withValues(alpha: 0.3),
                    onPressed: _currentMonthIndex > 0
                        ? () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                    tooltip: 'Previous Month',
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    color: _currentMonthIndex < _totalMonths - 1
                        ? primaryTextColor
                        : secondaryTextColor.withValues(alpha: 0.3),
                    onPressed: _currentMonthIndex < _totalMonths - 1
                        ? () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                    tooltip: 'Next Month',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Days of the Week Header (7 Equal Columns) ──
          Row(
            children: const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),

          // ── Responsive Month Days Pager ──
          LayoutBuilder(
            builder: (context, constraints) {
              const crossAxisSpacing = 4.0;
              const mainAxisSpacing = 6.0;
              // Dynamically calculate width per column based on phone width
              final cellWidth =
                  (constraints.maxWidth - (crossAxisSpacing * 6)) / 7;
              // 6 rows maximum in any calendar month
              final responsiveHeight =
                  (cellWidth * 6) + (mainAxisSpacing * 5) + 4.0;

              return SizedBox(
                height: responsiveHeight,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _totalMonths,
                  onPageChanged: (idx) =>
                      setState(() => _currentMonthIndex = idx),
                  itemBuilder: (context, pageIndex) {
                    final monthDate = _getMonthForIndex(pageIndex);
                    return _buildMonthGrid(
                      monthDate,
                      isDark,
                      primaryTextColor,
                      crossAxisSpacing,
                      mainAxisSpacing,
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 12),

          // ── Visual Legend ──
          _buildLegend(isDark, secondaryTextColor),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(
    DateTime monthDate,
    bool isDark,
    Color primaryTextColor,
    double crossAxisSpacing,
    double mainAxisSpacing,
  ) {
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final daysInMonth =
        DateTime(monthDate.year, monthDate.month + 1, 0).day;

    // Monday is index 1, Sunday is index 7. We want Monday to be 0 offset.
    final startOffset = (firstDayOfMonth.weekday - 1) % 7;
    final totalCells = ((startOffset + daysInMonth) / 7).ceil() * 7;

    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayNumber = index - startOffset + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final cellDate =
            DateTime(monthDate.year, monthDate.month, dayNumber);
        final isPast = cellDate.isBefore(_today);
        final isBooked = _isDateBooked(cellDate);
        final iso = _formatIso(cellDate);
        final isBlackout = widget.blackoutDates.contains(iso);
        final isSelected = widget.selectedDates.contains(iso);

        // Determine styling
        Color cellBg;
        Color textColor;
        Border? border;

        if (isSelected) {
          cellBg = AppColors.brand;
          textColor = Colors.white;
        } else if (isBooked) {
          // Booked = CaRide Emerald Green
          cellBg = AppColors.brand;
          textColor = Colors.white;
        } else if (isBlackout) {
          // Blackout / Maintenance = Amber
          cellBg = const Color(0xFFF59E0B);
          textColor = Colors.white;
        } else if (isPast) {
          cellBg = Colors.transparent;
          textColor = const Color(0xFF9CA3AF).withValues(alpha: 0.45);
        } else {
          // Available = Grey neutral
          cellBg = isDark
              ? const Color(0xFF1F2937)
              : const Color(0xFFF3F4F6);
          textColor = primaryTextColor;
          border = Border.all(
            color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
            width: 1,
          );
        }

        final isClickable = !isPast && (widget.onDateTapped != null);

        return GestureDetector(
          onTap: isClickable
              ? () => widget.onDateTapped!(cellDate)
              : () {
                  if (isBooked) {
                    final b = _getBookingForDate(cellDate);
                    if (b != null) {
                      _showBookingTooltip(context, b);
                    }
                  }
                },
          child: Container(
            decoration: BoxDecoration(
              color: cellBg,
              shape: BoxShape.circle,
              border: border,
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: (isBooked || isBlackout || isSelected)
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBookingTooltip(BuildContext context, RentalBooking booking) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.event_busy_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Reserved for ${booking.serviceType.label}: '
                '${DateFormat('MMM d').format(booking.startDate)} - ${DateFormat('MMM d').format(booking.endDate)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildLegend(bool isDark, Color secondaryTextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _legendItem(
          color: AppColors.brand,
          label: 'Booked',
          textColor: secondaryTextColor,
        ),
        _legendItem(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
          borderColor: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
          label: 'Available',
          textColor: secondaryTextColor,
        ),
        _legendItem(
          color: const Color(0xFFF59E0B),
          label: 'Maintenance',
          textColor: secondaryTextColor,
        ),
      ],
    );
  }

  Widget _legendItem({
    required Color color,
    required String label,
    required Color textColor,
    Color? borderColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: borderColor != null ? Border.all(color: borderColor) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
