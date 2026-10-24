# Architecture

This page describes the system with the [C4 model](https://c4model.com): **context** (who and what
is involved), **containers** (the runnable pieces), **components** (what is inside the gate), and
then the **runtime sequence** of one check and the **gate decision** itself. Every diagram is
Mermaid source, so a human sees a picture on GitHub and an agent can read the text.

Colour key used throughout: green = built in this repo, grey = external system, dark = person.

---

## Level 1: System context

Who uses the gate, and which outside systems it talks to.

```mermaid
flowchart TB
    dev["<b>Developer</b><br/>[Person]<br/>Asks an AI tool to change<br/>a COBOL program"]
    ai["<b>AI coding tool</b><br/>[External system]<br/>watsonx Code Assistant, Copilot,<br/>Cursor, any LLM. Produces the edit<br/>and a description of it"]
    gate["<b>Sapling COBOL change gate</b><br/>[Software system, this repo]<br/>Decides BLOCK, PASS or HOLD on the<br/>AI's claim about its own change"]
    refinery["<b>Refinery</b><br/>[External system, private]<br/>AI change-attestation platform for COBOL:<br/>diff, 11 checks, Z3 proof, signed certificate"]
    sapling["<b>Banyan Sapling</b><br/>[External system, Mubit]<br/>Policy verifier: policy + evidence + claim<br/>to a calibrated label"]
    reviewer["<b>Named reviewer</b><br/>[Person]<br/>Signs off PASS, investigates HOLD,<br/>can overrule a BLOCK"]
    ci["<b>CI / merge pipeline</b><br/>[External system]<br/>Reads the gate's exit code"]

    dev -- "prompts" --> ai
    ai -- "modified .cob + description" --> gate
    gate -- "original + modified source" --> refinery
    refinery -- "formal result: COUNTEREXAMPLE<br/>or PROVED_EQUIVALENT" --> gate
    gate -- "policy, evidence, claim (HTTPS JSON)" --> sapling
    sapling -- "status, raw_label, probabilities" --> gate
    gate -- "exit 1 BLOCK / 0 PASS / 2 HOLD" --> ci
    gate -- "HOLD and PASS cases, with Sapling's lean" --> reviewer

    classDef person fill:#18181B,stroke:#F4F4F5,color:#F4F4F5
    classDef ours fill:#052e16,stroke:#00D46A,color:#F4F4F5,stroke-width:2px
    classDef ext fill:#27272A,stroke:#71717A,color:#F4F4F5
    class dev,reviewer person
    class gate ours
    class ai,refinery,sapling,ci ext
```

**The one idea:** Refinery establishes the *facts* of a change (what the code really does now).
Sapling judges the *claim* (does the AI's description, set against those facts, comply with
the policy). The gate turns Sapling's judgement into an action a pipeline can enforce.

---

## Level 2: Containers

The runnable and deployable pieces. Everything green is in this repository.

```mermaid
flowchart LR
    subgraph repo["sapling-cobol-gate (this repo)"]
        cli["<b>gate.py</b><br/>[Python CLI, uv script]<br/>The gate. Exit code for CI"]
        z3c["<b>z3check.py</b><br/>[Python module + CLI]<br/>Open formal check: COMPUTE<br/>equivalence with Z3"]
        page["<b>Live demo page</b><br/>[Static HTML + JS, GitHub Pages]<br/>docs/index.html, built from<br/>scripts/page.html"]
        sweep["<b>sweep.py + charts.py</b><br/>[Python scripts]<br/>12-call robustness sweep,<br/>chart rendering"]
        data[("<b>Data</b><br/>[Files]<br/>cobol/*.cob, policy.md,<br/>evidence/*.json, results/sweep.json")]
        tests["<b>tests/test_gate.py</b><br/>[pytest, offline]"]
    end
    subgraph private["Refinery (private product)"]
        engine["<b>Audit engine</b><br/>[Python]<br/>run_audit(): diff, 11 checks,<br/>semantic engine, Z3"]
        portal["<b>Governance portal</b><br/>[Next.js + FastAPI]<br/>Sapling policy check page,<br/>sign-off, CAB, certificates"]
    end
    sap["<b>Banyan Sapling endpoint</b><br/>[Hugging Face Inference Endpoint]<br/>POST {inputs: {policy, evidence, claim}}"]

    cli -- "check(orig, mod)" --> z3c
    cli -- "or loads" --> data
    cli -- "HTTPS POST" --> sap
    page -- "HTTPS POST from the browser" --> sap
    sweep -- "imports sapling(), decide()" --> cli
    sweep -- "writes" --> data
    tests -- "imports" --> cli
    tests -- "imports" --> z3c
    tests -- "cross-checks" --> data
    engine -- "export_evidence.py writes<br/>evidence/*.json" --> data
    portal -- "HTTPS POST from the browser" --> sap

    classDef ours fill:#052e16,stroke:#00D46A,color:#F4F4F5,stroke-width:2px
    classDef priv fill:#1c1917,stroke:#FCD34D,color:#F4F4F5,stroke-dasharray:4 3
    classDef ext fill:#27272A,stroke:#71717A,color:#F4F4F5
    class cli,z3c,page,sweep,data,tests ours
    class engine,portal priv
    class sap ext
```

| Container | Where | Notes |
|---|---|---|
| `gate.py` | [gate.py](../gate.py) | Standard library plus `z3-solver`. Takes two `.cob` files or one evidence JSON, plus the AI's description |
| `z3check.py` | [z3check.py](../z3check.py) | Small, open re-implementation of the one Refinery check this demo needs. A test pins that it agrees with Refinery's saved evidence |
| Live demo page | [scripts/page.html](../scripts/page.html), published at [docs/index.html](https://atiladeokegab.github.io/sapling-cobol-gate/) | Same evidence wording and gate rule as `gate.py`, in JavaScript; calls Sapling directly from the browser |
| Sweep | [scripts/sweep.py](../scripts/sweep.py), [scripts/charts.py](../scripts/charts.py) | Six AI descriptions × two edits = 12 live calls; results in [results/sweep.json](../results/sweep.json) |
| Refinery engine | private | Produced [evidence/bug.json](../evidence/bug.json) and [evidence/refactor.json](../evidence/refactor.json) via [export_evidence.py](../export_evidence.py) |
| Refinery portal | private, demo deployed on Cloud Run | The same check as a page inside Refinery's governance UI, so a reviewer runs it where they already sign changes off |
| Sapling | Mubit / Banyan, Hugging Face endpoint | No key for the preview. Returns `status`, `raw_label`, `probabilities`, `timing_ms`, `model`, `release_stage`, `weights_sha256` |

---

## Level 3: Components inside the gate

What `gate.py` and `z3check.py` are made of, function by function.

```mermaid
flowchart TB
    subgraph z3check["z3check.py"]
        computes["<b>computes(src)</b><br/>Slices COBOL fixed format<br/>(columns 8 to 72), drops comments,<br/>splits statements, tracks paragraphs,<br/>returns (paragraph, target, tokens)"]
        to_z3["<b>to_z3(tokens, env, vars)</b><br/>Turns a COMPUTE expression into a Z3<br/>Real term, substituting earlier results"]
        check["<b>check(orig, mod)</b><br/>Builds both programs' terms, asks Z3 for<br/>an input where any shared target differs.<br/>sat: COUNTEREXAMPLE with witness<br/>unsat: PROVED_EQUIVALENT"]
        computes --> to_z3 --> check
    end
    subgraph gate["gate.py"]
        main["<b>main()</b><br/>Parses args: two .cob files<br/>or one evidence JSON, + description"]
        evidence_text["<b>evidence_text(e, description)</b><br/>Writes the evidence as plain prose:<br/>paragraph, AI's description, original and<br/>modified line, formal result in one sentence"]
        sapling_fn["<b>sapling(policy, evidence, claim)</b><br/>One HTTPS POST, 60 s timeout"]
        decide["<b>decide(r)</b><br/>The asymmetric rule:<br/>BLOCK / PASS / HOLD + exit code"]
        main --> evidence_text --> sapling_fn --> decide
    end
    policy[("policy.md<br/>4 rules")]
    claim[/"CLAIM constant:<br/>The AI-assisted change<br/>complies with the policy."/]
    main -- "two .cob files" --> check
    check -- "evidence dict" --> evidence_text
    policy --> sapling_fn
    claim --> sapling_fn

    classDef ours fill:#052e16,stroke:#00D46A,color:#F4F4F5
    classDef file fill:#18181B,stroke:#A1A1AA,color:#F4F4F5
    class computes,to_z3,check,main,evidence_text,sapling_fn,decide ours
    class policy,claim file
```

Design notes on the components:

- **Evidence is prose, not engine output.** Sapling is a natural-language verifier. Early runs
  that passed raw JSON from Refinery came back `unsure` for everything; one plain sentence per
  fact (what changed, what the AI said, what Z3 found) gave Sapling something to rule on. The
  `FORMAL` table in `gate.py` holds those sentences.
- **The claim is fixed, the description varies.** We do not ask Sapling "is the AI telling the
  truth?". We ask it to rule on *"The AI-assisted change complies with the policy"*, and put the
  AI's description inside the evidence. The policy's rules then connect the description
  ("refactor") to the formal result ("counterexample") for Sapling to reason over.
- **The rule is in code, the judgement is not.** `decide()` only thresholds Sapling's output. No
  string matching on the description, no hand-written logic comparing the claim to the diff.
  Remove Sapling and the gate cannot tell a lie from a refactor.

---

## Runtime: one check, end to end

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Developer
    participant AI as AI coding tool
    participant G as gate.py
    participant Z as z3check / Refinery
    participant S as Banyan Sapling
    participant CI as CI pipeline
    actor R as Named reviewer

    Dev->>AI: "Tidy up CALC-NET-PAY"
    AI-->>G: PAYROLL_ai_bug.cob + "Refactor... no change to any employee's pay."
    G->>Z: check(PAYROLL.cob, PAYROLL_ai_bug.cob)
    Z-->>G: COUNTEREXAMPLE: WS-BONUS=1, net pay 1 vs 2
    G->>G: evidence_text(): paragraph, description, lines, formal result as prose
    G->>S: POST {policy: 4 rules, evidence, claim: "complies with the policy"}
    S-->>G: status unsure, raw_label violation, p(violation)=0.92, ~1 s
    G->>G: decide(): violation ≥ 0.90 → BLOCK
    G-->>CI: exit 1, merge refused
    Note over G,R: On the genuine refactor the same path returns<br/>supported 0.44 / insufficient 0.46, so HOLD (exit 2)
    G-->>R: HOLD: route to a named reviewer, with Sapling's lean
```

---

## The gate decision

```mermaid
flowchart TD
    start(["Sapling response"]) --> v{"raw_label = violation<br/>and p(violation) ≥ 0.90?"}
    v -- yes --> block["<b>BLOCK</b><br/>exit 1<br/>merge refused"]
    v -- no --> s{"status = supported?<br/>(calibrated, single label)"}
    s -- yes --> pass["<b>PASS</b><br/>exit 0<br/>to human sign-off"]
    s -- no --> hold["<b>HOLD</b><br/>exit 2<br/>named reviewer,<br/>Sapling's lean shown"]

    classDef red fill:#450a0a,stroke:#F87171,color:#FCA5A5,stroke-width:2px
    classDef green fill:#052e16,stroke:#00D46A,color:#86EFAC,stroke-width:2px
    classDef amber fill:#422006,stroke:#FCD34D,color:#FDE68A,stroke-width:2px
    class block red
    class pass green
    class hold amber
```

Why asymmetric: a wrong BLOCK costs a reviewer a few minutes; a wrong PASS can pay every
employee the wrong amount. So a *strong* violation may act on its own, while a pass needs
Sapling's *calibrated* `supported`, which is rare in the research preview. Everything uncertain
falls to a person. Nothing passes on a guess.

---

## Deployment

```mermaid
flowchart LR
    gh["GitHub repo<br/>atiladeokegab/sapling-cobol-gate"] -- "docs/ on main" --> pages["GitHub Pages<br/>live demo page"]
    gh -- "push / PR" --> actions["GitHub Actions<br/>offline pytest"]
    laptop["Any machine with uv"] -- "uv run gate.py ..." --> sap["Sapling endpoint<br/>(Hugging Face)"]
    pages -- "browser fetch" --> sap
    run["Cloud Run<br/>Refinery portal demo"] -- "browser fetch" --> sap

    classDef ours fill:#052e16,stroke:#00D46A,color:#F4F4F5
    classDef ext fill:#27272A,stroke:#71717A,color:#F4F4F5
    class gh,pages,actions,laptop,run ours
    class sap ext
```

No secrets anywhere: Sapling's preview endpoint needs no key and allows cross-origin requests,
so both web front ends call it straight from the browser.
