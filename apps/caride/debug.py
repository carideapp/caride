
import re
file_path = "functions/src/index.ts"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()
pin_pattern = r"// --------------------------- Customer Security PIN Functions ---------------------------.*?// --------------------------- Customer Payout / Withdrawal Functions ---------------------------"
pin_match = re.search(pin_pattern, content, re.DOTALL)
withdraw_pattern = r"// --------------------------- Customer Payout / Withdrawal Functions ---------------------------.*?export const resolveFlutterwaveBankAccount"
withdraw_match = re.search(withdraw_pattern, content, re.DOTALL)
print("pin:", pin_match is not None)
print("withdraw:", withdraw_match is not None)

