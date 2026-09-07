
import os
import re

file_path = "lib/features/driver/wallet/driver_wallet_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

class_pattern = r"class _BankAccountTile extends StatelessWidget \{.*?\n\}\n"
new_content = re.sub(class_pattern, "", content, flags=re.DOTALL)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(new_content)

