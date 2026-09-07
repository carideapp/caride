
import os

repo1 = "lib/features/wallet/data/withdraw_repository.dart"
repo2 = "lib/features/profile/data/security_pin_repository.dart"

with open(repo1, "r", encoding="utf-8") as f:
    r1_content = f.read()

with open(repo2, "r", encoding="utf-8") as f:
    r2_content = f.read()

r1_content = r1_content.replace("WithdrawRepository", "DriverWithdrawRepository")
r1_content = r1_content.replace("customers", "drivers")
r1_content = r1_content.replace("CustomerWithdrawal", "DriverWithdrawal")

r2_content = r2_content.replace("SecurityPinRepository", "DriverSecurityPinRepository")
r2_content = r2_content.replace("customers", "drivers")
r2_content = r2_content.replace("CustomerSecurityPin", "DriverSecurityPin")
r2_content = r2_content.replace("CustomerPinResetOtp", "DriverPinResetOtp")

# ensure directories exist
os.makedirs("lib/features/driver/earnings/data", exist_ok=True)
os.makedirs("lib/features/driver/profile/data", exist_ok=True)

with open("lib/features/driver/earnings/data/driver_withdraw_repository.dart", "w", encoding="utf-8") as f:
    f.write(r1_content)

with open("lib/features/driver/profile/data/driver_security_pin_repository.dart", "w", encoding="utf-8") as f:
    f.write(r2_content)

print("Repos duplicated")

