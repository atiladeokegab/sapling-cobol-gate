"""Offline tests: the gate rule, the evidence wording, and the open Z3 check on the demo COBOL."""
import json
from pathlib import Path

from gate import PROVED, decide, evidence_text, formal_text
from z3check import check, computes

R = Path(__file__).resolve().parent.parent
COB = R / "cobol"


def r(label, status, p):
    return {"raw_label": label, "status": status, "probabilities": {label: p}}


def test_gate_is_asymmetric():
    assert decide(r("violation", "unsure", 0.92))[0] == "BLOCK"
    assert decide(r("violation", "unsure", 0.60))[0] == "HOLD"
    assert decide(r("supported", "supported", 0.90))[0] == "PASS"
    assert decide(r("supported", "unsure", 0.46))[0] == "HOLD"  # an uncalibrated lean never passes


def test_bonus_bug_has_counterexample():
    ev = check(COB / "PAYROLL.cob", COB / "PAYROLL_ai_bug.cob")
    assert ev["z3_formal_result"] == "COUNTEREXAMPLE"
    assert ev["changed_paragraphs"] == ["CALC-NET-PAY"]


def test_reordered_refactor_is_proved_equivalent():
    ev = check(COB / "PAYROLL.cob", COB / "PAYROLL_ai_refactor.cob")
    assert ev["z3_formal_result"] == "PROVED_EQUIVALENT"


def test_open_check_agrees_with_refinery_evidence():
    for name, mod in (("bug", "PAYROLL_ai_bug.cob"), ("refactor", "PAYROLL_ai_refactor.cob")):
        saved = json.loads((R / "evidence" / f"{name}.json").read_text())
        assert check(COB / "PAYROLL.cob", COB / mod)["z3_formal_result"] == saved["z3_formal_result"]


def test_cobol_stays_inside_column_72():
    for f in COB.glob("*.cob"):
        assert all(len(l) <= 72 for l in f.read_text().splitlines()), f.name


def test_computes_reads_both_statements():
    assert [t for _, t, _ in computes((COB / "PAYROLL.cob").read_text())] == ["WS-TAX-AMOUNT", "WS-NET-PAY"]


def test_evidence_names_the_change_and_the_proof():
    ev = check(COB / "PAYROLL.cob", COB / "PAYROLL_ai_bug.cob")
    text = evidence_text(ev, "No change to pay.")
    assert "WS-BONUS * 2" in text and '"No change to pay."' in text
    assert "WS-NET-PAY is 1 in the original and 2 in the modified program" in text


def test_formal_text_reads_both_evidence_formats():
    for name in ("bug", "refactor"):  # Refinery's saved evidence and the open check must say the same thing
        saved = json.loads((R / "evidence" / f"{name}.json").read_text())
        assert formal_text(saved).startswith("Formal verification (Z3)")
    assert formal_text({"z3_formal_result": "PROVED_EQUIVALENT"}) == PROVED
    bug = json.loads((R / "evidence" / "bug.json").read_text())
    assert "in the original and" in formal_text(bug)  # the witness was parsed, not the fallback


def test_eval_corpus_kinds_match_z3():
    edits = json.loads((R / "eval" / "corpus.json").read_text())
    assert len(edits) == 60
    for e in edits:
        d = R / "eval" / "corpus" / e["program"]
        res = check(d / "orig.cob", d / f"{e['edit']}.cob")["z3_formal_result"]
        assert (res == "PROVED_EQUIVALENT") == (e["kind"] == "refactor"), (e["program"], e["edit"])
