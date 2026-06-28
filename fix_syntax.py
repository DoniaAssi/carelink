import os

filepath = r'lib/features/ai/screens/find_provider_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("locale_caseController.dart", "locale_controller.dart")
content = content.replace("theme_caseController.dart", "theme_controller.dart")
content = content.replace("p.surfaceContainerHighest", "Theme.of(context).colorScheme.surfaceContainerHighest")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed syntax errors in find_provider_screen.dart")
