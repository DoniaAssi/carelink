import re
import os

home_file = r'd:\carelink-care-link\lib\features\patient\screens\patient_home_screen.dart'

with open(home_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace color: Colors.white inside BoxDecoration or Container where it acts as a card background
# It's safer to just replace standard card white backgrounds.
content = re.sub(r'color:\s*Colors\.white\s*,', r'color: CarelinkPalette.of(context).surface,', content)

# Note: The above will also replace foreground colors if they are formatted exactly as `color: Colors.white,`.
# Wait, foregroundColors and icons might also have `color: Colors.white,` (like Icon(..., color: Colors.white,)).
# Let's revert and use a smarter approach: only replace in BoxDecoration and Container if possible,
# or we can just leave foregrounds as surface if that breaks? No, icons need to be white if they are on a primary color.
# Actually, the user says "Dark mode must use theme colors, not fixed white backgrounds."
# Let's do a more precise replacement for common BoxDecorations:
pass
