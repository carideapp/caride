
import codecs

file_path = "functions/src/index.ts"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

pin_start = content.find("export const createCustomerSecurityPin = onCall")
withdraw_start = content.find("export const processCustomerWithdrawal = onCall")
end_idx = content.find("export const resolveFlutterwaveBankAccount")

if pin_start == -1 or withdraw_start == -1 or end_idx == -1:
    print("Could not find markers", pin_start, withdraw_start, end_idx)
    exit(1)

customer_pin_code = content[pin_start:withdraw_start]
customer_withdraw_code = content[withdraw_start:end_idx]

def replace_terms(text):
    text = text.replace("Customer Security PIN Functions", "Driver Security PIN Functions")
    text = text.replace("Customer Payout / Withdrawal Functions", "Driver Payout / Withdrawal Functions")
    text = text.replace("CustomerSecurityPin", "DriverSecurityPin")
    text = text.replace("CustomerPinResetOtp", "DriverPinResetOtp")
    text = text.replace("CustomerWithdrawal", "DriverWithdrawal")
    text = text.replace("customersCollection", "driversCollection")
    text = text.replace("customerRef", "driverRef")
    text = text.replace("customerSnap", "driverSnap")
    text = text.replace("Customer not found", "Driver not found")
    text = text.replace("Customer profile", "Driver profile")
    text = text.replace("role: \"customer\"", "role: \"driver\"")
    text = text.replace("const customer =", "const driver =")
    text = text.replace("customer.", "driver.")
    text = text.replace("processCustomerWithdrawal", "processDriverWithdrawal")
    text = text.replace("send payout email to customer", "send payout email to driver")
    return text

driver_pin_code = replace_terms(customer_pin_code)
driver_withdraw_code = replace_terms(customer_withdraw_code)

new_content = content[:end_idx] + "\n// Driver Security PIN Functions\n\n" + driver_pin_code + "\n// Driver Withdrawal Functions\n\n" + driver_withdraw_code + "\n" + content[end_idx:]

with open(file_path, "w", encoding="utf-8") as f:
    f.write(new_content)

print("Success")

