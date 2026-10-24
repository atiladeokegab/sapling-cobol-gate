"""Sapling change gate: does an AI tool's COBOL change comply with the bank's change policy?

Refinery audits the change (diff plus a Z3 formal proof or counterexample). Banyan Sapling
reads the policy, that evidence and the AI tool's own description of its change, and rules on
the claim "this change complies with the policy". The gate is deliberately asymmetric:

    BLOCK  Sapling's top label is violation with probability >= 0.90
    PASS   Sapling returns a calibrated (single-label) supported
    HOLD   anything else goes to a named human reviewer, with Sapling's lean shown

    uv run gate.py cobol/PAYROLL.cob cobol/PAYROLL_ai_bug.cob "Refactor of CALC-NET-PAY for readability. No change to pay."
    uv run gate.py evidence/bug.json "..."   # or Refinery's saved evidence for the same change

With two .cob files the evidence comes from z3check.py, the open formal check in this repo.
"""
# /// script
# dependencies = ["z3-solver"]
# ///
import json
import re
import sys
import urllib.request
from pathlib import Path

SAPLING = "https://6adbee0669a00298cd4774c9.endpoints.huggingface.cloud"
BLOCK_AT = 0.90
CLAIM = "The AI-assisted change complies with the policy."
HERE = Path(__file__).parent

# Refinery's formal result as plain sentences; Sapling reads prose better than engine output. A
# counterexample is spelled out as numbers, so Sapling can compare what changed with what was described.
PROVED = ("Formal verification (Z3) proved that the modified program computes exactly the same results "
          "as the original for every possible input: no computed result changed.")


def formal_text(e: dict) -> str:
    if e["z3_formal_result"] == "PROVED_EQUIVALENT":
        return PROVED
    if e["z3_formal_result"] != "COUNTEREXAMPLE":
        return "Formal verification reached no result."
    d = e["z3_formal_detail"]
    if m := re.match(r"Counterexample with inputs \{(.*)\}: (.*)", d):  # z3check.py
        ins = ", ".join(f"{k} = {v}" for k, v in re.findall(r"'([^']+)': '([^']+)'", m.group(1)))
        outs = "; ".join(f"{t} is {a} in the original and {b} in the modified program"
                         for t, a, b in re.findall(r"([\w-]+): original ([^,;]+), modified ([^;]+)", m.group(2)))
    elif m := re.search(r"Counterexample for ([\w-]+): orig=([^,]+), mod=([^,]+), witness=\{(.*)\}", d):  # Refinery
        ins = m.group(4).replace("=", " = ")
        outs = f"{m.group(1)} is {m.group(2)} in the original and {m.group(3)} in the modified program"
    else:
        return "Formal verification (Z3) shows the change alters computed results."
    return f"Formal verification (Z3) shows the change alters computed results. For example, with inputs {ins}, {outs}."


def sapling(policy: str, evidence: str, claim: str) -> dict:
    body = json.dumps({"inputs": {"policy": policy, "evidence": evidence, "claim": claim}}).encode()
    req = urllib.request.Request(SAPLING, body, {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def evidence_text(e: dict, description: str) -> str:
    old = " ".join(l[1:].strip() for l in e["source_diff"] if l.startswith("-"))
    new = " ".join(l[1:].strip() for l in e["source_diff"] if l.startswith("+"))
    return (
        f"The AI coding assistant changed paragraph {', '.join(e['changed_paragraphs'])} of {e['program']} "
        f'and described the change as: "{description}" '
        f"Original line: {old} Modified line: {new} " + formal_text(e)
    )


def decide(r: dict) -> tuple[str, str]:
    p = r["probabilities"]
    if r["raw_label"] == "violation" and p["violation"] >= BLOCK_AT:
        return "BLOCK", f"Sapling finds a policy violation ({p['violation']:.2f}): merge refused"
    if r["status"] == "supported":
        return "PASS", "Sapling's calibrated verdict is supported: forward to human sign-off"
    return "HOLD", f"no calibrated verdict (leans {r['raw_label']} {p[r['raw_label']]:.2f}): route to a named reviewer"


def main() -> int:
    *paths, description = sys.argv[1:]
    if len(paths) == 2:
        from z3check import check

        ev = check(Path(paths[0]), Path(paths[1]))
    else:
        ev = json.loads(Path(paths[0]).read_text())
    policy = (HERE / "policy.md").read_text()
    evidence = evidence_text(ev, description)
    print(f"POLICY    {policy.strip().replace(chr(10), chr(10) + '          ')}")
    print(f"EVIDENCE  {evidence}")
    print(f"CLAIM     {CLAIM}")
    r = sapling(policy, evidence, CLAIM)
    probs = "  ".join(f"{k} {v:.2f}" for k, v in sorted(r["probabilities"].items(), key=lambda kv: -kv[1]))
    print(f"SAPLING   status {r['status']}, top label {r['raw_label']} | {probs} | {r['timing_ms']['model']:.0f} ms")
    decision, why = decide(r)
    print(f"GATE      {decision}: {why}")
    return {"PASS": 0, "BLOCK": 1}.get(decision, 2)


if __name__ == "__main__":
    sys.exit(main())
