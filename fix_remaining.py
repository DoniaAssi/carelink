import re

home_file = r'd:\carelink-care-link\lib\features\patient\screens\patient_home_screen.dart'
loc_file = r'd:\carelink-care-link\lib\core\app_localizations.dart'

with open(home_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern for multi-line string literals or single quotes with newlines inside
# _homeText( '...', '...' ) spanning multiple lines
pattern = r"_homeText\(\s*'([^']*)'\s*,\s*'([^']*)'\s*\)"

def get_key(en_str):
    clean = re.sub(r'[^a-zA-Z0-9\s]', '', en_str).strip()
    words = clean.split()
    if not words: return "patient.home.empty"
    return "patient.home." + words[0].lower() + ''.join(w.capitalize() for w in words[1:5])

matches = re.finditer(pattern, content)
keys = {}
en_additions = []
ar_additions = []
new_content = content

for m in matches:
    en = m.group(1)
    ar = m.group(2)
    key = get_key(en)
    if key not in keys:
        keys[key] = (en, ar)
        en_additions.append(f"  '{key}': '{en.replace(chr(39), chr(92)+chr(39)).replace(chr(10), chr(92)+'n')}',")
        ar_additions.append(f"  '{key}': '{ar.replace(chr(39), chr(92)+chr(39)).replace(chr(10), chr(92)+'n')}',")
    new_content = new_content.replace(m.group(0), f"context.tr('{key}')")

with open(home_file, 'w', encoding='utf-8') as f:
    f.write(new_content)

if keys:
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

print(f"Added {len(keys)} multi-line keys safely")
