"""Open, minimal formal check: are the COMPUTE results of two COBOL programs equal for every input?

Refinery's full engine (11 checks, semantic engine, Z3 over far more of COBOL) is private. This is a
small re-implementation of the one check this demo needs, so anyone can reproduce the evidence:

    uv run z3check.py cobol/PAYROLL.cob cobol/PAYROLL_ai_bug.cob

It reads every COMPUTE statement in the PROCEDURE DIVISION, in order, substitutes earlier results
into later ones, and asks Z3 whether any input makes a target differ between the two programs.
"""
# /// script
# dependencies = ["z3-solver"]
# ///
import difflib
import json
import re
import sys
from pathlib import Path

import z3

OPS = {"+", "-", "*", "/", "(", ")"}


def computes(src: str) -> list[tuple[str, str, list[str]]]:
    """(paragraph, target, expression tokens) for each COMPUTE, in source order."""
    lines = [l[6:72] if len(l) > 6 else "" for l in src.splitlines()]  # fixed format: columns 8-72
    code = "\n".join("" if l[:1] in "*/" else l[1:] for l in lines)
    proc = code.split("PROCEDURE DIVISION.", 1)[1]
    out, para = [], "PROCEDURE"
    for stmt in re.split(r"\.\s", proc + " "):
        words = stmt.split()
        if len(words) == 1 and re.fullmatch(r"[A-Z0-9-]+", words[0]):
            para = words[0]
        if "COMPUTE" in words:
            i = words.index("COMPUTE")
            target, rest = words[i + 1], words[words.index("=", i) + 1:]
            out.append((para, target, rest))
    return out


def to_z3(tokens: list[str], env: dict, vars_: dict):
    py = []
    for t in " ".join(tokens).replace("(", " ( ").replace(")", " ) ").split():
        if t in OPS:
            py.append(t)
        elif re.fullmatch(r"\d+(\.\d+)?", t):
            py.append(f"z3.RealVal('{t}')")
        else:
            if t not in env:
                # shortcut: inputs are unbounded non-negative reals, not PIC-sized decimals; upgrade for overflow/truncation checks
                vars_.setdefault(t, z3.Real(t))
            py.append(f"_v[{t!r}]")
    lookup = {**vars_, **env}
    return eval(" ".join(py), {"z3": z3, "_v": lookup})


def check(orig: Path, mod: Path) -> dict:
    vars_: dict = {}
    results = {}
    for name, path in (("orig", orig), ("mod", mod)):
        env: dict = {}
        for _, target, toks in computes(path.read_text()):
            env[target] = to_z3(toks, env, vars_)
        results[name] = env
    o_src, m_src = orig.read_text(), mod.read_text()
    changed = sorted({p for (p, t, a), (_, _, b) in zip(computes(o_src), computes(m_src)) if a != b})
    diff = [l.rstrip() for l in difflib.unified_diff(o_src.splitlines(), m_src.splitlines(), n=0, lineterm="")
            if l[:1] in "+-" and not l.startswith(("+++", "---"))]
    targets = sorted(set(results["orig"]) & set(results["mod"]))
    s = z3.Solver()
    s.add(*[v >= 0 for v in vars_.values()])
    s.add(z3.Or(*[results["orig"][t] != results["mod"][t] for t in targets]))
    if s.check() == z3.sat:
        m = s.model()
        witness = {k: str(m.eval(v, model_completion=True)) for k, v in sorted(vars_.items())}
        diffs = [f"{t}: original {m.eval(results['orig'][t], model_completion=True)}, modified {m.eval(results['mod'][t], model_completion=True)}"
                 for t in targets if not m.eval(results["orig"][t] == results["mod"][t], model_completion=True)]
        result, detail = "COUNTEREXAMPLE", f"Counterexample with inputs {witness}: " + "; ".join(diffs)
    else:
        result, detail = "PROVED_EQUIVALENT", f"Proved equivalent for every non-negative input, targets: {targets}"
    return {"program": orig.name, "source_diff": diff, "changed_paragraphs": changed,
            "z3_formal_result": result, "z3_formal_detail": detail}


if __name__ == "__main__":
    print(json.dumps(check(Path(sys.argv[1]), Path(sys.argv[2])), indent=2))
