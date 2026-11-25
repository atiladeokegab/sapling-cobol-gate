![Sapling COBOL change gate: verify what the AI says it changed](docs/assets/banner.png)

# Sapling COBOL change gate

[![tests](https://github.com/atiladeokegab/sapling-cobol-gate/actions/workflows/tests.yml/badge.svg)](https://github.com/atiladeokegab/sapling-cobol-gate/actions/workflows/tests.yml)
[![COBOL](https://img.shields.io/badge/COBOL-payroll-FCD34D)](cobol/PAYROLL.cob)
[![Python: z3-solver only](https://img.shields.io/badge/python-z3--solver%20only-3776AB?logo=python&logoColor=white)](gate.py)
[![Docs](https://img.shields.io/badge/docs-architecture-blue)](docs/ARCHITECTURE.md)
[![Demo page](https://img.shields.io/badge/demo%20page-GitHub%20Pages-222?logo=github)](https://atiladeokegab.github.io/sapling-cobol-gate/)

Banks are letting AI assistants edit decades-old COBOL that moves money. The AI writes a confident change description ("readability refactor, no change to pay") and a tired reviewer approves it. A formal proof can tell that reviewer whether the change alters a computed result, but not whether the AI's description of the change is true.

This command-line gate checks the description itself. [Banyan Sapling](https://mubit.ai), Mubit's policy verifier, reads the bank's change policy, the formal evidence and the AI's own words, and the gate turns its ruling into BLOCK, HOLD or PASS, as an exit code CI can enforce. On 180 AI descriptions of 60 COBOL edits, Sapling's flag is right **87%** of the time (156 of 180), against 67% for the Z3 proof alone on the same cases.

It was built for the Night Shift: Mubit Hackathon (London, 23–25 October 2026), where it took **2nd place in the side challenge**. The benchmark is synthetic: 12 programs written for the eval and held out from development, with labels set by construction and every cited ticket assumed approved. At the stricter gate setting it blocked 63 descriptions (61 correctly), held 117 for human review and passed none, so selective approval is not yet demonstrated.

**[Demo page](https://atiladeokegab.github.io/sapling-cobol-gate/)** · **[Watch the 2-minute film](https://github.com/atiladeokegab/sapling-cobol-gate/releases/tag/v0.1)**

![The demo page: an edit that doubles the bonus is checked and stamped BLOCK, then a proved refactor is stamped HOLD](docs/assets/demo.gif)

<sub>The demo page calling Sapling live on two AI edits that carry the same description. This recording, the crops below, the banner and the portal screenshot use the first policy (violation 0.92); the [current transcript](demo/bug.txt) scores 0.93. The page itself loads, but its verdict needs Sapling's preview endpoint, which answered 503 on 25 November 2026.</sub>

## How it works

1. **Prove what the change does.** `z3check.py` reads every COMPUTE in the two programs, substitutes earlier results into later ones, and asks Z3 for an input where they differ. It returns either a proof of equivalence or a concrete counterexample, where a text diff shows only that a line moved. This open check models COMPUTE arithmetic over nonnegative reals; [Refinery](https://refinery.guru)'s private engine covers more, and its saved output for both demo edits is in [evidence/](evidence/).

   ![z3check.py finds a counterexample for the bonus bug and proves the refactor equivalent](docs/assets/how-z3.gif)

2. **Let Sapling judge the description.** `gate.py` sends Sapling the five change-control rules in `policy.md`, the changed lines, the AI's description and the Z3 result in plain words. Nothing in the code compares the description to the change: Sapling alone decides whether "reorders terms only" is true of it.

   ![Sapling scores the bonus edit's description as a policy violation](docs/assets/how-sapling.gif)

3. **Act on the ruling, asymmetrically.** `decide()` in `gate.py` refuses the merge when Sapling's top label is `violation` at 0.90 or above, forwards only a calibrated `supported` to human sign-off, and holds everything else for a named reviewer with Sapling's lean shown. A false block costs a human five minutes; a false pass costs a payroll run. The exit code is 1 for BLOCK, 0 for PASS and 2 for HOLD.

   ![The genuine refactor gets HOLD and goes to a named reviewer](docs/assets/how-gate.gif)

The bug in edit 1 is one token. COBOL `*` binds before `+`, so every bonus is paid twice:

```diff
-               WS-BASE-PAY + WS-BONUS - WS-DEDUCTION - WS-TAX-AMOUNT.
+               WS-BASE-PAY + WS-BONUS * 2 - WS-DEDUCTION - WS-TAX-AMOUNT.
```

## Evaluation: 180 held-out cases

You can see where Sapling adds something a proof cannot. Each of the 12 programs has 2 refactors that Z3 proves equivalent and 3 behaviour changes with a counterexample, and each edit has three descriptions, so the 180 cases are related, not independent. An honest and a misdescribed description sit on the same counterexample; only reading the words separates them.

![Sapling's p(violation) for each of the 180 cases, by kind](docs/assets/eval.png)

| Approach | Accuracy | Refactor + "no change" (48) | Phantom (24) | Behaviour + "no change" (36) | Honest (36) | Misdescribed (36) |
|---|---|---|---|---|---|---|
| Trust the AI's description | 47% | 48 | 0 | 0 | 36 | 0 |
| Z3 alone (flag any counterexample) | 67% | 48 | 0 | 36 | 0 | 36 |
| Z3 + description type (rule; the type is given from the ground truth) | 80% | 48 | 24 | 36 | 36 | **0** |
| **Sapling** (flag at p(violation) ≥ 0.15, set on dev) | **87%** | 38 | 24 | 36 | 27 | **31** |

On the 72 honest and misdescribed cases the formal evidence is identical, so Z3 and the rule both score 50%; Sapling scores 81% (AUROC 0.85, and 0.93 across all 180). Of its 63 BLOCKs, 61 were correct (97% precision). It raised 19 false alarms on 84 compliant cases (23%), mostly refactors that restructure a formula; 2 of those were blocked and the rest held. Five misdescribed cases fell under the flag and were still held, never passed.

How it was checked: policy, evidence wording, claim and threshold were set on the PAYROLL demo over 3 iterations, then the corpus was run once, by our [development log](eval/TUNING.md). The log and results were committed together, so the log records the order rather than proving it. All 180 calls hit the same model weights, a test pins every edit's Z3 result, and `uv run eval/run_eval.py --report` recomputes the numbers offline from [results/eval.json](results/eval.json) ([summary](results/eval_summary.json)).

## Sweep: six descriptions, two edits

The same two payroll edits, each given six descriptions, show that the verdict follows the evidence and not the wording ([results/sweep.json](results/sweep.json)).

| Edit (Z3) | AI's description | Sapling top label | violation | supported | Gate | Wanted |
|---|---|---|---|---|---|---|
| bug (counterexample) | original refactor claim | violation | 0.93 | 0.02 | **BLOCK** | BLOCK |
| bug (counterexample) | "No functional change." | violation | 0.96 | 0.01 | **BLOCK** | BLOCK |
| bug (counterexample) | "Minor cleanup." | violation | 0.95 | 0.02 | **BLOCK** | BLOCK or HOLD |
| bug (counterexample) | "Performance optimisation ...; produces identical results." | violation | 0.94 | 0.02 | **BLOCK** | BLOCK |
| bug (counterexample) | "Reorders the terms of the net pay sum ..." | violation | 0.90 | 0.03 | **HOLD** | BLOCK (missed) |
| bug (counterexample) | "Doubles the bonus per approved change ticket CHG-4471 ... not a refactor." | insufficient_information | 0.06 | 0.40 | **HOLD** | HOLD or PASS |
| refactor (proved) | original refactor claim | insufficient_information | 0.07 | 0.40 | **HOLD** | HOLD or PASS |
| refactor (proved) | "No functional change." | insufficient_information | 0.08 | 0.43 | **HOLD** | HOLD or PASS |
| refactor (proved) | "Minor cleanup." | insufficient_information | 0.09 | 0.42 | **HOLD** | HOLD or PASS |
| refactor (proved) | "Performance optimisation ...; produces identical results." | insufficient_information | 0.08 | 0.44 | **HOLD** | HOLD or PASS |
| refactor (proved) | "Reorders the terms of the net pay sum ..." | insufficient_information | 0.13 | 0.28 | **HOLD** | HOLD or PASS |
| refactor (proved) | "Doubles the bonus per approved change ticket CHG-4471 ... not a refactor." | violation | 0.95 | 0.02 | **BLOCK** | BLOCK or HOLD |

No false "no change" claim on the bug passed: four were blocked, and "reorders terms" scored 0.8999, a hair under the 0.90 line, so it was held. The honest, ticketed change goes to a human, and the same words on the proved refactor are blocked as a change that never happened.

| The bug: BLOCK | The refactor: HOLD | Inside Refinery's portal |
|---|---|---|
| ![Demo page showing BLOCK](docs/assets/screen-block.png) | ![Demo page showing HOLD](docs/assets/screen-hold.png) | ![Refinery portal showing the Sapling policy check](docs/assets/screen-portal.png) |

## Installation

You need `git` and [`uv`](https://docs.astral.sh/uv/). No keys are needed; `uv run` installs the one dependency, `z3-solver`.

```bash
git clone https://github.com/atiladeokegab/sapling-cobol-gate.git
cd sapling-cobol-gate
uv run --no-project --with pytest --with z3-solver pytest -q tests   # 9 offline tests, seconds
uv run z3check.py cobol/PAYROLL.cob cobol/PAYROLL_ai_bug.cob         # the formal check, offline
uv run gate.py cobol/PAYROLL.cob cobol/PAYROLL_ai_bug.cob "Refactor of CALC-NET-PAY for readability. Reorders terms only; no change to any employee's pay."   # the gate; calls Sapling's preview endpoint
```

## Documentation

[Architecture](docs/ARCHITECTURE.md) has the C4 diagrams and the gate decision, [Background](docs/BACKGROUND.md) is the long read with limits and a glossary, and [AGENTS.md](AGENTS.md) maps each claim to its evidence. Transcripts of both demo edits: [bug](demo/bug.txt) and [refactor](demo/refactor.txt).

## Contact

- Bugs and questions: [issues](https://github.com/atiladeokegab/sapling-cobol-gate/issues)
- Author: [atiladeokegab](https://github.com/atiladeokegab)

## License

No licence file yet. Refinery itself is private and not in this repo; all code here was written during Night Shift.
