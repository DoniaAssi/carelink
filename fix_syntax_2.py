import os

filepath = r'lib/features/ai/screens/find_provider_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the wrong method calls with the correct classes
content = content.replace(
    "CarelinkThemeToggle(isDark: p.isDark, onToggle: themeController.toggle)",
    "const CarelinkThemeIconButton()"
)
content = content.replace(
    "IconButton(\n          icon: Icon(Icons.language, color: p.inkMuted),\n          onPressed: localeController.toggle,\n        )",
    "const CarelinkLocaleIconButton()"
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
