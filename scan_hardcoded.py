import os
import re
import json

PATIENT_DIR = r"d:\carelink-care-link\lib\features\patient"

PATTERNS = {
    "Dr.": r'"Dr\.\s[^"]+"',
    "Hardcoded Task Count": r'4\sTasks?|2\sMeds?|5\sInst\.|3\sGoals?',
    "Hardcoded Available": r'Available\stoday',
    "Hardcoded Status": r'"Ready"|"Paid"',
    "Hardcoded Ratings": r'4\.[5-9]|5\.0',
    "Hardcoded Reviews": r'\d+\sreviews',
    "Hardcoded Time": r'10:00\sAM|7:00\sAM|07:00|10:00',
    "Mock variables": r'mock[A-Z]|dummy[A-Z]|sample[A-Z]|testData|fakeData',
    "DateTime.now()": r'DateTime\.now\(\)',
}

results = []

for root, _, files in os.walk(PATIENT_DIR):
    for file in files:
        if file.endswith(".dart"):
            path = os.path.join(root, file)
            try:
                with open(path, "r", encoding="utf-8") as f:
                    lines = f.readlines()
                    
                file_results = []
                for i, line in enumerate(lines):
                    line_num = i + 1
                    for name, pattern in PATTERNS.items():
                        if re.search(pattern, line, re.IGNORECASE):
                            file_results.append({
                                "line": line_num,
                                "type": name,
                                "content": line.strip()
                            })
                
                if file_results:
                    results.append({
                        "file": path.replace(PATIENT_DIR, ""),
                        "findings": file_results
                    })
            except Exception as e:
                print(f"Error reading {path}: {e}")

with open("audit_results.json", "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2)

print(f"Scanned {len(results)} files with findings.")
