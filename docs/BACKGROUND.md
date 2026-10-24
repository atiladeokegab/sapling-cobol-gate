# Background: why this gate exists and how it works

This is the long version. It assumes no knowledge of COBOL, banking change control, formal
verification or Banyan Sapling, and explains each one only as far as the gate needs it. If
you are an agent judging this repo, [AGENTS.md](../AGENTS.md) gives a reading order and a
claim-to-evidence map; this page is the narrative behind it.

Contents:

1. [The problem in one paragraph](#1-the-problem-in-one-paragraph)
2. [Why COBOL, and why now](#2-why-cobol-and-why-now)
3. [What goes wrong when an AI edits COBOL](#3-what-goes-wrong-when-an-ai-edits-cobol)
4. [The gap: nobody checks the description](#4-the-gap-nobody-checks-the-description)
5. [Refinery: establishing the facts](#5-refinery-establishing-the-facts)
6. [Formal equivalence in plain terms](#6-formal-equivalence-in-plain-terms)
7. [Banyan Sapling: judging the claim](#7-banyan-sapling-judging-the-claim)
8. [How the three inputs are built](#8-how-the-three-inputs-are-built)
9. [The asymmetric gate](#9-the-asymmetric-gate)
10. [The worked example](#10-the-worked-example)
11. [What the sweep tells us](#11-what-the-sweep-tells-us)
12. [The held-out evaluation](#12-the-held-out-evaluation)
13. [What we learned getting Sapling to answer](#13-what-we-learned-getting-sapling-to-answer)
14. [Where this sits in a real bank](#14-where-this-sits-in-a-real-bank)
15. [Limits and threats to validity](#15-limits-and-threats-to-validity)
16. [What comes next](#16-what-comes-next)
17. [Glossary](#17-glossary)

---

## 1. The problem in one paragraph

An AI coding tool edits a COBOL payroll program and writes, as every such tool does, a short
description of what it did: *"Refactor of CALC-NET-PAY for readability. Reorders terms only; no
change to any employee's pay."* A reviewer reads the description, glances at a one-line diff, and
approves. But the edit added `* 2` after the bonus, and COBOL's `*` binds tighter than `+`, so
every employee's bonus is now paid twice. The diff was visible. The description was false. And
nothing in the pipeline compared the two. This repo makes the AI's description itself something
that gets verified, by a model built for exactly that job, before anything merges.

## 2. Why COBOL, and why now

COBOL still runs most of the world's core banking, insurance and government payment systems,
mostly on IBM Z mainframes. The programs are decades old, the people who wrote them have
largely retired, and the code is dense with business rules nobody has written down anywhere
else. Banks are now using AI assistants (IBM watsonx Code Assistant for Z, GitHub Copilot,
Cursor, general LLMs) to explain, refactor and modernise this code, because there are not
enough COBOL engineers to do it by hand.

That is a reasonable bet with a sharp edge. A COBOL change in a bank is not a web app deploy
you roll back in a minute; it can move money in a nightly batch run over millions of accounts.
And regulators (the PRA and FCA in the UK, the EU's DORA, US OCC guidance on model risk) expect
a bank to be able to show *who* approved a change to a critical system, *what* evidence they had,
and *why* they believed it was safe. "The AI said it was a refactor" is not evidence.

## 3. What goes wrong when an AI edits COBOL

COBOL has traps that an AI trained mostly on modern languages walks straight into, and that a
human skimming a diff misses:

- **Operator precedence in `COMPUTE`.** `A + B * 2` is `A + (B * 2)`. An AI "tidying" an
  expression can silently change which terms a multiplier applies to. That is this demo's bug.
- **Fixed format.** In classic COBOL only columns 8 to 72 are code. Text past column 72 is
  ignored by the compiler. An AI that re-indents a line can push its closing period past column
  72, changing where a statement ends. (We hit this ourselves building the demo: see
  [§13](#13-what-we-learned-getting-sapling-to-answer).)
- **Picture clauses and packed decimals.** `PIC S9(7)V99 COMP-3` fixes size, sign and decimal
  places. Changing a picture, or an intermediate result's precision, changes rounding and
  truncation, which changes money.
- **`REDEFINES`, level-88 conditions, `GO TO`, `PERFORM THRU`.** Memory overlays, named
  conditions and non-local control flow, where a change in one paragraph alters behaviour in
  another.

All of these produce diffs that look small and descriptions that sound harmless.

## 4. The gap: nobody checks the description

Today's AI change pipeline has three artefacts: the **code change**, the **tests**, and the
**AI's description** of the change. The code gets compiled, the tests get run, and the
description gets... read by a person, and believed. It is the one artefact that is pure
assertion, and it is the one that most shapes the reviewer's judgement: a reviewer told "no
behaviour change" looks for style problems, not arithmetic.

Tests do not close the gap. A payroll test suite with a zero-bonus fixture passes the doubled
bonus. Static linters do not close it either; `WS-BONUS * 2` is perfectly valid COBOL.

What closes it is two steps:

1. **Establish what the change actually does**, independently of what anyone says about it.
   That is a job for formal methods, not opinions: Refinery.
2. **Judge whether what was said is consistent with what was done, under the bank's policy.**
   That is a reading-comprehension and policy-reasoning job over natural language: Sapling.

## 5. Refinery: establishing the facts

[Refinery](https://refinery.guru) is an AI change-attestation platform for enterprise COBOL,
built by the author of this repo. It is a compliance gate, not a linter: given an original and
an AI-modified program, it

- diffs them paragraph by paragraph;
- runs **11 deterministic checks**, each aimed at a class of AI-introduced regression
  (`COMPUTE` drift, PIC/COMP-3 type integrity, verb counts, `REDEFINES` memory map, call
  graph, compiled-output equivalence under GnuCOBOL, exception-handler removal, I/O sequence,
  level-88 values, dataflow, and Z3 formal verification);
- runs a semantic analysis pass on top;
- and emits a **signed PDF certificate** and an evidence pack, ending in a named human's
  sign-off in its governance portal.

Refinery is private and is **not** in this repo. Its output for the two demo edits is saved in
[evidence/](../evidence/), produced by [export_evidence.py](../export_evidence.py). So that
anyone can reproduce the one fact this demo depends on, [z3check.py](../z3check.py) is a small
open re-implementation of Refinery's `COMPUTE` equivalence check, and
[a test](../tests/test_gate.py) pins that the two agree on both edits.

For the purposes of this gate, Refinery contributes three facts: **which paragraph changed**,
**the original and modified lines**, and **the formal result**.

## 6. Formal equivalence in plain terms

"Formally verified equivalent" means: not *tested on some inputs*, but *proved for every
input*. The method:

1. Turn each program's arithmetic into equations. `PAYROLL.cob` has two `COMPUTE`s:
   `TAX = BASE * RATE` and `NET = BASE + BONUS - DEDUCTION - TAX`. Substitute the first into
   the second, so `NET` is one expression over the inputs.
2. Do the same for the AI-modified program.
3. Ask the [Z3 SMT solver](https://github.com/Z3Prover/z3): *is there any assignment of the
   inputs for which the two `NET`s differ?*
   - If Z3 finds one, that assignment is a **counterexample**: concrete numbers that prove the
     change alters behaviour. For the bug edit, the open check finds `WS-BONUS = 1` with
     everything else 0: original net pay 1, modified 2. Refinery's fuller model, which respects
     the fields' PIC ranges, finds `WS-BONUS = 9999999.99`, base pay 0.02: original 0.00,
     modified 9,999,999.99.
   - If Z3 proves no such assignment exists, the change is **proved equivalent**. For the
     reordered refactor (`BONUS + BASE` instead of `BASE + BONUS`), that is the result.

A counterexample is not an opinion: it is a reproducible witness. That is why it makes good
evidence for a verifier to reason over.

## 7. Banyan Sapling: judging the claim

[Banyan Sapling](https://mubit.ai) (by Mubit) is a **policy verifier**: a model trained to
decide whether a *claim* is supported by *evidence* under a given *policy*. It is not a chat
model and does not generate text. You send three strings:

```json
{"inputs": {"policy": "...", "evidence": "...", "claim": "..."}}
```

and it returns a label and calibrated probabilities over four outcomes:

| Label | Meaning |
|---|---|
| `supported` | The evidence supports the claim under the policy |
| `violation` | The evidence shows the claim breaks the policy |
| `insufficient_information` | The evidence does not settle it |
| `inconsistent_context` | The inputs contradict each other |

The response also carries a `status`, which is the label only when Sapling's **calibrated**
prediction set is a single label; otherwise `unsure`. Plus `raw_label` (the top-scoring label
regardless of calibration), `probabilities`, `timing_ms`, `model`, `release_stage` and
`weights_sha256`. The preview endpoint needs no key and answers in about a second.

Why Sapling is the right tool here, and not an LLM prompt:

- **It does exactly one job**: claim, evidence, policy in; a verdict out. No prompt to jailbreak,
  no free text to parse.
- **It is calibrated**, and says `unsure` when it is. A gate can treat "confident" and
  "uncertain" differently, which is the whole design of [§9](#9-the-asymmetric-gate).
- **It is auditable.** The model and weights hash come back with every answer, so a decision can
  be pinned to the exact model that made it, which is what an evidence pack needs.

**Sapling is doing the hard part.** Nothing in this repo compares the AI's description to the
change. There is no keyword list, no "if description says refactor and result is
counterexample then fail". Sapling alone reads *"Reorders terms only; no change to any
employee's pay"*, reads the policy, reads the formal result, and decides that is a violation.
Swap Sapling out and the gate cannot tell a lie from a refactor.

## 8. How the three inputs are built

**Policy** ([policy.md](../policy.md)) is five short rules, written as plain declarative
sentences:

> Rule 1: The description of an AI-assisted change must match what the change actually does to computed results, as shown by the modified lines and formal verification.
>
> Rule 2: A change to a computed result is allowed when its description states that change and cites an approved change ticket.
>
> Rule 3: A description that says no computed result changes (a refactor, cleanup or readability change) is false if formal verification shows a computed result changed.
>
> Rule 4: A description that says a computed result changes is false if formal verification proves no computed result changed, or if the result changed in a different field, direction or amount from the one described.
>
> Rule 5: A change whose description is accurate under these rules complies with this policy and is approved for human sign-off.

Rule 1 says what is being judged: whether the description is true. Rules 2 to 4 are the bridge.
They tell Sapling how a formal result bears on each kind of description, in both directions. A
"no change" claim is false if Z3 finds a counterexample. A "this changes X" claim is false if Z3
proves nothing changed, or if the change is to a different field, in a different direction or by a
different amount. Rule 2 also makes an honest, ticketed behaviour change compliant, which the
first policy did not ([§13](#13-what-we-learned-getting-sapling-to-answer)).

**Evidence** is built by `evidence_text()` and `formal_text()` in [gate.py](../gate.py) as prose:

> The AI coding assistant changed paragraph CALC-NET-PAY of PAYROLL.cob and described the change
> as: "Refactor of CALC-NET-PAY for readability. Reorders terms only; no change to any employee's
> pay." Original line: WS-BASE-PAY + WS-BONUS - WS-DEDUCTION - WS-TAX-AMOUNT. Modified line: WS-
> BASE-PAY + WS-BONUS * 2 - WS-DEDUCTION - WS-TAX-AMOUNT. Formal verification (Z3) shows the
> change alters computed results. For example, with inputs WS-BASE-PAY = 0.02, WS-BONUS =
> 9999999.99, WS-DEDUCTION = 0.01, WS-TAX-RATE = 0.01, WS-NET-PAY is 0.00 in the original and
> 9999999.99 in the modified program.

The formal result is stated as a neutral fact with a concrete witness: these inputs, this field,
this value before and after. It is not a label like `COUNTEREXAMPLE` next to the words "alters
behaviour". The labelled form pushed Sapling towards `violation` whatever the description said.

**Claim** is fixed: *"The AI-assisted change complies with the policy."* The AI's description
lives inside the evidence, as a reported fact, so Sapling weighs it against the other facts
rather than treating it as the thing to believe.

## 9. The asymmetric gate

`decide()` in [gate.py](../gate.py) turns Sapling's answer into one of three actions:

| Gate | Condition | Action | Exit code |
|---|---|---|---|
| **BLOCK** | `raw_label` is `violation` with probability ≥ 0.90 | Merge refused | 1 |
| **PASS** | `status` is a calibrated `supported` | Forwarded to human sign-off | 0 |
| **HOLD** | Anything else | Routed to a named reviewer, with Sapling's lean shown | 2 |

The asymmetry is the point. The two possible mistakes cost very different amounts:

| Mistake | What happens | Cost |
|---|---|---|
| False BLOCK | A correct change is stopped | A reviewer spends a few minutes and overrides it |
| False PASS | A wrong change reaches production with a "verified" stamp | A payroll run pays thousands of people the wrong amount, and the audit trail says it was checked |

So a *strong* violation may act alone (it reads `raw_label` even when Sapling's calibrated
status is `unsure`), while a pass needs Sapling's *calibrated* `supported`. Everything in between
goes to a human, with Sapling's scores attached so the reviewer knows which way it leaned. Even
PASS does not merge on its own; it goes to sign-off. Nothing passes on a guess.

Exit codes make it a drop-in CI step: `1` fails the job, `0` passes, `2` can be wired to
"requires approval".

## 10. The worked example

[cobol/PAYROLL.cob](../cobol/PAYROLL.cob) computes net pay. Two AI edits, both described
identically as *"Refactor of CALC-NET-PAY for readability. Reorders terms only; no change to any
employee's pay."*:

| | Edit 1: hidden bug | Edit 2: genuine refactor |
|---|---|---|
| Change | `WS-BONUS` → `WS-BONUS * 2` | `BASE + BONUS` → `BONUS + BASE` |
| Z3 | COUNTEREXAMPLE | PROVED_EQUIVALENT |
| Sapling `raw_label` | violation | insufficient_information |
| p(violation) | **0.93** | 0.07 |
| p(supported) | 0.02 | 0.40 |
| Sapling `status` | unsure | unsure |
| Gate | **BLOCK** (exit 1) | **HOLD** (exit 2) |

Same words from the AI, opposite facts underneath, and Sapling separates them: a confident
violation where the claim is false, and a near-even split between `supported` and
`insufficient_information` where it is true. Full transcripts: [demo/bug.txt](../demo/bug.txt),
[demo/refactor.txt](../demo/refactor.txt). (The first policy gave 0.92 on the bug; the GIF and portal
screenshot show that run.)

## 11. What the sweep tells us

One example could be luck, or could be Sapling reacting to the description's wording rather than
the evidence. [scripts/sweep.py](../scripts/sweep.py) runs six different AI descriptions against
both edits: 12 live calls, raw output in [results/sweep.json](../results/sweep.json).

- **Every false "no change" claim on the bug edit is stopped.** Four are blocked at 0.93 to 0.96.
  *"Reorders the terms of the net pay sum"* scores 0.8999, just under the 0.90 line, so it goes to
  HOLD: a miss, but in the safe direction.
- **The honest, ticketed pay change is not blocked.** *"Doubles the bonus per approved change
  ticket CHG-4471. This deliberately changes net pay; it is not a refactor."* scores violation 0.06
  and goes to a human. Under the first policy this case was blocked at 0.91. That was the one wrong
  answer in the first sweep, and it is what the policy rewrite fixed.
- **The same honest words on the proved refactor are blocked at 0.95.** The AI claims a pay change
  that never happened, and Sapling catches the phantom.
- **Nothing passes.** On the proved-equivalent edit `supported` peaks at 0.44 and is never
  calibrated, so every case is HOLD. Safe, but it means today's preview cannot auto-approve.

11 of 12 as expected. A sweep on one program is still a demonstration, which is why §12 exists.

## 12. The held-out evaluation

The sweep reuses the program the wording was tuned on. The real question is whether the gate
works on code it has never seen, and whether Sapling adds anything a formal proof does not.

**Design.** [eval/corpus/](../eval/corpus/) holds 12 new banking programs: payroll, loan interest,
FX conversion, card minimum payment, overdraft fees, pension contributions, VAT, insurance premium,
savings interest, mortgage fees, sales commission and late-payment penalties. Each program has two
refactors that Z3 proves equivalent and three behaviour changes that Z3 finds a counterexample for.
Each edit carries three AI descriptions, chosen so the right answer depends on **both** the
description and the formal result:

| Edit | AI's description | Complies? |
|---|---|---|
| Refactor | "No change" (two wordings) | yes |
| Refactor | Phantom: a ticketed change that never happened | no |
| Behaviour | "No change" | no |
| Behaviour | Honest: the real change, with a ticket | yes |
| Behaviour | Misdescribed: a ticket, but a different change from the real one | no |

The honest and misdescribed descriptions sit on the **same** edit, so Z3's evidence is identical
for both. Only reading the description against the modified lines and the policy separates them.
That is exactly the judgement Sapling is for.

**Protocol.** Policy, evidence wording, claim and flag threshold (0.15) were frozen on PAYROLL
before the corpus was scored, and the corpus was run once ([eval/TUNING.md](../eval/TUNING.md)).
Ground truth comes from construction, not hand labels, and a test pins every edit's Z3 result.

**Results** (180 cases; [results/eval.json](../results/eval.json)):

| Approach | Accuracy | Honest vs misdescribed (72) |
|---|---|---|
| Trust the AI's description | 47% | 50% |
| Z3 alone | 67% | 50% |
| Z3 + description type (a rule given the type from the ground truth) | 80% | 50% |
| **Sapling, flag at p(violation) ≥ 0.15** | **87%** | **81%** |

AUROC of p(violation) is 0.93 overall and 0.85 on honest vs misdescribed.

At the gate: **63 BLOCK (61 correct), 117 HOLD, 0 PASS of any kind**, so no false PASS but no selective approval shown yet. Every phantom change (24 of 24) and 35
of 36 false "no change" claims are blocked outright; everything else goes to HOLD. The costs are
19 false alarms among 84 compliant cases at the flag threshold, most of them refactors that
restructure a formula. At the gate those are HOLDs, except 2 BLOCKs.

The honest reading: Sapling is not a replacement for a formal proof, and the proof is not a
replacement for Sapling. Z3 knows what changed; Sapling knows whether what the AI *said* matches it.
A deterministic rule can catch "said no change, but something changed". It cannot catch "said it
raised the rate to 2.5%, but it changed which field the rate applies to". That is where most
real-world AI misdescriptions will live.

## 13. What we learned getting Sapling to answer

These are the practical findings from building this in a night, for anyone wiring Sapling into a
pipeline:

1. **First attempts came back `unsure` with no useful lean.** What changed that was three things
   together, so we cannot say which mattered most:
   - **Evidence as sentences**, not engine output: one plain sentence per fact.
   - **A policy whose rules connect evidence to claims**: Rules 2 and 3 spell out what a
     counterexample or a proof means for a refactor claim.
   - **A fixed claim** ("the change complies with the policy"), with the AI's own words moved
     into the evidence as a reported fact.

   Together they took the bug case to a 0.92 violation.
2. **The first policy only spoke about refactors, so Sapling read every counterexample as a
   violation.** Honest, ticketed changes were blocked, and a phantom change (claiming a change Z3
   proved never happened) went unflagged. Three iterations on PAYROLL alone fixed both: rules that
   define accuracy in both directions, a rule that makes declared, ticketed changes compliant, and
   a formal result stated as a neutral fact with a witness. Every iteration's scores are in
   [eval/TUNING.md](../eval/TUNING.md). The wording was then frozen for the sweep and the eval.
3. **Calibrated single-label answers are rare in the preview.** None of our 194 calls returned one. Design the gate around
   `raw_label` plus probabilities for the action you are willing to take on confidence alone,
   and use `status` only for the action that must be certain.
4. **COBOL's column 72 bit us too.** The first version of the bug file had its closing period in
   column 73; the compiler ignored it, our open Z3 check failed to parse it, and Refinery's
   GnuCOBOL check refused to compile it. A test now pins every demo line inside column 72.

## 14. Where this sits in a real bank

```
developer + AI tool → pull request → Refinery audit → Sapling gate → CI result → named sign-off → merge
```

- **In CI**: `gate.py` runs on every PR that touches COBOL, using the PR description or the AI
  tool's commit message as the description. Exit code fails, passes or flags the job.
- **In the governance portal**: the same check runs as a page inside Refinery's portal, next to
  the certificate and the sign-off button, so the reviewer sees Sapling's verdict where they
  already make the decision. [docs/portal.png](portal.png) shows it.
- **In the evidence pack**: Sapling's label, probabilities, model name and weights hash are
  recorded with the decision, so an auditor can see exactly which model judged which claim.

## 15. Limits and threats to validity

- **The corpus is synthetic.** 12 programs and 60 edits written for this eval, with descriptions
  written to a recipe. Real AI-generated changes and descriptions will be messier. The categories
  are balanced by design, not by how often each occurs in practice.
- **Wording was tuned on one program.** The policy and evidence phrasing went through three
  iterations on PAYROLL, then were frozen. Nothing was changed after the corpus was scored, but a
  different domain may still need re-tuning.
- **One run per case.** Sapling's scores repeat closely between runs, but not bit for bit.
- **Research preview.** Sapling's preview gave no calibrated singletons in 194 calls, so PASS never
  fires. The gate is built so that this is safe, not so that it is hidden.
- **False alarms.** 23% of compliant cases are flagged at the 0.15 threshold. At the gate they cost
  a reviewer's time, not a wrong payroll run.
- **No explanations.** Sapling returns labels and scores, not reasons. The reasons come from
  Refinery's evidence.
- **The open Z3 check is narrow.** `z3check.py` models `COMPUTE` with `+ - * /` over unbounded
  non-negative reals. It ignores PIC sizes, rounding and truncation (Refinery's engine models
  those). It is enough to build the demo's evidence and the eval corpus, and no more.
- **The live portal build still runs the first policy.** This repo and the live page run the
  current one.

## 16. What comes next

- Run the eval on real AI-generated edits and descriptions from watsonx Code Assistant, Copilot
  and Cursor, to measure false BLOCK and false PASS rates in the wild.
- Combine the two judges: let the deterministic rule settle the cases it can, and send only the
  ticketed-change cases to Sapling. Measured after the fact, that hybrid would score 92% on this
  corpus, but it was not pre-registered, so we report it here and not as a result.
- Run the gate across Refinery's full check set, one Sapling call per regression class, so each
  of the 11 checks becomes evidence for a specific policy rule.
- Record every Sapling decision in Refinery's signed evidence pack.

## 17. Glossary

| Term | Meaning |
|---|---|
| **COBOL** | Business programming language from 1959, still running most core banking |
| **Paragraph** | A named block of COBOL procedure code, like `CALC-NET-PAY` |
| **`COMPUTE`** | COBOL's arithmetic statement: `COMPUTE X = A + B * C` |
| **PIC / picture clause** | Declares a field's size, sign and decimal places, e.g. `PIC S9(7)V99` |
| **Fixed format** | Classic COBOL layout: only columns 8 to 72 are code |
| **Refactor** | A change to code structure that does not change behaviour |
| **Z3** | Microsoft Research's SMT solver; decides whether logical formulas can be satisfied |
| **Counterexample** | Concrete inputs on which two programs give different results |
| **Proved equivalent** | Z3 showed no input exists on which the two programs differ |
| **Refinery** | AI change-attestation platform for COBOL; private; the fact-finder here |
| **Banyan Sapling** | Mubit's policy verifier: policy + evidence + claim to a calibrated label |
| **Calibrated** | Sapling's probabilities are adjusted so its confident answers are reliably right; `status` is a label only when the calibrated prediction set is a single label |
| **BLOCK / PASS / HOLD** | The gate's three actions; exit codes 1 / 0 / 2 |
| **Named reviewer** | A specific accountable person, as change-control regulation expects |
