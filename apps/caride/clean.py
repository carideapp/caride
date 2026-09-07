
import os
import re

file_path = "lib/features/driver/earnings/driver_earnings_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Remove fields
content = re.sub(r"  double _today = 0;\s+double _week = 0;\s+double _month = 0;\s+bool _loadingStats = true;\s+", "", content)

# Remove initState and _loadStats
init_state_pattern = r"  @override\s+void initState\(\) \{\s+super\.initState\(\);\s+_loadStats\(\);\s+\}\s+Future<void> _loadStats\(\) async \{.*?\s+\}\s+  @override\s+Widget build\(BuildContext context\) \{"
content = re.sub(init_state_pattern, "  @override\n  Widget build(BuildContext context) {", content, flags=re.DOTALL)

# Remove _EarningCard
card_pattern = r"class _EarningCard extends StatelessWidget \{.*?\n\}\n\nclass _EarningTile"
content = re.sub(card_pattern, "class _EarningTile", content, flags=re.DOTALL)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Cleaned up unused code")

