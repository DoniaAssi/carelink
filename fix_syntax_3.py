import re

home_file = r'd:\carelink-care-link\lib\features\patient\screens\patient_home_screen.dart'

with open(home_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    # Fix invalid constants
    if '_p.' in line or 'context.tr' in line or 'CarelinkPalette' in line:
        # If there's a const before it on the same line, remove it
        line = re.sub(r'\bconst\s+(?=[A-Z])', '', line)
        line = re.sub(r'\bconst\s+\[', '[', line)
        line = re.sub(r'\bconst\s+EdgeInsets', 'EdgeInsets', line)
        line = re.sub(r'\bconst\s+EdgeInsetsDirectional', 'EdgeInsetsDirectional', line)
        line = re.sub(r'\bconst\s+BoxConstraints', 'BoxConstraints', line)
        line = re.sub(r'\bconst\s+TextStyle', 'TextStyle', line)
        line = re.sub(r'\bconst\s+BoxShadow', 'BoxShadow', line)
        line = re.sub(r'\bconst\s+Offset', 'Offset', line)
    
    # Fix duplicate borderRadius
    if 'borderRadius: BorderRadius.circular(16),' in line:
        if 'borderRadius: BorderRadius.circular(16),' in ''.join(lines[i-2:i]):
            continue
    
    # Fix undefined _p at 7223
    # Look at line 7223 and replace _p with CarelinkPalette.of(context) if _p is not defined
    if '_p.' in line and 'Widget build(' not in ''.join(lines[max(0, i-50):i]):
        if 'context' in line or 'context' in ''.join(lines[max(0, i-5):i]):
            line = line.replace('_p.', 'CarelinkPalette.of(context).')
    
    new_lines.append(line)

with open(home_file, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print("Syntax fixed")
