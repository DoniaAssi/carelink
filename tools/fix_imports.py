#!/usr/bin/env python3
"""One-shot import fix after lib/ reorganization. Run from repo root."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"


def fix_file(p: Path) -> bool:
    text = p.read_text(encoding="utf-8")
    orig = text

    # Order matters: deeper relatives first
    subs = [
        (r"import '\.\./\.\./\.\./\.\./core/", "import 'package:carelink/core/"),
        (r"import '\.\./\.\./\.\./core/", "import 'package:carelink/core/"),
        (r"import '\.\./\.\./core/", "import 'package:carelink/core/"),
        (r"import '\.\./core/", "import 'package:carelink/core/"),
        (r"import '\.\./\.\./\.\./\.\./shared/", "import 'package:carelink/shared/"),
        (r"import '\.\./\.\./\.\./shared/", "import 'package:carelink/shared/"),
        (r"import '\.\./\.\./\.\./models/", "import 'package:carelink/shared/models/"),
        (r"import '\.\./\.\./\.\./widgets/", "import 'package:carelink/shared/widgets/"),
        (r"import '\.\./\.\./\.\./services/", "import 'package:carelink/shared/services/"),
        (r"import '\.\./\.\./models/", "import 'package:carelink/shared/models/"),
        (r"import '\.\./\.\./widgets/", "import 'package:carelink/shared/widgets/"),
        (r"import '\.\./\.\./services/", "import 'package:carelink/shared/services/"),
        (r"import '\.\./models/", "import 'package:carelink/shared/models/"),
        (r"import '\.\./widgets/", "import 'package:carelink/shared/widgets/"),
        (r"import '\.\./services/", "import 'package:carelink/shared/services/"),
    ]

    for pat, rep in subs:
        text = re.sub(pat, rep, text)

    # Patient-local services (not in shared)
    text = text.replace(
        "package:carelink/shared/services/patient_care_summary.dart",
        "package:carelink/features/patient/services/patient_care_summary.dart",
    )
    text = text.replace(
        "package:carelink/shared/services/favorite_providers_service.dart",
        "package:carelink/features/patient/services/favorite_providers_service.dart",
    )
    text = text.replace(
        "package:carelink/shared/services/provider_smart_match.dart",
        "package:carelink/features/ai/provider_smart_match.dart",
    )
    text = text.replace(
        "package:carelink/shared/services/care_intent_parser.dart",
        "package:carelink/features/ai/care_intent_parser.dart",
    )

    # Cross-feature routes (after generic ../../services -> shared)
    text = text.replace(
        "import '../payment/payment_screen.dart'",
        "import 'package:carelink/features/patient/payment/payment_screen.dart'",
    )
    text = text.replace(
        "import 'package:carelink/features/patient/screens/payment_screen.dart'",
        "import 'package:carelink/features/patient/payment/payment_screen.dart'",
    )

    if text != orig:
        p.write_text(text, encoding="utf-8")
        return True
    return False


def main() -> None:
    n = 0
    for p in sorted(LIB.rglob("*.dart")):
        if fix_file(p):
            n += 1
    print(f"updated {n} files")


if __name__ == "__main__":
    main()
