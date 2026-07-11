import os
import re

PATIENT_DIR = r"d:\carelink-care-link\lib\features\patient"
OUTPUT_FILE = "comprehensive_audit.md"

PATTERNS = {
    "Dr.": r'[\'"]Dr\.\s[^"\'\\]+[\'"]',
    "Hardcoded Task Count": r'[\'"]\d+\s+(?:Tasks?|Meds?|Inst\.|Goals?)[\'"]',
    "Hardcoded Available": r'[\'"]Available\s+today[\'"]',
    "Hardcoded Ready/Paid": r'[\'"]Ready[\'"]|[\'"]Paid[\'"]',
    "Hardcoded Ratings": r'(?<![a-zA-Z])(?:4\.[5-9]|5\.0)(?![a-zA-Z])',
    "Hardcoded Reviews": r'[\'"]\d+\s+reviews[\'"]',
    "Hardcoded Prices": r'[\'"]\$?\d+(?:\.\d{2})?[\'"]',
    "DateTime.now()": r'DateTime\.now\(\)',
    "Hardcoded Arrays": r'\[null,\s*\d+\.\d+,\s*\d+\.\d+,\s*\d+\.\d+\]',
    "Mock variables": r'(?i)(mock|dummy|sample|fake|testData)',
    "Static Lists": r'\.add\(\{[\s\S]{0,100}?[Title|title]',
    "Hardcoded Time": r'[\'"](?:10:00\sAM|7:00\sAM|07:00|10:00)[\'"]',
}

markdown_output = "# Comprehensive Audit Results\n\n"

for root, _, files in os.walk(PATIENT_DIR):
    for file in files:
        if file.endswith(".dart"):
            path = os.path.join(root, file)
            try:
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()
                    lines = content.split('\n')
                    
                file_results = []
                for i, line in enumerate(lines):
                    line_num = i + 1
                    for name, pattern in PATTERNS.items():
                        if re.search(pattern, line):
                            file_results.append((line_num, name, line.strip()))
                
                if file_results:
                    rel_path = path.replace(PATIENT_DIR, "")
                    markdown_output += f"## {rel_path}\n"
                    for res in file_results:
                        markdown_output += f"- **Line {res[0]}** ({res[1]}): `{res[2]}`\n"
                    markdown_output += "\n"
            except Exception as e:
                print(f"Error reading {path}: {e}")

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    f.write(markdown_output)

print("Audit written to", OUTPUT_FILE)
