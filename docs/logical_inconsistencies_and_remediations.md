# Logical Inconsistencies & Remediations

Scope: `stories/stoch_attr_collapse/index.md`

The piece is tightly constructed. The hard technical scaffolding (CXL/PCIe
generation math, RISC-V Zkr/`seed` CSR, RFC 9669, Verus/Z3, the patch-count
arithmetic 17→11→6→1) all checks out internally. The inconsistencies below are
concentrated in the central conceit — the reward function and its post-mortem —
plus a few smaller continuity snags.

---

## Major

### 1. The epistemic term plays two contradictory roles

The reward has exactly **one** epistemic term (`index.md:169`):

```text
throughput - tail_penalty + epistemic_weight * self_prediction
```

That single term is described two incompatible ways:

- **As the *cause* of collapse.** `index.md:180`: "the policy had nothing left
  to climb but its own forecast — and the global optimum of *predict yourself*
  is a fixed point." `index.md:182` nails it via BYOL/SimSiam: a self-predictive
  objective with no stop-gradient collapses to the trivial constant
  representation. So *maximizing* `self_prediction` drives the dark room.
- **As the *preventer* of collapse.** `index.md:100` calls the same term "the
  exploration half of an expected-free-energy objective, the kind of curiosity
  term you add to keep a policy probing the world." `index.md:184`: "the
  exploration bonus that should have shoved it back out into the world had
  annealed to nothing precisely when it was needed most." Here its
  *disappearance* causes the collapse.

A term cannot be both the attractor you fall into when it's present and the
safety valve you lose when it's absent. There's also a conceptual error feeding
the contradiction: rewarding **accuracy of your own forecasts**
(`self_prediction = agreement(predicted_next, observed_next)`) is
surprise-*minimization* — the literal dark-room driver. It is the **opposite**
of an epistemic/curiosity bonus, which in expected-free-energy rewards
*information gain* (going where you're uncertain). So labeling `self_prediction`
"the exploration/curiosity half" inverts the active-inference concept the rest
of the section leans on.

**Remediation (preserves both set-pieces).** Split the one term into the two
distinct things the prose already wants:

- Keep `self_prediction` as the **collapse cause** and stop calling it
  exploration/curiosity. Describe it honestly as a self-modeling/predictability
  reward — or, even better in-story, as expected-free-energy's epistemic value
  *implemented wrong* (rewarding forecast accuracy instead of information gain).
  That naming mistake can be Elena's actual bug.
- Point the "exploration bonus that should have shoved it back out… went silent"
  at the **`route_weight` confidence-gated noise** (`index.md:221`,
  `index.md:226`: "went silent as confidence climbed"). That mechanism genuinely
  vanishes at high confidence and is exactly what Section 4 fixes — so this also
  tightens the cause→fix link. The reward's `self_prediction` term then stays the
  thing the empowerment/stop-gradient rewrite (the slow fix) must address.

### 2. The "annealing trap" runs backwards mathematically

`index.md:141` (WARN) and `index.md:173` (point 1) say `epistemic_weight`
"annealed **below** task gradient," and conclude "for a few hundred
microseconds, `self_prediction` was the only term on the right-hand side with
any slope left to climb."

But as `epistemic_weight → 0`, the gradient of `epistemic_weight *
self_prediction` → 0 *too*. A vanishing weight cannot make its term the dominant
one; and "annealed below task gradient" says the *task* term should win, not
self-prediction. The only way the conclusion holds is if the throughput/tail
gradients hit **exactly zero** (plateau) — which `index.md:180` does assert
("once the throughput and tail-latency terms went flat") — but that directly
contradicts the framing that the epistemic weight fell *below a still-live* task
gradient.

**Remediation.** Make it a comparison of gradient **magnitudes**, with the task
gradient going to zero: e.g., WARN should read "task gradient collapsed below
epistemic residual on Node 3," and point 1 should say throughput had *plateaued*
(gradient → 0) while a tiny-but-nonzero `self_prediction` gradient remained the
only slope. That makes "the only term with slope left to climb" literally true
without the weight-vs-gradient inversion.

### 3. The Harness modifies the observer — violating the story's first law

The single most repeated invariant is that the instrumentation/observer is
sacrosanct and the Harness can never touch it (`index.md:37`: "the probe only
ever watched… nothing crossed the line"; `index.md:186`: "An observer it could
not touch"). Yet the staged diff at the end includes (`index.md:305`):

```text
modified:   src/drivers/npu/telemetry_probe.zig
```

…and the prose attributes the staging to the Harness (`index.md:294`: "The
Harness had packaged the patch… and staged the commit"). So the agent edited the
telemetry probe — exactly the file the whole thematic spine says it structurally
cannot.

**Remediation.** Either (a) change the second modified file to something on the
implementation side that the patch plausibly touched — e.g.
`src/kernel/sched/policy_reward.rs` or a Zig descriptor/driver file — or (b) if
you want a probe change (the post-patch telemetry *does* show a new `Zkr
injection` metric, `index.md:288`), have **Elena** author that one from the
intent side and say so, so the observer edit doesn't come from the optimizer.

---

## Medium

### 4. Two different "correct cures" are each declared definitive

- `index.md:182`: "The fix, when it existed at all, was **always the same
  shape** — sever the path from the optimizer to its own scorecard. A
  stop-gradient."
- `index.md:198`: "The *correct* cure, she knew, was **a different objective
  entirely** — an empowerment term."

Both use absolute language, so they read as contradicting each other on what the
real fix is.

**Remediation.** Frame them as a layered pair rather than rivals: the
stop-gradient removes the *degenerate fixed point* (representational collapse),
while empowerment replaces the *objective* so the policy is rewarded for
optionality. One short connective clause ("the stop-gradient kills the trivial
optimum; empowerment is what you reward *instead*") resolves it.

### 5. "Signing," committing, and git state are conflated

`index.md:294`: "The Harness had… **staged the commit** — but it had not signed
it. It couldn't. The deploy capability lived on the hardware key." Two issues:

- The git status shows the change as **staged but not yet committed**
  (`index.md:302`, "Changes to be committed"), so "staged the commit" is
  imprecise — and *signing* a git commit (GPG) happens at commit time, not deploy
  time. The text fuses commit-signing with deploy authorization (the hardware
  key).
- "Your branch is ahead… by 1 commit" (`index.md:299`) means a completed commit
  already exists locally — on a machine where the signing/deploy key has "never
  once been" (`index.md:294`). If signing requires that key, that prior commit
  (plausibly the `0x8F9A2C` refactor at `index.md:10`) couldn't have been made
  either.

**Remediation.** Separate the concepts cleanly: the Harness *stages* changes;
*committing* is fine locally; only the **deploy/sign-for-release** step needs the
hardware key. Reword `index.md:294` to "staged the change but could not authorize
the deploy — that signature lived on the key in her pocket." That also makes the
"1 commit ahead" (the earlier refactor) consistent, since ordinary local commits
don't need the deploy key.

---

## Minor / technical-coherence

### 6. Spectral radius 0.06 can't sustain a period-four cycle

`index.md:142`: "state-transition spectral radius → 0.06" (strong contraction —
the linear state decays to a point). But `index.md:178` describes "the state is
just cycling its own echo — **period four**" with "the input gate's shut"
(autonomous dynamics, zero forcing). An autonomous linear map with spectral
radius 0.06 decays to the origin in a couple of steps; a *sustained* period-4
orbit needs eigenvalues near the unit circle (ρ ≈ 1) at the right angle, not
0.06. Also note ρ is used for two different objects — the SSM state-transition
matrix (`0.06`) and the Markov-chain mixing rate (`0.71`, `index.md:288`) — which
a careful reader will trip on.

**Remediation.** Either drop "period four" (let the collapse be a near-static
fixed point, which ρ→0.06 supports) and describe it as the state pinned at a
single point; or, if you want the four-step `RX→ALLOC→VECTOR→TX` loop to be a
literal limit cycle, raise the collapse-state ρ toward ~1 and reframe the
pathology as "spectral radius pinned near unity, all mass on one orbit." Pick one
and keep ρ referring to a single object.

### 7. (External, not internal) "Atmosphere kernels" as a formal-proof reference

`index.md:254` cites "the same toolchain lineage that had carried the
**Atmosphere kernels** through their proofs." Atmosphere is the Nintendo Switch
custom firmware, not a formally-verified-kernel lineage; the canonical
machine-checked-kernel reference is **seL4**. Not an internal contradiction, but
it'll read as an error to the same audience that appreciates the Verus/Z3 detail.

---

## Bottom line & suggested order of fixing

The piece is in good shape; only **#1** threatens the story's logic at the level
a knowledgeable reader will notice, and #1/#2/#3 share a single root — the reward
function is doing too many jobs. Suggested order:

1. **#1 + #2 together** — split self-prediction (collapse cause, needs
   stop-gradient/empowerment) from a real exploration mechanism (the
   confidence-gated `route_weight` noise, whose silencing is the trigger), and
   recast the annealing trap as a gradient-magnitude argument with throughput
   plateaued. This is one coherent revision and it makes the dark-room *and* the
   BYOL/stop-gradient beats reinforce each other instead of fighting.
2. **#3** — repoint or re-author the `telemetry_probe.zig` line; cheap, protects
   the strongest theme.
3. **#5** — one-sentence reword separating stage/commit/deploy-sign.
4. **#4, #6, #7** — small touch-ups.
