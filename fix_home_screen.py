import re
import os

home_file = r'd:\carelink-care-link\lib\features\patient\screens\patient_home_screen.dart'
loc_file = r'd:\carelink-care-link\lib\core\app_localizations.dart'

with open(home_file, 'r', encoding='utf-8') as f:
    home_content = f.read()

# Pattern to match _homeText('en', 'ar')
pattern = r"_homeText\(\s*'([^']*)',\s*'([^']*)'\s*\)"

matches = re.findall(pattern, home_content)

en_additions = []
ar_additions = []

def generate_key(en_str):
    # Create a camel case key from English string
    clean = re.sub(r'[^a-zA-Z0-9\s]', '', en_str)
    words = clean.split()
    if not words:
        return "patient.home.empty"
    key = words[0].lower() + ''.join(w.capitalize() for w in words[1:5])
    return f"patient.home.{key}"

key_map = {}
for en, ar in matches:
    key = generate_key(en)
    # Ensure unique keys if duplicates with different translations exist
    base_key = key
    counter = 1
    while key in key_map and key_map[key] != (en, ar):
        key = f"{base_key}{counter}"
        counter += 1
    
    if key not in key_map:
        key_map[key] = (en, ar)
        # Escape single quotes
        en_esc = en.replace("'", "\\'")
        ar_esc = ar.replace("'", "\\'")
        en_additions.append(f"  '{key}': '{en_esc}',")
        ar_additions.append(f"  '{key}': '{ar_esc}',")

# Replace in home_screen
new_home_content = re.sub(pattern, lambda m: f"context.tr('{generate_key(m.group(1))}')", home_content)

# We also need to fix _homeText with triple quotes or multi-lines? The regex might miss multi-line if they exist.
# Let's do a more robust regex for multi-line.
pattern_multiline = r"_homeText\(\s*('''|\"\"\"|'|\")([\s\S]*?)\1\s*,\s*('''|\"\"\"|'|\")([\s\S]*?)\3\s*\)"
matches_multi = re.findall(pattern_multiline, home_content)

for m in matches_multi:
    en = m[1]
    ar = m[3]
    key = generate_key(en)
    base_key = key
    counter = 1
    while key in key_map and key_map[key] != (en, ar):
        key = f"{base_key}{counter}"
        counter += 1
    
    if key not in key_map:
        key_map[key] = (en, ar)
        en_esc = en.replace("'", "\\'").replace("\n", "\\n")
        ar_esc = ar.replace("'", "\\'").replace("\n", "\\n")
        en_additions.append(f"  '{key}': '{en_esc}',")
        ar_additions.append(f"  '{key}': '{ar_esc}',")

new_home_content = re.sub(pattern_multiline, lambda m: f"context.tr('{generate_key(m.group(2))}')", new_home_content)

# Remove the _homeText definition
new_home_content = re.sub(r"String _homeText\(String en, String ar\) => _ar \? ar : en;\n", "", new_home_content)

with open(home_file, 'w', encoding='utf-8') as f:
    f.write(new_home_content)

# Now update app_localizations.dart
with open(loc_file, 'r', encoding='utf-8') as f:
    loc_content = f.read()

# Insert en_additions before the closing brace of _en
en_insert_pos = loc_content.find('};', loc_content.find('const Map<String, String> _en = {'))
if en_insert_pos != -1:
    loc_content = loc_content[:en_insert_pos] + '\n' + '\n'.join(en_additions) + '\n' + loc_content[en_insert_pos:]

# Insert ar_additions before the closing brace of _ar
ar_insert_pos = loc_content.find('};', loc_content.find('const Map<String, String> _ar = {'))
if ar_insert_pos != -1:
    loc_content = loc_content[:ar_insert_pos] + '\n' + '\n'.join(ar_additions) + '\n' + loc_content[ar_insert_pos:]

with open(loc_file, 'w', encoding='utf-8') as f:
    f.write(loc_content)

print(f"Replaced {len(key_map)} keys in patient_home_screen.dart")
