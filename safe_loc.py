import re

home_file = r'd:\carelink-care-link\lib\features\patient\screens\patient_home_screen.dart'
loc_file = r'd:\carelink-care-link\lib\core\app_localizations.dart'

with open(home_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
keys = {}
en_additions = []
ar_additions = []

def get_key(en_str):
    clean = re.sub(r'[^a-zA-Z0-9\s]', '', en_str).strip()
    words = clean.split()
    if not words: return "patient.home.empty"
    return "patient.home." + words[0].lower() + ''.join(w.capitalize() for w in words[1:5])

for line in lines:
    # We only match simple _homeText('en', 'ar') on a single line
    # For multiline, we skip or handle manually. We will just handle single line first.
    m = re.search(r"_homeText\(\s*'([^']*)'\s*,\s*'([^']*)'\s*\)", line)
    if m:
        en = m.group(1)
        ar = m.group(2)
        key = get_key(en)
        if key not in keys:
            keys[key] = (en, ar)
            en_additions.append(f"  '{key}': '{en.replace(chr(39), chr(92)+chr(39))}',")
            ar_additions.append(f"  '{key}': '{ar.replace(chr(39), chr(92)+chr(39))}',")
        
        line = line.replace(m.group(0), f"context.tr('{key}')")
    new_lines.append(line)

with open(home_file, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

# Now update app_localizations.dart
with open(loc_file, 'r', encoding='utf-8') as f:
    loc_content = f.read()

en_pos = loc_content.find('};', loc_content.find('const Map<String, String> _en = {'))
if en_pos != -1:
    loc_content = loc_content[:en_pos] + '\n'.join(en_additions) + '\n' + loc_content[en_pos:]

ar_pos = loc_content.find('};', loc_content.find('const Map<String, String> _ar = {'))
if ar_pos != -1:
    loc_content = loc_content[:ar_pos] + '\n'.join(ar_additions) + '\n' + loc_content[ar_pos:]

with open(loc_file, 'w', encoding='utf-8') as f:
    f.write(loc_content)

print(f"Added {len(keys)} keys safely")
