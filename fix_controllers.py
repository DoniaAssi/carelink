import os
import re

filepath = r'lib/features/ai/screens/find_provider_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Revert the mistaken replacements
content = content.replace('locale_caseController', 'localeController')
content = content.replace('theme_caseController', 'themeController')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed accidental controller replacements")
