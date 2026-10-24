"""Run Refinery's audit engine on a COBOL change and save the evidence Sapling will read.

Needs a Refinery checkout (private). Usage, from the Refinery repo root:
    uv run python export_evidence.py ORIGINAL.cob MODIFIED.cob OUT.json
"""
import difflib
import json
import sys
from pathlib import Path

from audit.engine import run_audit

orig, mod, out = map(Path, sys.argv[1:4])
d = run_audit(orig, mod).diff
diff = [
    l.rstrip()
    for l in difflib.unified_diff(orig.read_text().splitlines(), mod.read_text().splitlines(), orig.name, mod.name, n=0, lineterm="")
    if l[:1] in "+-" and not l.startswith(("+++", "---"))
]
evidence = {
    "program": orig.name,
    "source_diff": diff,
    "changed_paragraphs": sorted({c.location for c in d.semantic_changes if c.change_type == "COMPUTE_EXPR"}),
    "z3_formal_result": d.formal_result,
    "z3_formal_detail": d.formal_detail,
}
out.write_text(json.dumps(evidence, indent=2) + "\n")
print(json.dumps(evidence, indent=2))
