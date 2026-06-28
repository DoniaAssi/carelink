import re

home_file = r'd:\carelink-care-link\lib\features\patient\screens\patient_home_screen.dart'

with open(home_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Strip 'const' around these lines
target_lines = [2867, 2879, 2899, 3426, 3445, 3484, 3493, 3651, 3790]
for tl in target_lines:
    for i in range(max(0, tl-3), min(len(lines), tl+1)):
        lines[i] = re.sub(r'\bconst\s+', '', lines[i])

# Fix duplicate borderRadius around 3627
for i in range(3620, 3635):
    if 'borderRadius: BorderRadius.circular(16),' in lines[i]:
        # if the previous lines also have it, remove this one
        if any('borderRadius: BorderRadius.circular(16),' in l for l in lines[max(0, i-5):i]):
            lines[i] = ""

# Fix _p at 7224
for i in range(7215, 7235):
    if '_p' in lines[i]:
        lines[i] = lines[i].replace('_p', 'CarelinkPalette.of(context)')

# Fix unused local variable isHome at 3332
for i in range(3325, 3340):
    if 'bool isHome =' in lines[i]:
        lines[i] = lines[i].replace('bool isHome =', 'bool _ =')

with open(home_file, 'w', encoding='utf-8') as f:
    f.writelines(lines)
print("Final syntax fixed")
