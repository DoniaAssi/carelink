#!/usr/bin/env python3
"""Fix dart analyzer issues in patient_home_screen.dart"""

path = r'lib/features/patient/screens/patient_home_screen.dart'
with open(path, 'rb') as f:
    content = f.read().decode('utf-8')

fixes_done = []

# Fix 1: Remove unused import for carelink_theme_toggle.dart
target_import = "import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';\r\n"
if target_import in content:
    content = content.replace(target_import, '', 1)
    fixes_done.append('Removed unused import: carelink_theme_toggle.dart')

# Fix 2: Change (_, __) to (_, child) in ListenableBuilder for theme toggle
old_lb = "          builder: (_, __) => _headerIconBtn(\r\n"
new_lb = "          builder: (_, child) => _headerIconBtn(\r\n"
if old_lb in content:
    content = content.replace(old_lb, new_lb, 1)
    fixes_done.append('Fixed unnecessary_underscores in ListenableBuilder builder')

# Fix 3: Fix separatorBuilder (_, __) in favorites row
old_sep = "        separatorBuilder: (_, __) => const SizedBox(width: 12),"
new_sep = "        separatorBuilder: (_, index) => const SizedBox(width: 12),"
if old_sep in content:
    content = content.replace(old_sep, new_sep, 1)
    fixes_done.append('Fixed unnecessary_underscores in separatorBuilder')
else:
    # Try variant
    old_sep2 = "        separatorBuilder: (_, index) => const SizedBox(width: 12),"
    if old_sep2 in content:
        fixes_done.append('separatorBuilder already fixed')
    else:
        # Check what's actually there
        idx = content.find('width: 12')
        if idx >= 0:
            print(f'separatorBuilder variant: {repr(content[idx-80:idx+30])}')

print()
print('=== FIXES APPLIED ===')
for f in fixes_done:
    print(f'  [OK] {f}')

with open(path, 'wb') as f:
    f.write(content.encode('utf-8'))
print('\nSaved.')
