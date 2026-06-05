---
title: "Rust for the TypeScript 6 / C# 14"
author: realSergiy
date: 2026-05-30
---

> Target: Rust 1.96 (2024 edition), TypeScript 6, .NET 10 / C# 14. Written for someone fluent in strict TS and modern C#, moving to Rust as a primary language. Density over hand-holding.

The single biggest reframing: **Rust has no garbage collector and no runtime, yet is memory-safe — because the *compiler* tracks who owns each value and for how long.** TS/C# answer "is this memory still valid?" at runtime (GC). Rust answers it at compile time (ownership + borrow checker). Almost every unfamiliar thing in Rust descends from that one decision. Your existing instinct — "be explicit about the unknowns" (using `undefined` over `null`, banning `any`/`as`) — is exactly the Rust mindset, applied to *memory and lifetimes* in addition to *types*.

---

## 0. The three-bucket map

| Bucket | Examples |
|---|---|
| **Translates well** (you already think this way) | nominal typing, generics + constraints, discriminated unions, exhaustive pattern matching, no-null discipline, deterministic disposal (`using`/`IDisposable`), interfaces→traits, structural value types, `Span<T>`→slices, source generators→macros, async/await *syntax* |
| **Forget it** (exists in TS/C#, absent or discouraged in Rust) | class inheritance, exceptions for control flow, `null`, method/operator *overloading by arity*, optional/default parameters, named args, rich runtime reflection, eager Tasks, declaration-site variance keywords, mutable aliasing as the default |
| **Brand new** (neither TS nor C# has it) | ownership & moves, borrowing (`&`/`&mut`) with aliasing-XOR-mutation, lifetimes, `Send`/`Sync` as *compile-time* data-race freedom, interior mutability (`Cell`/`RefCell`), lazy poll-based futures, no built-in async runtime, `unsafe` as a scoped capability, monomorphization vs `dyn`, the orphan rule/coherence, typestate via moves |

---

## 1. Tooling & project shape (fast, because it's familiar)

`cargo` is `npm` + `tsc` + `dotnet` CLI fused into one, and it is excellent.

- `cargo new app` / `cargo init` — scaffold. `Cargo.toml` is `package.json` + `.csproj`; `Cargo.lock` is `package-lock.json`.
- `cargo build` / `cargo run` / `cargo test` / `cargo bench` / `cargo doc --open`.
- `cargo add tokio --features full` edits `Cargo.toml` for you.
- `crates.io` is the npm/NuGet registry. A *crate* = a compilation unit/package. A *module* (`mod`) = an in-crate namespace.
- **Workspaces** = monorepo with multiple crates sharing one lockfile (`[workspace]`), like a solution with many projects.
- **Editions** (`edition = "2024"`) are an opt-in language-dialect knob: a 2015-edition crate and a 2024-edition crate interoperate in the same build. There is no "edition runtime"; it only changes surface syntax/defaults (e.g. 2024 reserved `gen`, changed closure capture & RPIT lifetime capture). Always start new code on **2024**.
- Quality bar you'll want immediately: `cargo clippy` (≈ your custom eslint rules — *the* idiom linter, lean on it hard), `cargo fmt` (rustfmt, non-negotiable in the community), `cargo deny`/`cargo audit` (supply chain).

Visibility is path-based, not file-based: items are private to their module unless `pub`. `crate::`, `super::`, `self::` are the path roots. There's no `namespace` keyword; the module tree *is* the namespace tree, and `use` is your `import`.

---

## 2. Types: nominal, no null, sum types are first-class

### Nominal, like C# (not structural like TS)
Two structs with identical fields are **distinct, incompatible types**. This is C#'s model, not TS's. There is no structural duck-typing and no `satisfies`. The newtype pattern (below) is how you get cheap distinct types — closer to your custom-branded types in TS than to TS's structural defaults.

### Scalars
Integers are explicit-width and signed/unsigned: `i8..i128`, `u8..u128`, `isize`/`usize` (pointer-width; `usize` indexes collections). `f32`/`f64`. `bool`, `char` (a 4-byte Unicode scalar, *not* a UTF-16 code unit like C#'s `char`). Overflow panics in debug, wraps in release — use `checked_add`/`wrapping_add`/`saturating_add` when it matters. There are **no implicit numeric conversions**; you write `x as u64` or, better, `u64::from(x)` / `.try_into()?`. (Idiomatically you avoid `as` for fallible/narrowing casts just like you avoid `as` in TS — prefer `From`/`TryFrom`.)

### Strings and slices — map to your `Span<T>` intuition
- `String` = owned, growable, heap, **UTF-8** (≈ `StringBuilder`/owned buffer).
- `&str` = a borrowed view into UTF-8 bytes (≈ `ReadOnlySpan<char>` but UTF-8). String literals are `&'static str`.
- `Vec<T>` = `List<T>`. `&[T]` / `&mut [T]` = slices = **exactly your `ReadOnlySpan<T>`/`Span<T>` mental model**: a fat pointer (ptr+len) borrowing into an array/Vec, no allocation.
- `[T; N]` = a fixed-size array that is a **value type living inline/on the stack** (unlike C# arrays which are heap references). `N` is a const generic.
- Because strings are UTF-8, you cannot `s[3]` index by character; you iterate `.chars()` or `.bytes()` or slice by byte range on char boundaries. This trips up everyone from C#.

### Tuples & unit
`(i32, String)` tuples with `.0`/`.1` access; destructure with `let (a, b) = t;`. The **unit type `()`** is "no meaningful value" — it's `void`-as-a-real-type (like F#'s `unit`). A `fn` with no return returns `()`.

### Structs (three flavors)
```rust
struct Point { x: f64, y: f64 }          // named-field (your records/classes-of-data)
struct Meters(f64);                       // tuple struct — the newtype workhorse
struct Marker;                            // unit struct — zero-sized
```
No fields are `pub` unless you say so. There are **no classes and no inheritance.** A struct holds data; behavior is attached via `impl` blocks and traits.

### Enums = real sum types (your TS discriminated unions, enforced; beyond C#)
This is the feature you'll love most coming from strict TS. Rust enums are tagged unions where each variant can carry different data:
```rust
enum Shape {
    Circle { radius: f64 },
    Rect(f64, f64),
    Unit,
}
```
This is your `type Shape = { kind: "circle"; radius: number } | ...` — but the tag is implicit and the compiler *forces* exhaustive handling. C# 14 still has **no native discriminated unions** (the proposal hasn't shipped), so you'd be faking this with a sealed hierarchy + visitor today; Rust gives it natively with pattern matching. `Option<T>` and `Result<T, E>` are just enums from the standard library.

### No `null`. Ever
There is no null and no nullable reference types because there are no nulls to make non-null. Absence is `Option<T>` = `Some(T) | None`. Your existing "use `undefined`, be explicit about unknowns" rule *is* `Option`. The compiler will not let you "forget" to handle `None`. Fallible operations return `Result<T, E>` (below), not exceptions.

---

## 3. Expressions, flow, pattern matching

Rust is **expression-oriented** (like F#, more than C#): `if`, `match`, `loop`, and blocks all *evaluate to a value*. The last expression in a block, with no semicolon, is the block's value. A trailing `;` turns it into a statement yielding `()`.
```rust
let grade = if score >= 90 { "A" } else { "B" };
let x = { let t = compute(); t * 2 };
```
`return` exists but is mostly for early exit; idiomatic Rust ends functions with a bare expression.

**`match`** is C#'s switch-expression on steroids — exhaustive, with binding, guards, ranges, `|` or-patterns, and struct/enum destructuring:
```rust
match shape {
    Shape::Circle { radius } if *radius > 0.0 => area_circle(*radius),
    Shape::Rect(w, h) => w * h,
    Shape::Unit => 0.0,
}
```
Exhaustiveness is enforced at compile time. This replaces your TS `switch (x) { ... default: const _: never = x }` exhaustiveness hack — you get it for free, as an error, not a convention.

Ergonomic narrowing forms:
- `if let Some(v) = opt { ... } else { ... }` — match one pattern.
- `let Some(v) = opt else { return; };` — **let-else** (1.65): bind-or-diverge, the clean replacement for early-return guard pyramids.
- `while let Some(item) = stack.pop() { ... }`.
- **let chains** (stable in the 2024 edition): `if let Some(u) = user && u.active && let Ok(p) = parse(&u.id) { ... }` — chain conditions and bindings without nesting. Alongside this, `if let` guards *inside* `match` arms are stabilizing right now (1.97).
- `matches!(x, Shape::Rect(..))` returns a bool; and as of **1.96**, `assert_matches!(x, Shape::Rect(..))` / `debug_assert_matches!` for tests.

**Shadowing** is idiomatic and good: `let x = "5"; let x: u32 = x.parse()?;` reuses the name with a new type. Not mutation — a fresh binding.

---

## 4. Functions, closures, and what's *gone*

```rust
fn add(a: i32, b: i32) -> i32 { a + b }
```

**Forget these from C#/TS:**
- **No function/method overloading.** One name = one signature. Want "overloads"? Use generics + a trait, or distinct names (`new`, `with_capacity`, `from_str`). This feels restrictive for a day, then liberating.
- **No optional/default parameters, no named arguments.** Patterns instead: take `Option<T>` params, use the **builder pattern**, or take a config struct with `..Default::default()`.
- **No `params`/variadics** in normal functions (only macros are variadic, e.g. `println!`).

**Closures** are `|args| body`. The compiler infers an anonymous type implementing one of three traits based on *how it captures the environment*:
- `FnOnce` — consumes captures (can be called once); e.g. moves a value out.
- `FnMut` — mutably borrows captures (callable repeatedly, mutating state).
- `Fn` — borrows immutably (callable repeatedly, no mutation).

The `move` keyword forces capture *by value* (essential for threads/async, where the closure outlives the current stack). Unlike C# closures (which always heap-allocate a display class and capture by reference), Rust closures are usually unboxed, stack-stored, zero-allocation, and monomorphized into the caller. Pass them as `impl Fn(i32) -> i32` (static dispatch) or `Box<dyn Fn(...)>` (dynamic). **Async closures** (`async || { ... }`, 1.85) implement `AsyncFn`/`AsyncFnMut`/`AsyncFnOnce` and are now the idiomatic way to pass async callbacks.

---

## 5. Ownership, borrowing, lifetimes — the core, and the genuinely new part

Everything here is new relative to TS and C#. Spend your real learning budget on this section.

### 5.1 Move semantics
Every value has exactly one **owner**. Assignment or passing by value **moves** ownership; the source is then statically unusable:
```rust
let a = String::from("hi");
let b = a;            // ownership moves a -> b
// println!("{a}");   // compile error: value borrowed after move
```
For cheap, "plain old data" types that implement **`Copy`** (all scalars, `bool`, `char`, shared refs, and — *new in 1.96* — range types like `0..n`), assignment copies bitwise instead of moving, so the original stays valid. Everything else moves. When an owner goes out of scope, its value is **dropped** (destructor runs) — deterministically.

Mental bridge: this is C# `struct` move/copy semantics, but **pervasive and compiler-enforced for all types**, and tied to scope-based destruction.

### 5.2 `Drop` = `IDisposable`, but automatic and guaranteed
RAII: cleanup happens when the owner leaves scope, in reverse declaration order, with **no `using` block required and no way to forget it.** A `File` closes, a `MutexGuard` unlocks, a `Vec` frees its buffer — automatically and deterministically. Implement `Drop::drop` for custom teardown. This is your `IDisposable`/`using`/finalizer story, except it's the default, it's deterministic (no GC finalizer nondeterminism), and you can't leak it by forgetting `using`. (You *can* opt out with `std::mem::forget` or `ManuallyDrop`, rarely.)

### 5.3 Borrowing: references without ownership transfer
Instead of moving, you can lend a reference:
- `&T` — a **shared (immutable) borrow**. Many may coexist.
- `&mut T` — an **exclusive (mutable) borrow**. Exactly one may exist, and no shared borrows may coexist with it.

**The rule that defines Rust: aliasing XOR mutability.** At any instant a value has *either* any number of readers *or* exactly one writer — never both. This is what eliminates data races and iterator-invalidation/use-after-free *at compile time*. C# lets you alias mutable state freely (and pays with GC + runtime bugs); Rust forbids it structurally.
```rust
fn len(s: &String) -> usize { s.len() }       // borrow, don't take ownership
fn push(s: &mut String) { s.push('!'); }       // exclusive borrow to mutate
```
Borrows are checked by **Non-Lexical Lifetimes**: a borrow ends at its last use, not at the closing brace, so the checker is far less annoying than older Rust. The 2024 edition's next-gen trait/borrow solver makes this even smarter.

### 5.4 Lifetimes
A lifetime `'a` is a compile-time-only label naming a *region of code over which a reference is valid*. They carry **zero runtime cost** — they are erased; they're proof obligations, not data. Most are inferred (**elision**), so you rarely write them. You annotate when a function's output reference's validity depends on which input it came from:
```rust
fn longest<'a>(a: &'a str, b: &'a str) -> &'a str {
    if a.len() >= b.len() { a } else { b }
}
```
This says "the returned reference lives no longer than the shorter of the inputs." The closest TS/C# analog is *nothing* — they have no concept because the GC keeps everything alive. `'static` means "valid for the whole program" (string literals, leaked allocations, owned data with no borrows). Structs that hold references need lifetime params: `struct Parser<'a> { input: &'a str }`. Rule of thumb early on: **prefer owning data (`String`, `Vec`) in your structs; reach for borrowed fields with lifetimes only when profiling demands it.**

---

## 6. Traits — interfaces, type classes, and constraints in one

Traits are the central abstraction. They are interfaces + C# generic constraints + a bit of Haskell type classes.

```rust
trait Animal {
    fn name(&self) -> String;
    fn legs(&self) -> u32 { 4 }     // default method, like C# 8 default interface members
}
impl Animal for Dog {
    fn name(&self) -> String { "dog".into() }
}
```

What maps cleanly from C#:
- **Default methods** ≈ default interface members.
- **Trait bounds** ≈ generic constraints: `fn f<T: Animal + Clone>(x: T)` is `where T : IAnimal, ICloneable`. The `where` clause exists too and reads almost identically.
- **Operator overloading** is "implement the operator trait": `impl Add for V`, `impl PartialEq`, etc. — same idea as C# `operator +`, just trait-shaped.
- **`From`/`Into`** ≈ implicit/explicit conversion operators, but principled: implement `From<A> for B` and you get `Into` for free. `TryFrom`/`TryInto` for fallible conversions.

What's new or different:
- **Associated types**: `trait Iterator { type Item; fn next(&mut self) -> Option<Self::Item>; }`. An output type chosen by the implementer, not the caller — there's no clean C#/TS equivalent (it's *not* a generic parameter). **GATs** (generic associated types, stable since 1.65) let associated types themselves be generic/lifetime-parameterized: `type Item<'a>;` — Rust's pragmatic stand-in for higher-kinded types (which, like C#/TS, it otherwise lacks).
- **The orphan rule / coherence**: you may `impl Trait for Type` only if you own the trait *or* the type. This guarantees there's never more than one implementation globally (no "two libraries both extend `string`" conflicts). Work around it with the newtype pattern.
- **Blanket impls**: `impl<T: Display> ToString for T { ... }` — implement a trait for *all* types satisfying a bound. Hugely powerful; no C#/TS analog.
- **Marker traits**: `Copy`, `Send`, `Sync`, `Sized` — traits with no methods that the compiler reasons about.
- **Derive macros**: `#[derive(Debug, Clone, PartialEq, Eq, Hash, Default)]` auto-generates impls — like a souped-up record-member synthesis. `Debug` ≈ a dev `ToString`, `Display` ≈ user-facing `ToString`, `Default` ≈ parameterless ctor, `Clone` ≈ explicit `.Clone()`, `Copy` ≈ value-copy struct, `PartialEq`/`Eq` drive `==`, `Ord`/`PartialOrd` drive comparison/sorting. (Floats are `PartialOrd` but not `Ord`, and `PartialEq` but not `Eq`, because of `NaN` — the type system encodes this.)

### Generics: monomorphization vs trait objects (a real performance/architecture decision)
- **Static dispatch (generics / `impl Trait`)**: `fn draw<T: Shape>(s: &T)` or `fn make() -> impl Shape`. The compiler **monomorphizes** — generates a specialized copy per concrete type, like C++ templates (and unlike C# generics, which share JIT-compiled code for reference types). Zero-cost, inlinable, bigger binary.
- **Dynamic dispatch (trait objects)**: `&dyn Shape`, `Box<dyn Shape>`, `Vec<Box<dyn Shape>>`. A fat pointer (data ptr + vtable ptr) — this is exactly C# interface dispatch. Use when you need a heterogeneous collection of differing concrete types. A trait must be **dyn-compatible** ("object safe") to be used this way (no generic methods, no `Self`-returning methods, etc.).
- `impl Trait` in argument position = anonymous generic; in return position (RPIT) = "some concrete type I won't name"; **RPITIT** (return-position `impl Trait` in traits, stable 1.75) is what makes `async fn` in traits work.
- **Const generics**: types parameterized by *values*, e.g. `struct Matrix<const R: usize, const C: usize>`. C# has no value generics at all; this is closer to C++ NTTPs. Basic forms are stable; complex const expressions in generics are still maturing.

---

## 7. Error handling — `Result` + `?`, not exceptions

**Forget exceptions for ordinary control flow.** Recoverable errors are values:
```rust
fn parse_port(s: &str) -> Result<u16, std::num::ParseIntError> {
    let n: u16 = s.parse()?;     // ? = unwrap Ok, or early-return the Err
    Ok(n)
}
```
The **`?` operator** is the killer ergonomic: on `Ok(v)` it yields `v`; on `Err(e)` it returns `Err(e.into())` from the function (auto-converting via `From`). It also works on `Option` (`None` short-circuits). This replaces try/catch plumbing entirely — errors are tracked in the *type signature*, so a function's fallibility is visible and exhaustive, much like checked nullability but for all failure. There is genuinely **no `try`/`catch`/`throw`.**

- `panic!` / `.unwrap()` / `.expect("msg")` = unrecoverable, aborts the thread/unwinds the stack. Use for "this can't happen / bug" — *not* for expected failures. Closer to `Debug.Assert` + fail-fast than to exceptions; do not design around catching it (`catch_unwind` exists but is for FFI/thread boundaries, not flow).
- Library code: define error enums and derive with **`thiserror`** (the de-facto crate; gives you `Display` + `From` + `Error` with a derive).
- Application code: **`anyhow`** (`anyhow::Result<T>` + `.context("while loading config")?`) for ergonomic, type-erased error bubbling with backtraces.
- Idiom: `thiserror` at boundaries you expose, `anyhow` at the top of bins.

---

## 8. Iterators — your LINQ / array chains, but lazy and zero-cost

`Iterator` is a trait with one required method, `next()`. Adapters are lazy and fuse into tight loops with **no intermediate allocation** — nothing runs until a *consumer* drives it (`collect`, `sum`, `for`, `find`, ...). This is `IEnumerable`/LINQ semantics with C++-level performance after monomorphization.
```rust
let total: u64 = items.iter()
    .filter(|x| x.active)
    .map(|x| x.size as u64)
    .sum();

let names: Vec<String> = users.iter().map(|u| u.name.clone()).collect();
```
- `iter()` borrows (`&T`), `iter_mut()` borrows mutably (`&mut T`), `into_iter()` consumes (`T`). Choosing among them is choosing your ownership story — new vs LINQ, which only ever borrows.
- `collect::<Vec<_>>()` / the **turbofish** `::<>` annotate the target type when inference needs help. `collect` can also build `HashMap`, `Result<Vec<_>, E>` (short-circuiting on first `Err`), etc.
- Rough LINQ map: `Sele
