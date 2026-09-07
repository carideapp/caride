
import os

screens = [
    "lib/features/driver/earnings/withdrawal/driver_withdraw_amount_screen.dart",
    "lib/features/driver/earnings/withdrawal/driver_withdraw_bank_details_screen.dart",
    "lib/features/driver/earnings/withdrawal/driver_withdraw_pin_screen.dart",
    "lib/features/driver/earnings/withdrawal/driver_withdraw_success_screen.dart",
    "lib/features/driver/profile/driver_security_pin_screen.dart"
]

for file_path in screens:
    if os.path.exists(file_path):
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
        
        # fix imports
        content = content.replace("package:caride/features/wallet/driver_withdraw", "package:caride/features/driver/earnings/withdrawal/driver_withdraw")
        
        # fix balance fetch
        content = content.replace(".collection('customers')", ".collection('drivers')")
        
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)

