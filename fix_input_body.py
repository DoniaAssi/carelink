import os
import re

filepath = r'lib/features/ai/screens/find_provider_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the compile errors from the previously inserted _inputBody
content = content.replace('_controller', '_caseController')
content = content.replace('_toggleListening', '_toggleVoice')
content = content.replace('_isListening', '_listening')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed variables in _inputBody")
