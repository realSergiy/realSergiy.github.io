---
title: "Graphs Without a GC: Arenas, Interning, and Index-Based References in Rust"
author: realSergiy
date: 2026-07-31
description: Why cyclic, mutable graphs — a compiler's type graph being the extreme case — are the hard problem for Rust's ownership model, and the three idiomatic architectures (arenas, interning, index handles) that replace a garbage collector.
---

> Context: this grew out of a concrete question — why does every type-aware TypeScript lint rule in the ecosystem live in the type checker's language (clippy rules in Rust inside rustc, tsgolint rules in Go inside typescript-go), and why did Microsoft port tsc to Go rather than Rust? The answer bottoms out in how Rust models object graphs without a GC. This is that lecture.

## 1. The root difference: who decides when memory dies

In a GC'd language (Go, TypeScript/JS, Java), the object graph is a *soup*: any object may point at any other, references are free, cycles are free, and **liveness is computed at runtime** by tracing from roots. Because the collector discovers reachability dynamically, the *program* never has to articulate who owns what.

Rust's bet is the opposite: **liveness is proven at compile time**. Three rules do all the work:

- every value has exactly one owner; when the owner goes out of scope, the value is dropped;
- you may have many shared borrows `&T` *or* one exclusive borrow `&mut T`, never both;
- every borrow has a lifetime that must be statically shown not to outlive the owner.

This gives you deterministic destruction and zero runtime overhead, but notice what the rules describe: a **tree**. Ownership is hierarchical by construction (`Box<T>` is a uniquely-owned edge; a struct owns its fields). The moment your data is a *graph* — shared nodes, back-edges, cycles — the question "who is the one owner?" has no natural answer, and the aliasing rule "shared XOR mutable" collides with the most ordinary compiler operation there is: walking a graph while mutating its nodes.

A type checker's data is the worst case on both axes. Types reference symbols, symbols reference declarations, declarations reference types; recursive types (`type List<T> = { head: T; tail: List<T> }`) are literal cycles; and the whole thing is built *lazily*, with caches filled in mid-traversal. In Go or JS you just... do it. In Rust, the naive translation doesn't compile.

So idiomatic Rust developed a small vocabulary of escape hatches, each trading a different thing away. The three load-bearing ones are arenas, interning, and index-based references.

## 2. The naive port, and why it's rejected: `Rc<RefCell<T>>`

The mechanical translation of a GC object graph is reference counting plus runtime borrow checking:

```rust
struct TypeNode {
    kind: TypeKind,
    members: RefCell<Vec<Rc<TypeNode>>>,     // mutate later ("lazy" fields)
    target: RefCell<Option<Weak<TypeNode>>>, // back-edge must be Weak or it leaks
}
```

This works, and it's genuinely idiomatic for *small* object graphs with truly dynamic lifetimes (GUI widget trees, observer lists). For compiler-scale data it's the wrong default four times over: cycles leak unless you manually decide which edges are `Weak` (you've reinvented manual memory management, badly); every access pays refcount traffic and a `RefCell` runtime check that *panics* on aliasing violations you'd rather have caught statically; `Rc` isn't thread-safe, and `Arc<Mutex<T>>` is worse; and every node is its own heap allocation, scattered across memory. When people say a Rust program is "fighting the borrow checker," this shape is usually what they wrote.

## 3. Arenas: replace "who owns each node?" with "one region owns everything"

An arena (bump allocator: `bumpalo`, `typed-arena`) is a big buffer you allocate into by incrementing a pointer. Nothing is ever freed individually; **the entire region dies at once** when the arena drops. That single design decision dissolves the ownership question:

```rust
let arena = Arena::new();
let a: &Node = arena.alloc(Node::new("a"));
let b: &Node = arena.alloc(Node::new("b"));
```

Every node now has the *same* lifetime — the arena's — so nodes may freely hold plain shared references to each other: `&'arena Node` pointing at `&'arena Node`, cycles included. No `Rc`, no `Weak`, no refcounts; edges are ordinary pointers again, like in Go. The borrow checker is satisfied because nobody's lifetime is shorter than anybody else's.

Two costs. First, arenas hand out **shared** references, so building a cycle needs interior mutability or two-phase construction — the classic pattern is a `Cell` you patch after both nodes exist:

```rust
struct Node<'a> {
    edges: Cell<Option<&'a Node<'a>>>,
}
let a = arena.alloc(Node { edges: Cell::new(None) });
let b = arena.alloc(Node { edges: Cell::new(Some(a)) });
a.edges.set(Some(b));               // cycle closed, entirely safe
```

Second — and this is the famous one — the lifetime parameter **infects every signature that touches the data**. This is rustc's `'tcx`: the compiler allocates types, predicates, and much of its IR in arenas owned by the global context, so `Ty<'tcx>`, `TyCtxt<'tcx>`, `&'tcx List<GenericArg<'tcx>>` thread through thousands of function signatures. It works at scale — rustc is the proof — but it is an *architecture*, chosen up front, not a local trick.

Theory sidebar: arenas are region-based memory management (the MLKit lineage). A GC computes liveness exactly, at runtime; regions *approximate* liveness statically by batching many objects into one lifetime. You trade peak memory (nothing frees early; fine for a batch compiler run, dubious for a long-lived server) for zero per-object bookkeeping.

## 4. Interning: identity as a value, equality as a pointer compare

Interning (hash-consing) canonicalizes structurally equal values: before allocating, look the value up in a hash set; if an equal one exists, return the existing allocation. Combined with an arena you get rustc's central move — `Ty<'tcx>` is essentially a newtype around `&'tcx TyKind<'tcx>` where every type is interned on construction (`tcx.mk_*`). Consequences:

- **Equality is pointer equality.** `t1 == t2` is one word compare, hashing hashes the address. A checker compares types millions of times; this matters enormously.
- **Deduplication.** `Vec<String>` exists once no matter how many times it's mentioned across a million-line crate.
- **The price: immutability.** Interned values are frozen forever — they're shared with every other user of the same pointer. So types must be built **bottom-up as values**, and anything computed later (normalizations, relations, member lists) must live in *side caches keyed by the interned pointer*, not in mutable fields on the type.

That last point is exactly the fault line under the tsc-to-Go port. tsc's checker is GC-shaped in the deepest sense: `Type` and `Symbol` objects are created early and **mutated afterward** — lazily resolved members, flags flipped, caches written onto the object itself mid-traversal. Go could absorb that design unchanged: structs, pointers, mutation, GC. A Rust version wanting interning's benefits must invert it — immutable interned cores plus external memo tables or a query system. That inversion touches every function in a 50k-line checker. That's the "multi-year redesign into arena/ownership idioms": not that Rust *can't* express it, but that a faithful *port* can't, and a redesign is a rewrite.

The redesign has a name: rustc's **query system** (and `salsa`, its extraction, which powers rust-analyzer). Instead of "object with lazily mutated cached fields," you write memoized pure functions keyed by IDs — `type_of(DefId) -> Ty<'tcx>` — and a runtime that caches and (in salsa's case) incrementally invalidates them. It's the arena-and-interning world's replacement for the GC world's "just stash it on the object."

## 5. Index-based references: build your own address space

The third idiom drops pointers entirely. Put the nodes in a `Vec`; make edges plain integers:

```rust
#[derive(Copy, Clone, PartialEq)]
struct NodeId(u32);

struct Graph {
    nodes: Vec<Node>,          // the single owner of everything
}
struct Node {
    edges: Vec<NodeId>,        // cycles are just numbers
}
```

The borrow checker now sees one owned container and integers — which are `Copy`, `'static`, and carry no lifetime. Every signature simplifies (`fn check(&mut self, id: NodeId)` — no `'tcx` plague); cycles are trivial; serialization is trivial (indices survive a round-trip to disk; pointers don't); it's cache-friendly (dense storage, 4-byte handles). Mutation-during-traversal gets solved the idiomatic way — collect IDs first, then mutate through re-lookup, sidestepping the "two `&mut` into one Vec" aliasing wall:

```rust
let neighbors: Vec<NodeId> = self.nodes[id.0 as usize].edges.clone();
for n in neighbors { self.mark(n); }   // each re-borrows self.nodes briefly
```

The honest description of this pattern: **you've reified pointers into handles the type system no longer tracks.** Memory safety is retained (an index can't dangle into freed memory), but *semantic* safety is on you — a stale index silently reads the wrong node. The ecosystem's mitigations: newtype every ID so a `SymbolId` can't index the type table (rustc has `DefId`, `HirId`, `BodyId`, `LocalDefId`…), and *generational* indices (`slotmap`) that embed a version counter so stale handles fail loudly. This is also precisely the ECS architecture from game engines (bevy), `petgraph`'s `NodeIndex`, and rust-analyzer's everything-is-a-salsa-ID design. rustc uses this alongside arenas: interned pointers for types, index IDs for definitions and HIR.

## 6. The pattern map

| Need | GC-language reflex | Idiomatic Rust counterpart |
|---|---|---|
| Hierarchical data | objects owning objects | `Box<T>` / owned fields (the default tree) |
| Phase-scoped graph, cycles OK | object soup | arena + `&'arena T` (+ `Cell` to tie cycles) |
| Shared immutable values, fast equality | pointer identity for free | interning; equality = pointer compare |
| Mutable graph, serializable, long-lived | object soup + mutation | `Vec` + newtype indices / `slotmap` |
| Lazily computed field | mutate a cached property on the object | `OnceCell`, side-table `HashMap<Id, T>`, or a query/memo system (salsa) |
| Genuinely dynamic shared ownership | GC handles it | `Rc<T>` + `Weak` back-edges (accept the costs) |
| Hot intrusive structure | n/a | `unsafe` raw pointers behind a safe API (std's `LinkedList`, allocators) |

The meta-pattern: a GC language lets you defer every ownership decision to runtime, so one representation (mutable object soup) serves all needs. Rust makes you *choose a memory architecture per data structure*, and each choice reshapes your APIs — lifetimes in signatures (arenas), immutability plus side caches (interning), or handle discipline (indices). None of it is exotic; rustc demonstrates all three coexisting in one of the largest Rust codebases alive. But the choices are load-bearing and global — which is why they're a fine foundation to *design into* (pyrefly, ty, and Ruff did exactly this for Python), and a terrible thing to retrofit under a mechanical port of two decades of GC-shaped JavaScript. Hejlsberg's Go decision wasn't "Rust can't build compilers"; it was "a port preserves tsc's soul, a Rust rewrite would have to replace it."
