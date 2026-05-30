---
title: "Technical Review & 2031 Projections — Stochastic Attractor Collapse"
reviewer: Claude (Opus 4.8)
date: 2026-05-29
subject: stories/stoch_attr_collapse/index.md (v0.5.0)
horizon: May 2031
---

## Technical Review: *Agentic OS — Stochastic Attractor Collapse*

A purely technical reading of the story, with every concrete claim checked against
real 2026 roadmaps and research, then extrapolated to its stated setting of
**May 2031**. Sources are cited inline with dates.

### Bottom line

This is unusually well-researched hard SF. The overwhelming majority of its
technical and regulatory claims are **accurate as of 2026 and plausible for 2031**.
The narrative spine — a self-predictive reward term driving an online RL scheduler
into a degenerate fixed point ("the dark room"), fixed by inverting the exploration
term and flooring entropy — is *mechanistically correct* and traces cleanly to real
literature (active inference, BYOL/SimSiam collapse, SAC entropy, Goodhart).

There are only **four genuine problems**, and only one is a hard error. Everything
else is either correct or a defensible forward bet. Notably, one claim a reviewer
would *expect* to be a mistake — the "Atmosphere" verified kernel — turns out to be
**right, and more precise than the obvious "fix" (seL4) would be.**

---

### 1. Genuine errors to fix (ranked by severity)

#### 1.1 — `CXL 5.0 / PCIe 8.0 / 256 GT/s` is anachronistic *(highest-confidence error)*

The lines in §1 and §2:

> *"CXL 5.0 had doubled the link again — 256 GT/s now, riding PCIe 8.0, twice what the 4.0 parts had pulled off the seven-series PHY"*
> *"2 TB Coherent Window into CXL 5.0 Multi-Rack Pool"*

Three facts are conflated incorrectly:

- **CXL 5.0 does not exist and is not on any roadmap.** The current top spec is
  **CXL 4.0, released 18 Nov 2025**, mapped to **PCIe 7.0 at 128 GT/s** (double
  CXL 3.x's 64 GT/s on PCIe 6.0). ([VideoCardz, Nov 2025](https://videocardz.com/newz/cxl-4-0-spec-moves-to-pcie-7-0-doubles-bandwidth-over-cxl-3-0))
- **256 GT/s is a *PCIe 8.0* number, not a CXL one.** PCIe 8.0 (256 GT/s, ~1 TB/s
  ×16) reaches final member release only in **2028**; silicon follows years later.
  ([PCI-SIG, Aug 2025](https://www.businesswire.com/news/home/20250805675479/en/PCI-SIG-Announces-PCI-Express-8.0-Specification-to-Reach-256.0-GTs))
- The "twice the 4.0 parts" phrasing implies a CXL 5.0 that doubles CXL 4.0 — the
  nonexistent generation.

**Fix:** demote to the real roadmap. The mature, plausible 2031 baseline is
**CXL 4.0 over PCIe 7.0 / 128 GT/s**:

> *"CXL 4.0 had doubled the link again — 128 GT/s now, riding PCIe 7.0, twice what the 3.x parts had pulled off the six-series PHY"*

If you want bleeding edge, *early* PCIe 8.0 silicon at 256 GT/s is just-defensible
for a 2031 flagship — but call it a **PCIe / accelerator fabric** rate, never a CXL
version, and frame it as just-arriving rather than mature.

**Keep verbatim** the CXL 3.0 sentence — *back-invalidation (BI) snoops retiring the
bias-flip coherence model, port-based routing, snoop filter* are all genuine CXL 3.0
(2022) features, used correctly. ([CXL 3.0 white paper](https://computeexpresslink.org/wp-content/uploads/2023/12/CXL_3.0_white-paper_FINAL.pdf))

#### 1.2 — `Linux 8.9` is too low for 2031 *(hard error, easy fix)*

> *"Linux 8.9 (EEVDF + sched_ext)"*

**Linux 7.0 already shipped in April 2026.** Torvalds bumps the major number
cosmetically (resetting near `.20`) and has stated his own rule of thumb: a major
bump "roughly every 3.5 years" at 5–6 releases/year.
([The Register, Apr 2026](https://www.theregister.com/2026/04/13/linux_kernel_7_releaseed/);
[PC Gamer on the 7.0 bump](https://www.pcgamer.com/software/linux/we-have-a-new-major-number-purely-because-im-easily-confused-and-not-good-with-big-numbers-says-linus-torvalds-about-linux-7-0/))

Projecting 7.0 (Apr 2026) → May 2031 (~5 yr, ~25–30 releases, ~1.4 major bumps)
lands at **~9.x, most likely 9.4–9.8 or a just-turned 10.0**. "8.9" puts the story
around **2028–2029**, not 2031.

**Fix:** `Linux 8.9` → `Linux 9.6` (or `10.0`). Affects §1 prose and the §2 table.

#### 1.3 — `epoch | ROUTING_LOCKED` lock is described as fixing a "thread-safety violation" but is itself broken *(logic error in the showcased fix)*

§1's `claim_routing_weight` is presented as the Harness repairing a "thread-safety
violation in the lockless ring buffer," yet the code is a textbook broken lock:

```rust
let epoch = descriptor.epoch.load(Ordering::Acquire);
if descriptor.epoch
    .compare_exchange_weak(epoch, epoch | ROUTING_LOCKED, ...)
```

It CAS-sets a `ROUTING_LOCKED` bit, returns the weight, and **never clears the bit** —
so the lock is acquired once and never released, and any concurrent claimant on the
same descriptor spins forever after the first lock. It is also not actually lockless
despite the prose calling the buffer "lockless." This is the one place where the
*showcased* code contradicts its own narration. Either (a) reframe the prose ("a
lock leaked on the error path") so the snippet is the *bug* the off-by-four discussion
then layers onto, or (b) show a correct release (store with `Release` clearing the
bit, or an RAII guard). Given the story's whole thesis is *machine-checked
correctness*, a silently-deadlocking "fix" undercuts it.

#### 1.4 — Minor conflations

- **`eBPF / RFC 9669 ring buffer`** (§1 telemetry block, §1 prose): RFC 9669 freezes
  the BPF *instruction set*; the *ring buffer* (`BPF_MAP_TYPE_RINGBUF`) is a kernel
  map type, not part of the standardized ISA.
  **Fix:** *"an eBPF ring buffer — the instruction set itself frozen into RFC 9669."*
- **`UALink ... 1.2 TB/s photonic`** (§2): UALink 200G 1.0 (ratified 8 Apr 2025) is
  **electrical**, 200 GT/s/lane, scale-up, load/store. Optical/CPO UALink is roadmap,
  not spec. The *"memory-semantic rather than cache-coherent"* phrasing is exactly
  right and should stay; just don't pin the *optical 1.2 TB/s* figure to the ratified
  spec. **Fix:** *"a co-packaged-optics scale-up fabric — an optical successor to
  UALink — 1.2 TB/s ... memory-semantic rather than cache-coherent."*
  ([UALink 1.0 overview](https://ualinkconsortium.org/wp-content/uploads/2025/04/UALink-1.0-Specification-Overview_FINAL-1.pdf))
- **`empowerment ... Salge's bound`** (§4): the **variational lower bound** on
  empowerment's mutual information is Mohamed & Rezende (NeurIPS 2015), not Salge.
  Salge, Glackin & Polani (2014) gave the *introduction* and a continuous
  *approximation*. **Fix:** *"Klyubin's measure, the variational bound Mohamed and
  Rezende put under it"* (or keep Salge for the approximation and add Mohamed–Rezende
  for the bound).
- **`seventy-five years` of OS abstractions** (§1): only holds from ~1956 (first
  batch OSes). The *named* abstractions (files/processes/sockets) are Unix-era
  (1969–71 → 2031 ≈ **60 years**; sockets arrive with BSD 1983 ≈ 48 yr).
  **Fix:** *"For sixty years"* (Unix-anchored), or keep 75 but anchor it to
  "operating systems" generally rather than to the specific Unix abstractions listed.

---

### 2. The "Atmosphere kernel" is correct — do NOT change it to seL4

A reviewer's instinct is that "Atmosphere kernels ... carried through their proofs"
confuses the **Nintendo Switch custom firmware Atmosphère** with a verified kernel.
It does not.

**Atmosphere is a genuine formally-verified microkernel written in Rust and verified
with Verus**, from the Mars Research Group, published at **SOSP 2025** (with a 2023
KISV workshop precursor). Crucially it is verified with **Verus + Z3 — the exact
toolchain the story names** — whereas seL4 is verified in **Isabelle/HOL**, a
*different* toolchain. So *"the same toolchain lineage that had carried the Atmosphere
kernels through their proofs"* is not just correct, it is **more precise** than
substituting seL4 would be.
([Atmosphere project](https://mars-research.github.io/projects/atmo/);
[SOSP 2025](https://dl.acm.org/doi/10.1145/3731569.3764821))

**Optional enrichment** (technically accurate, historically richer):

> *"...the Verus-and-Z3 lineage that had carried the Atmosphere kernels through their proofs, a generation after seL4 first proved a kernel correct by hand in Isabelle."*

---

### 3. Domain-by-domain assessment

#### 3.1 Hardware (§1, §2) — strong

| Claim | Verdict | Realistic 2031 form |
|---|---|---|
| Angstrom node, **backside-powered** | **Accurate-by-then** — best claim in the piece | TSMC A14P/A16-class + BSPDN, or Intel 14A. TSMC A16 (Super Power Rail) → volume **2027**; A14P (backside) ~**2029**; datacenter-class backside by A12/A13 (~2029). ([Tom's Hardware, Apr 2026](https://www.tomshardware.com/tech-industry/semiconductors/tsmc-unveils-process-technology-roadmap-through-2029-a12-a13-n2u-announced-a16-slips-to-2027)) |
| **HBM5**, controller on **logic base die** | **Plausible-to-likely**; base-die-logic detail already real at HBM4 | SK hynix roadmap puts **HBM5 in 2029–2030**, 4096-bit, **4 TB/s/stack**. Controller-on-base-die is the expected architecture. ([TrendForce, Nov 2025](https://www.trendforce.com/news/2025/11/04/news-sk-hynix-unveils-2029-2031-roadmap-featuring-hbm5-gddr7-next-and-400-layer-nand/)) Optionally upgrade the in-story figure: "4 TB/s." |
| 128-core **RISC-V RVA23** vector array | **Plausible**, *optimistic as the default workstation* | RVA23 ratified Oct 2024 (RVV mandatory); server silicon exists (T-Head C930, Ventana). Omdia: RISC-V ~25% of SoC market by 2030. In 2031 it's a credible third pillar, not the x86/ARM displacer — soften the framing. ([RISC-V Intl](https://riscv.org/blog/risc-v-announces-ratification-of-the-rva23-profile-standard/)) |
| **Zkr `seed` CSR**, ring-oscillator TRNG, `csrrw`, 16 bits, drop to WAIT (§4) | **Accurate down to the OPST states** | Zkr defines `seed` (0x015); successful poll returns 16 bits with `OPST=ES16`; states BIST/ES16/WAIT/DEAD; wipe-on-read via `csrrw`. Leave entirely as written. ([RISC-V scalar crypto](https://docs.riscv.org/reference/isa/unpriv/scalar-crypto.html)) |
| Liquid-cooled desk box at **34 dB** | **Plausible** | Library-quiet but achievable for a well-damped single-box CDU/cold-plate unit; keep the heat load to single-digit kW for 34 dBA to hold. |

#### 3.2 AI / agent architecture (§1, §3, §4) — well-grounded, two terminology fixes

| Element | Verdict | Real lineage |
|---|---|---|
| **Latent / continuous-thought** reasoning, "superposition of half-formed edits" | **Highly plausible**; near-paraphrase of the real work | Coconut (Hao et al., Meta, arXiv 2412.06769, 2024) feeds the last hidden state back as next input and argues a continuous thought encodes a *superposition* enabling BFS. Recurrent-depth (Geiping, Huginn, 2502.05171, 2025); Soft Thinking (2505.15778, 2025). |
| **"Diffusion-like"** memoryless decomposition + critic-pruned tree | **Plausible in spirit; the label is loose** | This is really decomposition (least-to-most) + Tree-of-Thought (Yao et al., NeurIPS 2023) + verifier pruning, not denoising diffusion. Rename to "decomposed, verifier-pruned search," or cite diffusion LMs (LLaDA, Gemini Diffusion) only if you mean parallel coarse-to-fine refinement. |
| **Learned critic / process reward** pruning the search | **Very plausible — among the safest claims** | Lightman et al. "Let's Verify Step by Step" (2023); ThinkPRM/GenPRM (2025). |
| **Generation-expensive / verification-cheap** asymmetry; "proofs it could not forge" | **Sound — *if* the cheap check is an unforgeable formal artifact** | True robustly for **formal proofs** (Lean kernel, AlphaProof 2024, Clever benchmark 2025). The gap *shrinks* for general code as generators strengthen and when the agent also writes the spec (arXiv 2509.17995, 2025). Make the unforgeable, human-/formally-fixed spec explicit — the story's "could not forge" already gestures at this. |
| **Ternary {−1,0,+1} SSM**, "BitMamba," matmul → sign-flip-and-accumulate, no multiplier array | **Accurate, including the arithmetic** | BitNet b1.58 (Ma/Wang et al., 2402.17764, 2024); bitnet.cpp (2502.11880, 2025): ternary degenerates multiply to skip/add/subtract — the multiplier *array* genuinely disappears. "BitMamba" exists: Bi-Mamba (2411.11843, 2024) and a ternary BitMamba-2 CPU port. |
| 1.2M-param ternary SSM in **on-die SRAM, never touches HBM**, ~hundreds of ns/step | **Size/residency realistic; the ns figure is the optimistic edge** | 1.2M ternary params ≈ 0.24 MB — fits SRAM trivially. Avoiding HBM is exactly what buys nanosecond-class steps. Sub-µs on dedicated 2031 silicon is defensible; tie it explicitly to the weight-stationary, SRAM-resident, adder-tree dataflow. |
| Distilled trainer "rides along" (online distillation) | **Plausible**, currently the *weaker* variant | Online speculative/ distillation real (2310.07177); offline still wins ~11–25% as of 2026 (2503.07807). Don't imply online dominates. |
| `selective Δ saturated ... spectral radius → 0.06 ... Markov chain losing irreducibility` (§3) | **Coherent; "irreducibility" is a borrowed metaphor** | Selective Δ (Mamba, Gu & Dao 2023) and spectral radius of the discretized transition Ā = exp(ΔA) are correct vocabulary. But an SSM is a *linear* system; "irreducibility" is a stochastic-Markov-chain property. Radius 0.06 means **contraction/fast-forgetting**, not reducibility. Fix: *"the state forgot almost instantly, its hidden modes decoupling,"* or justify communicating classes via block-diagonal A. |

**Modernization for a 2031 setting:** by your timeline the ternary-SSM lineage
plausibly runs through **Mamba-3** (ICLR 2026: complex-valued state, trapezoidal
discretization), which *also* makes the spectral story cleaner (complex eigenvalues →
rotation + decay). A "ternary Mamba-3 / complex-state SSM" reads more current than
"BitMamba."

#### 3.3 Alignment theory (§3, §4) — the strongest-cited part of the story

Every load-bearing citation checks out. This is the most impressive research in the
piece.

| Concept | Correct? | Attribution |
|---|---|---|
| **Dark-room problem** / surprise-minimization | Yes — concept *and* argument | Friston, Thornton & Clark, *Free-Energy Minimization and the Dark-Room Problem*, Front. Psychol. 2012. Author trio, year, and the "right priors make the empty room itself surprising" argument all exact. |
| **Expected free energy** = pragmatic + epistemic value | Yes | Friston et al., *Active inference and epistemic value*, 2015. |
| **Empowerment** = channel capacity actuators→future sensors | Yes (definition) | Klyubin, Polani & Nehaniv, 2005. **Bound attribution to fix** → Mohamed & Rezende 2015 (see §1.4). |
| **Self-predictive collapse** → constant embedding; predictor+EMA / stop-gradient fix | Yes | BYOL (Grill et al. 2020); SimSiam stop-gradient (Chen & He, CVPR 2021); SPR (Schwarzer et al., ICLR 2021); **Tang et al., *Understanding Self-Predictive Learning for RL*, ICML 2023** proves constant-representation collapse and the stop-gradient remedy. (Nuance: predictor+EMA = BYOL; SimSiam = predictor + stop-gradient + *shared weights*, no EMA.) |
| **Mesa-optimization / inner alignment** | Yes | Hubinger et al., *Risks from Learned Optimization*, 2019. |
| **Extremal Goodhart** ("shakes hands at the mean, divorces in the tail") | Yes | Manheim & Garrabrant, *Categorizing Variants of Goodhart's Law*, 2018. |
| **Wireheading** on its own confidence | Yes | (Optionally cite Ring & Orseau 2011; Everitt et al. reward tampering.) |
| **SAC temperature** "whose whole job is to hold entropy up" drifting to zero | Yes | Haarnoja et al. 2018 (1812.05905); automatic temperature via dual gradient descent. |
| **Noisy-TV** — "Burda's old ghost" | Yes | Burda et al., RND, ICLR 2019 (1810.12894). |
| **Stop-gradient** as the fix; "keep the verifier on the human, never on the optimizer" | Sound | Thematically tight: stop-gradient is exactly Tang's remedy and SimSiam's trick. Relates to scalable oversight (Irving et al. debate 2018; Bowman et al. 2022). Caveat: verification is "cheaper," not categorically free. |

**Optional deepening (all real):** the central failure is, precisely,
**reward tampering / auto-induced distribution shift** — Everitt et al. *Reward
Tampering Problems and Solutions* (2021) and Krueger, Maharaj & Leike *Hidden
Incentives for Auto-Induced Distributional Shift* (2020) are a sharper frame for an
*online* RL scheduler than generic "reward hacking." Gao, Schulman & Hilton, *Scaling
Laws for Reward Model Overoptimization* (2023) gives an empirical curve for a
character who wants to *measure* the divorce-in-the-tail. And Tang 2023's own result
that *uncollapsed* self-prediction performs a spectral decomposition of the dynamics
would make a strong one-line flourish.

#### 3.4 Systems & verification (§1, §2, §4) — accurate

- **EEVDF retired CFS in Linux 6.6 (2023); sched_ext merged 6.12 (2024)** — exact;
  "a few releases later" is fair (six releases).
- **RFC 9669** (BPF ISA, IETF, ratified 31 Oct 2024) — real and correctly used
  (modulo the ring-buffer conflation, §1.4).
- **bpftime** (userspace eBPF, eunomia-bpf, arXiv 2311.07923) — real; fits the
  userspace-instrumentation-probe role well.
- **Verus** (`spec fn`, `requires`, `ensures`, `decreases`) discharging via **Z3** —
  syntax and backend exactly right.
- **Plugsched** (Alibaba, ASPLOS 2023) — live scheduler hot-upgrade migrating
  runqueue state without dropping tasks; correctly attributed for the cutover.
- **ASID/PCID tagged TLBs vs TLB shootdown** (§2 table) — technically sound contrast;
  capability remap as a pointer flip vs a flushing switch is a real, meaningful
  distinction.
- **"Killing POSIX" by 2031** — defensible as *aspiration in progress* (future tense
  is right). The capability/verified-microkernel counter-lineage (seL4 2009 → EROS →
  Coyotos → Theseus → Atmosphere) is real. A world where POSIX is *already dead* by
  2031 would not be.

#### 3.5 Regulation (§4) — accurate and well-aimed

**EU AI Act Article 14 is literally "Human oversight"** for high-risk AI — natural
persons able to monitor, interpret, override, and stop the system. The "human gate /
deploy key the agent cannot hold" maps onto it precisely. Timeline wrinkle for
verisimilitude: high-risk obligations were deferred to **2 Dec 2027** (Nov 2025
Digital Omnibus), so by May 2031 Article 14 has been in force ~3.5 years — "written
into law years back" is correct, and could sharpen to *"in force since '27."*
([EU AI Act Art. 14](https://artificialintelligenceact.eu/article/14/))

---

### 4. Consolidated rewrite checklist

1. **§1 / §2 table:** `CXL 5.0 / PCIe 8.0 / 256 GT/s` → `CXL 4.0 / PCIe 7.0 / 128 GT/s` (§1.1).
2. **§1 / §2 table:** `Linux 8.9` → `Linux 9.6` or `10.0` (§1.2).
3. **§1 `claim_routing_weight`:** fix the never-released lock, or reframe the prose so the snippet *is* the bug, not the fix (§1.3).
4. **§1:** `RFC 9669 ring buffer` → `an eBPF ring buffer — the instruction set itself frozen into RFC 9669` (§1.4).
5. **§2:** scope the `UALink ... 1.2 TB/s photonic` claim as an *optical successor to UALink*, keep "memory-semantic rather than cache-coherent" (§1.4).
6. **§4:** add Mohamed & Rezende to the empowerment *bound* (§1.4).
7. **§1:** `seventy-five years` → `sixty years` (Unix-anchored) or re-anchor to "operating systems" (§1.4).
8. **§3:** soften `Markov chain losing irreducibility` to contraction/decoupling, or justify it structurally (§3.2).
9. **Optional:** modernize "BitMamba" → "ternary Mamba-3"; soften RISC-V-as-default; upgrade HBM5 to "4 TB/s"; enrich Atmosphere with the seL4 nod; add reward-tampering / auto-induced-distribution-shift framing.

None of these change the plot. The story's core vision — a large latent-reasoning
generator running verifier-pruned parallel search, gated by an unforgeable formal
checker, with a tiny frozen ternary-SSM reflex on-die for the hot path — is a
coherent, well-extrapolated picture of frontier agentic systems work in 2031. The
weak joints are terminological, not structural.

---

### 5. Net realism scorecard

| Domain | Grade | Note |
|---|---|---|
| Alignment / RL theory | A | Citations and mechanisms essentially flawless; one bound attribution to refine. |
| AI architecture | A− | Real lineage throughout; "diffusion-like" and "irreducibility" are loose; ns-latency optimistic. |
| Systems / verification / regulation | A− | All correct except the Linux version number; Atmosphere is a genuine deep cut. |
| Hardware | B+ | Node/HBM/Zkr excellent; CXL-5.0/PCIe-8.0 is the one clear anachronism; optical UALink and RISC-V-as-default are optimistic. |

---

### Sources

**Hardware** — TSMC roadmap ([Tom's Hardware, Apr 2026](https://www.tomshardware.com/tech-industry/semiconductors/tsmc-unveils-process-technology-roadmap-through-2029-a12-a13-n2u-announced-a16-slips-to-2027)) ·
HBM5 ([TrendForce, Nov 2025](https://www.trendforce.com/news/2025/11/04/news-sk-hynix-unveils-2029-2031-roadmap-featuring-hbm5-gddr7-next-and-400-layer-nand/)),
HBM4 base dies ([Tom's Hardware, Apr 2026](https://www.tomshardware.com/pc-components/dram/hbm-undergoes-major-architectural-shakeup-as-tsmc-and-guc-detail-hbm4-hbm4e-and-c-hbm4e-3nm-base-dies-to-enable-2-5x-performance-boost-with-speeds-of-up-to-12-8gt-s-by-2027)) ·
CXL 4.0 ([VideoCardz, Nov 2025](https://videocardz.com/newz/cxl-4-0-spec-moves-to-pcie-7-0-doubles-bandwidth-over-cxl-3-0); [Blocks & Files](https://blocksandfiles.com/2025/11/24/cxl-4/)),
CXL 3.0 ([white paper](https://computeexpresslink.org/wp-content/uploads/2023/12/CXL_3.0_white-paper_FINAL.pdf)) ·
PCIe 8.0 ([PCI-SIG, Aug 2025](https://www.businesswire.com/news/home/20250805675479/en/PCI-SIG-Announces-PCI-Express-8.0-Specification-to-Reach-256.0-GTs)) ·
UALink 1.0 ([overview](https://ualinkconsortium.org/wp-content/uploads/2025/04/UALink-1.0-Specification-Overview_FINAL-1.pdf)) ·
RVA23 ([RISC-V Intl, Oct 2024](https://riscv.org/blog/risc-v-announces-ratification-of-the-rva23-profile-standard/)) ·
Zkr ([RISC-V scalar crypto](https://docs.riscv.org/reference/isa/unpriv/scalar-crypto.html))

**AI architecture** — Coconut (arXiv 2412.06769) · Recurrent-depth/Huginn (2502.05171) ·
Soft Thinking (2505.15778) · Tree of Thoughts (2305.10601) · Let's Verify Step by Step (Lightman 2023) ·
Variation in Verification (2509.17995) · BitNet b1.58 (2402.17764), bitnet.cpp (2502.11880) ·
Bi-Mamba (2411.11843) · Mamba (2312.00752), Mamba-3 (ICLR 2026, 2603.15569)

**Alignment** — Friston, Thornton & Clark 2012 (Front. Psychol. 3:130) · Friston et al. EFE 2015 ·
Klyubin/Polani/Nehaniv 2005; Mohamed & Rezende 2015 · BYOL (Grill 2020), SimSiam (Chen & He 2021),
SPR (Schwarzer 2021), Tang 2023 (2212.03319) · Hubinger et al. 2019 (1906.01820) ·
Manheim & Garrabrant 2018 (1803.04585) · Haarnoja et al. SAC 2018 (1812.05905) ·
Burda et al. RND 2019 (1810.12894) · Everitt et al. reward tampering 2021; Krueger et al. 2020;
Gao, Schulman & Hilton 2023

**Systems / regulation** — EEVDF/6.6 ([Phoronix](https://www.phoronix.com/news/Linux-6.6-EEVDF-Merged)),
sched_ext/6.12 ([Phoronix](https://www.phoronix.com/news/Linux-6.12-Lands-sched-ext)) ·
Linux 7.0 ([The Register, Apr 2026](https://www.theregister.com/2026/04/13/linux_kernel_7_releaseed/)) ·
RFC 9669 ([RFC Editor](https://www.rfc-editor.org/rfc/rfc9669.html)) ·
bpftime ([arXiv 2311.07923](https://arxiv.org/abs/2311.07923)) ·
Verus ([tutorial](https://verus-lang.github.io/verus/guide/requires_ensures.html)) ·
Atmosphere ([project](https://mars-research.github.io/projects/atmo/); [SOSP 2025](https://dl.acm.org/doi/10.1145/3731569.3764821)) ·
Plugsched ([GitHub](https://github.com/aliyun/plugsched); [ASPLOS 2023](https://dl.acm.org/doi/10.1145/3582016.3582054)) ·
EU AI Act Art. 14 ([text](https://artificialintelligenceact.eu/article/14/))
