"""Build docs/index.html (the live demo page) from the repo's COBOL, evidence and policy."""
import json
from pathlib import Path

R = Path(__file__).resolve().parent.parent
data = {
    "cobol": {"orig": (R / "cobol/PAYROLL.cob").read_text(), "bug": (R / "cobol/PAYROLL_ai_bug.cob").read_text(),
              "refactor": (R / "cobol/PAYROLL_ai_refactor.cob").read_text()},
    "evidence": {k: json.loads((R / f"evidence/{k}.json").read_text()) for k in ("bug", "refactor")},
    "policy": (R / "policy.md").read_text(),
}
page = (R / "scripts/page.html").read_text().replace("__DATA__", json.dumps(data).replace("</", "<\\/"))
(R / "docs/index.html").write_text(page)
