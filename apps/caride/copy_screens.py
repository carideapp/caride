
import os

screens = {
    "lib/features/wallet/withdraw_amount_screen.dart": "lib/features/driver/earnings/withdrawal/driver_withdraw_amount_screen.dart",
    "lib/features/wallet/withdraw_bank_details_screen.dart": "lib/features/driver/earnings/withdrawal/driver_withdraw_bank_details_screen.dart",
    "lib/features/wallet/withdraw_pin_screen.dart": "lib/features/driver/earnings/withdrawal/driver_withdraw_pin_screen.dart",
    "lib/features/wallet/withdraw_success_screen.dart": "lib/features/driver/earnings/withdrawal/driver_withdraw_success_screen.dart",
    "lib/features/profile/security_pin_screen.dart": "lib/features/driver/profile/driver_security_pin_screen.dart"
}

os.makedirs("lib/features/driver/earnings/withdrawal", exist_ok=True)

for src, dst in screens.items():
    with open(src, "r", encoding="utf-8") as f:
        content = f.read()

    # Repositories
    content = content.replace("WithdrawRepository", "DriverWithdrawRepository")
    content = content.replace("wallet/data/withdraw_repository.dart", "driver/earnings/data/driver_withdraw_repository.dart")

    content = content.replace("SecurityPinRepository", "DriverSecurityPinRepository")
    content = content.replace("profile/data/security_pin_repository.dart", "driver/profile/data/driver_security_pin_repository.dart")

    # Classes
    content = content.replace("WithdrawAmountScreen", "DriverWithdrawAmountScreen")
    content = content.replace("_WithdrawAmountScreenState", "_DriverWithdrawAmountScreenState")
    
    content = content.replace("WithdrawBankDetailsScreen", "DriverWithdrawBankDetailsScreen")
    content = content.replace("_WithdrawBankDetailsScreenState", "_DriverWithdrawBankDetailsScreenState")

    content = content.replace("WithdrawPinScreen", "DriverWithdrawPinScreen")
    content = content.replace("_WithdrawPinScreenState", "_DriverWithdrawPinScreenState")

    content = content.replace("WithdrawSuccessScreen", "DriverWithdrawSuccessScreen")

    content = content.replace("SecurityPinScreen", "DriverSecurityPinScreen")
    content = content.replace("_SecurityPinScreenState", "_DriverSecurityPinScreenState")

    # Navigations / File references
    content = content.replace("withdraw_bank_details_screen.dart", "driver_withdraw_bank_details_screen.dart")
    content = content.replace("withdraw_pin_screen.dart", "driver_withdraw_pin_screen.dart")
    content = content.replace("withdraw_success_screen.dart", "driver_withdraw_success_screen.dart")
    content = content.replace("security_pin_screen.dart", "driver_security_pin_screen.dart")
    
    content = content.replace("package:caride/features/wallet/withdraw_bank_details_screen.dart", "package:caride/features/driver/earnings/withdrawal/driver_withdraw_bank_details_screen.dart")
    content = content.replace("package:caride/features/wallet/withdraw_pin_screen.dart", "package:caride/features/driver/earnings/withdrawal/driver_withdraw_pin_screen.dart")
    content = content.replace("package:caride/features/wallet/withdraw_success_screen.dart", "package:caride/features/driver/earnings/withdrawal/driver_withdraw_success_screen.dart")
    content = content.replace("package:caride/features/profile/security_pin_screen.dart", "package:caride/features/driver/profile/driver_security_pin_screen.dart")

    with open(dst, "w", encoding="utf-8") as f:
        f.write(content)

print("Screens duplicated")

