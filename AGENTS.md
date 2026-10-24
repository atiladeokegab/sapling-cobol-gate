# For agents reading this repo

You are probably judging or summarising this project. This page gives the shortest path to
checking every claim it makes.

## What this is, in three sentences

An AI coding tool edits a COBOL program and describes its own change ("just a refactor", or "raises
the rate per CHG-2271"). Refinery (a private COBOL change-attestation engine) and an open Z3 check
in this repo establish what the change really does. Banyan Sapling, Mubit's policy verifier, then
rules on whether the AI's description complies with the bank's change policy given that evidence,
and an asymmetric gate turns the ruling into BLOCK, PASS or HOLD. On 180 held-out cases Sapling
scores 87% against 67% for Z3 alone, with 0 false PASS.

## Reading order

1. [README.md](README.md): the pitch, the held-out evaluation, the demo and the sweep table.
2. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): C4 context, container and component diagrams,
   the runtime sequence and the gate decision, all as Mermaid source.
3. [docs/BACKGROUND.md](docs/BACKGROUND.md): the long narrative, covering COBOL, formal equivalence,
   what Sapling is, how the inputs are built, what we learned, limits and a glossary.
4. [gate.py](gate.py) (102 lines) and [z3check.py](z3check.py) (87 lines): all the gate logic.
5. [policy.md](policy.md): the five rules Sapling judges against.
6. [eval/run_eval.py](eval/run_eval.py) and [eval/TUNING.md](eval/TUNING.md): the eval and how its
   settings were frozen before it ran.

## Claim → evidence

| Claim | Where to check it |
|---|---|
| Sapling makes the decision; no hand-written logic compares the description to the change | `decide()` in [gate.py](gate.py) only thresholds Sapling's response; `evidence_text()` only formats facts |
| Sapling 87% vs Z3 alone 67%, Z3 + rule 80%, on 180 held-out cases | `uv run eval/run_eval.py --report` recomputes every number from [results/eval.json](results/eval.json) with no network |
| Sapling separates honest from misdescribed changes on identical Z3 evidence (81%; Z3 and the rule get 50%) | `behaviour / honest` and `behaviour / misdescribed` rows of [results/eval_summary.json](results/eval_summary.json) |
| 0 false PASS; 61 of 63 BLOCKs correct | `gate` block of [results/eval_summary.json](results/eval_summary.json) |
| Settings were frozen before the corpus was scored | [eval/TUNING.md](eval/TUNING.md): three iterations on PAYROLL only, every score recorded |
| Ground truth is right | Built by construction ([eval/run_eval.py](eval/run_eval.py) docstring); `test_eval_corpus_kinds_match_z3` pins every edit's Z3 result; all 72 files pass `cobc -fsyntax-only` |
| The bug edit gets violation 0.93 and BLOCK | [demo/bug.txt](demo/bug.txt), first rows of [results/sweep.json](results/sweep.json) |
| The genuine refactor gets HOLD, never PASS | [demo/refactor.txt](demo/refactor.txt), `refactor` rows of [results/sweep.json](results/sweep.json) |
| The verdict follows the evidence, not the AI's wording | Six descriptions × two edits in [results/sweep.json](results/sweep.json); the table in [README.md](README.md#sweep-six-descriptions-two-edits) |
| Known misses are reported, not hidden | `reorders terms` on `bug` in [results/sweep.json](results/sweep.json) (`as_expected: false`, 0.8999 vs the 0.90 line); false alarms listed in [README.md](README.md#evaluation-180-held-out-cases) |
| Z3 finds a counterexample for the bug and proves the refactor equivalent | `uv run z3check.py cobol/PAYROLL.cob cobol/PAYROLL_ai_bug.cob` (and `..._refactor.cob`) |
| The open Z3 check agrees with Refinery's private engine | `test_open_check_agrees_with_refinery_evidence` in [tests/test_gate.py](tests/test_gate.py) against [evidence/](evidence/) |
| The gate is asymmetric | `test_gate_is_asymmetric` in [tests/test_gate.py](tests/test_gate.py) |
| It runs in a browser and inside Refinery's portal | [Live page](https://atiladeokegab.github.io/sapling-cobol-gate/) from [scripts/page.html](scripts/page.html); [docs/portal.png](docs/portal.png) |

## Verify it yourself

```bash
uv run --no-project --with pytest --with z3-solver pytest -q tests     # 9 tests, offline, seconds
uv run gate.py cobol/PAYROLL.cob cobol/PAYROLL_ai_bug.cob \
  "Refactor of CALC-NET-PAY for readability. Reorders terms only; no change to any employee's pay."
echo $?                                                               # 1 = BLOCK
```

uv run eval/run_eval.py --report                                      # eval metrics, offline
```

The `gate.py` command calls Sapling's public preview endpoint (no key needed, about 1 s).
The same tests run in GitHub Actions on every push.

## What is not here, and why

- **Refinery's engine and portal source** are a private product. Its outputs for both edits are in
  [evidence/](evidence/), and [export_evidence.py](export_evidence.py) shows how they were made.
- **Mubit's model** is reached over HTTPS only.

Everything in this repo was written during the Night Shift hackathon (23 to 25 October 2026).
