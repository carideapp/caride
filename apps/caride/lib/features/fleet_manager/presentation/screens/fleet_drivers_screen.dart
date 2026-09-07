import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';
import '../../controllers/fleet_manager_controller.dart';

/// Redesigned Fleet Drivers Screen matching the CaRide design-system.md standards.
class FleetDriversScreen extends StatefulWidget {
  const FleetDriversScreen({super.key});

  @override
  State<FleetDriversScreen> createState() => _FleetDriversScreenState();
}

class _FleetDriversScreenState extends State<FleetDriversScreen> {
  static const Color _lightInputFill = Color(0xFFF3F4F6);

  void _showInviteDriverModal() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final licenseController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
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
                    Text(
                      'Add Fleet Driver',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Register a chauffeur driver to assign to rental vehicles and bookings.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: nameController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15),
                      decoration: _pillInputDecoration(
                        hint: 'Driver Full Name',
                        fillColor: isDark ? AppColors.darkBackground : _lightInputFill,
                        prefixIcon: const Icon(Icons.person_rounded, color: AppColors.brand, size: 20),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15),
                      decoration: _pillInputDecoration(
                        hint: 'Driver Phone Number',
                        fillColor: isDark ? AppColors.darkBackground : _lightInputFill,
                        prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.brand, size: 20),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Phone required' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15),
                      decoration: _pillInputDecoration(
                        hint: 'Driver Email (Optional)',
                        fillColor: isDark ? AppColors.darkBackground : _lightInputFill,
                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.brand, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: licenseController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15),
                      decoration: _pillInputDecoration(
                        hint: 'Driver License Number (Optional)',
                        fillColor: isDark ? AppColors.darkBackground : _lightInputFill,
                        prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.brand, size: 20),
                      ),
                    ),
                    const SizedBox(height: 24),

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
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                final messenger = ScaffoldMessenger.of(this.context);
                                setModalState(() => isSubmitting = true);
                                try {
                                  await fleetManagerController.inviteDriver(
                                    fullName: nameController.text.trim(),
                                    phone: phoneController.text.trim(),
                                    email: emailController.text.trim(),
                                    licenseNumber: licenseController.text.trim(),
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: const Text('Driver added to fleet successfully!'),
                                      backgroundColor: AppColors.brand,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                  );
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Failed: $e'),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                  );
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Add to Fleet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brand,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
        label: const Text(
          'Add Driver',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
        ),
        onPressed: _showInviteDriverModal,
      ),
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
                      'Fleet Drivers',
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

            // Drivers List
            Expanded(
              child: ListenableBuilder(
                listenable: fleetManagerController,
                builder: (context, _) {
                  final drivers = fleetManagerController.drivers;

                  if (drivers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.people_outline_rounded,
                              size: 48,
                              color: AppColors.brand,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No drivers registered yet',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "+ Add Driver" to link chauffeurs to your fleet.',
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    itemCount: drivers.length,
                    itemBuilder: (context, index) {
                      final driver = drivers[index];
                      return _DriverCard(driver: driver);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _pillInputDecoration({
    required String hint,
    required Color fillColor,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      filled: true,
      fillColor: fillColor,
      prefixIcon: prefixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver});

  final FleetDriver driver;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.brand.withValues(alpha: 0.12),
            child: Text(
              driver.fullName.isNotEmpty ? driver.fullName[0].toUpperCase() : 'D',
              style: const TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.fullName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  driver.phone,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                  ),
                ),
                if (driver.assignedVehicleTitle != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.directions_car, size: 14, color: AppColors.brand),
                      const SizedBox(width: 4),
                      Text(
                        driver.assignedVehicleTitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.brand,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Remove Driver'),
                  content: Text('Remove ${driver.fullName} from your fleet?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Remove', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await fleetManagerController.removeDriver(driver.id);
              }
            },
          ),
        ],
      ),
    );
  }
}
