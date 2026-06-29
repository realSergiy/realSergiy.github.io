---
title: "Flow's OCaml-to-Rust Port"
author: realSergiy
date: 2026-06-29
description: How the Facebook Flow team mechanically ported their OCaml type checker to Rust with heavy AI assistance — the decisions, the agent workflow, and a 2x speedup. A summary of the team's own write-up.
---

> A summary of the [Facebook Flow](https://github.com/facebook/flow) team's engineering write-up, [*Flow's OCaml to Rust Port*](https://medium.com/flow-type/flows-ocaml-to-rust-port-78b95bcf49e9) by Sam Zhou (June 2026). The original post is the authoritative account; this is my condensed read of it, with commentary. The ported source now lives in the [`rust_port`](https://github.com/facebook/flow/tree/main/rust_port) Cargo workspace.

Flow's entire OCaml codebase has been ported to Rust by the Facebook Flow team. As of **v0.319** (released June 17, 2026), the `flow-bin` npm package ships the Rust binary. On large internal JavaScript codebases the Rust build was measured at roughly **2x faster** across most type-checking stages, and **30–100% faster** in the heaviest checking stage.

## Why it wasn't done sooner

The idea was first floated in 2019, when scalability limits in Meta's monorepos were biting. Back then a rewrite was judged too costly and slow — scalability would have broken before a rewrite could land — so it was shelved in favor of architectural work like Types-First.

For years the appeal stayed theoretical: a larger ecosystem, better IDE tooling, Rust's "fearless concurrency," and an escape from hard-to-debug, release-blocking OCaml CI breakages. None of that justified a multi-year rewrite with an uncertain payoff.

Three things in 2025 changed the math:

- **Pyrefly** — a Rust rewrite of Pyre (also from OCaml) inside Meta — delivered a 30x-plus speedup.
- **TypeScript** announced a Go port running ~10x faster than the JS implementation.
- Rapidly improving **AI coding agents** showed that the timeline for a mechanical port could be compressed dramatically.

Feasibility and benefit were both suddenly visible, and a Flow port moved from idle wish to serious plan.

## The decisions that shaped the project

**Rust, not Go or Kotlin.** Purely to leave OCaml, Go or Kotlin would have been the safer pick — all three share OCaml's mark-and-sweep GC model, sidestepping the perf regressions that come from swapping GC for manual allocation. The Flow team chose the riskier Rust path anyway, reasoning that the real prize was integration with the Rust-based JS toolchain (SWC, oxlint), and that a port worth doing once should be done in a language they wouldn't second-guess again.

**A line-by-line port, not a rewrite.** The goal was a drop-in replacement with no behavioral change, so a conservative mechanical port was chosen over a tempting-but-risky rewrite. The known cost: some accumulated bad decisions in the type checker got carried over verbatim. AI changes that "took too much liberty" were rejected to hold the line. The one deliberate exception was the shared-memory system, which was cleanly rewritten in Rust rather than porting the old C-based workaround that existed only because pre-5.0 OCaml lacked multithreading.

**Progress over idiomatic Rust.** A fully idiomatic port — studying a well-built Rust compiler for guidance — would likely have run even faster, but it would have demanded rethinking the OCaml design first, which conflicts with a line-by-line port. So idiomatic cleanup was deferred; in places the result is admittedly "OCaml written in Rust syntax," with `Rc` and `RefCell` standing in for the GC. Progress wasn't pursued at all costs, though: a strict **no-`unsafe`** rule was enforced for the AI, and the handful of `unsafe` blocks present were written intentionally by humans.

## A heavily AI-assisted port

**The parser came first.** Expectations were modest — just function-by-function migration. The mechanical nature of the work actually favored AI, which is less prone than a tired human to, say, dropping a token-consumption line during parsing. Even weaker models added enough judgment to avoid the ugliest literal translations (e.g. turning OCaml's `foo :: my_list` cons onto a list into an idiomatic Rust `Vec`). At the time (late 2025, Sonnet 4.5 the strongest model), agents could only port a few functions before degrading, so the loop was manual: prompt "port functions A, B, C," review, continue. Even so, the post's author ported the **entire parser solo in four weeks**, tests green, 2x faster — the proof point that secured the green light.

**Then the checker.** A month of porting supporting systems (module resolution, dependency analysis, signature extraction) came first, then the type checker itself. By this stage the frontier models were Opus 4.5/4.6, capable of much longer autonomous runs, and **agent teams** ported the far-more-complex checker in about a month. Discipline was kept through layered techniques:

- Reviewer agents that checked changes against the `claude.md` guidelines and rejected violations.
- A requirement that the AI keep the **original OCaml inline as comments** beside the Rust, so any non-line-by-line port had nowhere to hide (the comments were stripped after human review).
- A final human pass to catch any clever workarounds around the rules.

A code-complete pipeline arrived in early March — and on first run, **zero checker tests passed**. Continuous AI runs got them all green within a week; one overnight run alone took the pass rate from 20% to 60%. This is where the strict line-by-line rule paid off: because each Rust function mirrored a known-good OCaml original, agents could localize defects and humans could cheaply judge whether a fix was both correct and compliant.

**No code freeze.** CI was set up so the OCaml integration tests had to pass against the Rust implementation too. Normally keeping two codebases in lockstep would force a freeze on the original — but here it was nearly as cheap as appending "port this to Rust" to a prompt, since the groundwork already existed for agents to follow. The rest of the team kept shipping features throughout.

## Closing the performance gap

With the checker ported, the remaining systems followed quickly — but the early Rust build noticeably *under-performed* OCaml. Agents knocked out the obvious big-O problems fast. Persistent OOMs on large Flow roots pointed at a memory leak; agents traced it and fixed it by manually breaking reference cycles created by `Rc`/`RefCell`. After that, agents were pointed at profilers to chase hot spots — an ideal **Ralph-loop**, a clear goal with seemingly endless headroom, where AI steadily banked 1–2% wins that a time-pressed human would dismiss as noise but that compounded.

The honest caveat from the team: AI didn't crack everything. It sometimes burned days finding nothing, and the biggest gains — a work-stealing scheduler, and spotting implicitly repeated computations introduced by the port — came from human insight.

## Takeaways

The team frames their port on a spectrum from meticulous to fully autonomous: close to the React Compiler's Rust port, and between TypeScript's Go port and Bun's Rust port. They're explicit that it's too early to say whether they could have leaned on AI even harder, or should have slowed down in places — the post is offered as a case study in principled decisions plus aggressive-but-bounded agent use, not a victory lap.

A few things stand out to me:

- **The line-by-line constraint was the unlock, not a compromise.** It's what made agent output cheaply reviewable and defects locally fixable. A glamorous rewrite would have removed exactly the oracle (the original OCaml) that made the AI tractable.
- **Guardrails were structural, not aspirational** — reviewer agents, OCaml-as-comments, no-`unsafe`, human final pass. The interesting AI-engineering content here is the *review harness*, not the prompts.
- **The model timeline maps onto the work.** Manual few-function loops on Sonnet 4.5 for the parser; autonomous agent teams on Opus 4.5/4.6 for the checker. The scope of what they delegated tracked model capability quarter over quarter.
