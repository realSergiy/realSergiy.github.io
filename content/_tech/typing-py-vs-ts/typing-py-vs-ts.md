---
title: "Python 3.15 vs TypeScript 7 Type Systems, by Example"
author: realSergiy
date: 2026-07-31
description: A capability comparison of the Python 3.15 and TypeScript 7.0.2 type systems — sixteen concrete examples of what each can express that the other cannot, and where they have converged.
emoji: "🧬"
---

## TL;DR

TypeScript 7.0.2 is the native Go-port release — deliberate feature parity with the 6.0 line, so its type system is the mature 5.9/6.0 surface. Python 3.15 (final scheduled for October 2026) brings the type system to: PEP 695 generics syntax, TypeVar defaults, `TypeIs`, `ReadOnly`, deferred annotations (3.14), plus two new pieces — closed TypedDicts (PEP 728) and `TypeForm` (PEP 747).

The asymmetry has a shape: **TypeScript wins on type-level computation, Python wins on types-at-runtime and soundness discipline.** TypeScript's type system is a Turing-complete functional language over types, grown inside a single compiler to describe wild JavaScript. Python's is a spec-governed annotation language whose types survive to runtime and power frameworks like pydantic and FastAPI.

## Possible in TypeScript, not in Python

### 1. Conditional types — types computed from types

```ts
type Unwrap<T> = T extends Promise<infer U> ? Unwrap<U> : T;
type A = Unwrap<Promise<Promise<number>>>;  // number
```

Python has no conditional construct in types at all. The nearest tool is `@overload` — enumerating finitely many cases by hand.

### 2. Mapped types — deriving one shape from another

```ts
interface User { id: number; name: string; email: string }
type PartialUser = { [K in keyof User]?: User[K] };            // all optional
type Getters<T> = { [K in keyof T as `get${Capitalize<K & string>}`]: () => T[K] };
type UserGetters = Getters<User>;  // { getId(): number; getName(): string; ... }
```

A Python `TypedDict` or dataclass cannot be derived from another — a "partial User" is a second class you write and maintain by hand. This is why TypeScript has `Partial`, `Pick`, `Omit`, `Record` as one-liners and Python has nothing analogous.

### 3. `keyof` and indexed access — abstracting over an arbitrary type's keys

```ts
function prop<T, K extends keyof T>(obj: T, key: K): T[K] { return obj[key]; }
const n = prop(user, "id");     // number
prop(user, "nope");             // error
```

Python checkers special-case `TypedDict` literal-key access (`movie["name"]` is typed), but that is built-in magic for one class — user code cannot express "for any `T`, a valid key of `T`, returning that field's type."

### 4. Template literal types — string computation in the type system

```ts
type EventName = `on${Capitalize<"click" | "focus">}`;   // "onClick" | "onFocus"

type Params<S> = S extends `${infer _}:${infer P}/${infer Rest}` ? P | Params<`/${Rest}`>
  : S extends `${infer _}:${infer P}` ? P : never;
type R = Params<"/users/:id/posts/:postId">;  // "id" | "postId"
```

An Express-style router can type `req.params` from the route string. Python's type system contains no string operations whatsoever — a route string is just `str`.

### 5. Recursive tuple computation vs mere concatenation

```ts
type Reverse<T extends unknown[]> = T extends [infer H, ...infer R] ? [...Reverse<R>, H] : [];
type X = Reverse<[1, 2, 3]>;  // [3, 2, 1]
```

Python's `TypeVarTuple` can concatenate — `tuple[int, *Ts]` — but cannot destructure into head/tail, and with no conditional types there is no recursion. Python can pass tuples through; TypeScript can compute over them. Examples 1, 4, and 5 together are what makes TypeScript types Turing-complete — type-level SQL parsers are real.

### 6. Intersection types

```ts
function merge<A, B>(a: A, b: B): A & B { return { ...a, ...b }; }
```

Python has `|` but no `&` — an `Intersection` proposal has been discussed for years and never landed. `merge` cannot be typed precisely; you define a named Protocol combining both members for each case.

### 7. Declaration merging / module augmentation

```ts
declare module "express-serve-static-core" {
  interface Request { user?: AuthUser }   // adds a field to a third-party type
}
```

Python cannot extend a third-party class's type from the outside — you replace its entire stub or you don't.

### 8. `as const` + `satisfies` — deep literal inference without widening

```ts
const config = { port: 8080, mode: "dev", tags: ["a", "b"] } as const satisfies Config;
// { readonly port: 8080; readonly mode: "dev"; readonly tags: readonly ["a", "b"] }
```

Checked against `Config` yet keeping the exact literals. Python's `Final` gives shallow literals for scalars; there is no deep-freeze inference and no check-without-widen operator.

### 9. Assertion functions

```ts
function assertUser(x: unknown): asserts x is User { /* throw if not */ }
assertUser(input);
input.name;  // narrowed from here on
```

Python's `TypeGuard`/`TypeIs` must return a bool; "narrows the caller's variable by raising" is not expressible.

## Possible in Python, not in TypeScript

### 10. Types exist at runtime — frameworks derive behavior from annotations

```python
@dataclass
class User:
    id: int
    name: str = "anon"      # __init__, __eq__, __repr__ generated FROM the annotations

class Order(BaseModel):     # pydantic
    id: int
    email: EmailStr
Order.model_validate_json(raw_bytes)   # runtime validation driven by the same types
```

TypeScript types are erased at compile time — an `interface` cannot validate anything. That is why zod exists and works backwards: you write a runtime value schema and derive the static type from it (`type User = z.infer<typeof user>`).

### 11. `Annotated` — metadata attached to types, readable at runtime

```python
Port = Annotated[int, Field(gt=0, lt=65536)]

@app.get("/items/{item_id}")
def read(item_id: Annotated[int, Path(gt=0)]): ...   # FastAPI: parsing, validation,
                                                     # and OpenAPI docs from one annotation
```

TypeScript has no mechanism for attaching metadata to a type — decorators annotate values, never types.

### 12. Runtime structural checks

```python
@runtime_checkable
class Closeable(Protocol):
    def close(self) -> None: ...

isinstance(resource, Closeable)   # True for ANY object with .close()
```

Plus `match`/`case` class patterns narrow both statically and at runtime. TypeScript's `instanceof` is nominal-only and interfaces don't survive to runtime; a structural runtime check requires hand-written predicates.

### 13. `NewType` — sanctioned zero-cost nominal types

```python
UserId = NewType("UserId", int)
def load(uid: UserId) -> User: ...
load(42)          # error
load(UserId(42))  # ok — identity function at runtime
```

The TypeScript idiom is branding — `type UserId = number & { __brand: "UserId" }` — which works but is a structural hack that lies about the value's shape.

### 14. Soundness: invariant mutable collections

```python
def feed(animals: list[Animal]) -> None:
    animals.append(Cat())
dogs: list[Dog] = [Dog()]
feed(dogs)        # REJECTED: list is invariant (pass Sequence[Animal] for reads)
```

```ts
function feed(animals: Animal[]) { animals.push(new Cat()); }
const dogs: Dog[] = [new Dog()];
feed(dogs);       // compiles — arrays are unsoundly covariant by design
dogs[1].bark();   // runtime explosion
```

Python's checkers also verify your declared variance on generic classes; TypeScript measures variance structurally and keeps deliberate holes (method-parameter bivariance) for ergonomics.

### 15. `TypeForm` (new in 3.15, PEP 747) — type expressions as first-class checked values

```python
def parse[T](form: TypeForm[T], raw: str) -> T: ...
x = parse(int | None, "42")   # T solved to int | None; x: int | None
```

Types as first-class checked values. In TypeScript, types and values are separate universes — you cannot pass `Promise<number>` to a function as an argument. Ironically Python gets this because its annotations are runtime objects.

### 16. `@final` — sealed classes and methods

```python
@final
class Token: ...
class Fake(Token): ...   # type error: cannot subclass
```

TypeScript has no `final`/`sealed`; the closest is a private-constructor trick.

## Where they have converged

Unions, literal types, generics (both with defaults now), flow narrowing, user-defined guards (`x is T` / `TypeIs`), overloads, `Self`/`this` typing, `readonly`/`ReadOnly`, exhaustiveness (`never`/`Never` + `assert_never`), and variance annotations (`in`/`out`) exist in both. Structural typing is TypeScript's default and Python's opt-in (`Protocol`).

Python 3.15's `class Movie(TypedDict, closed=True)` plus `extra_items=` is Python adopting what TypeScript has long done with excess-property checks and index signatures — the systems borrow from each other constantly. What doesn't transfer is TypeScript's computational layer (examples 1–5), which is architectural, and Python's runtime presence (examples 10–15), which TypeScript gave up the day it committed to full erasure.

## Sources

- [What's new in Python 3.15](https://docs.python.org/3.15/whatsnew/3.15.html)
- [InfoWorld — the best new features in Python 3.15](https://www.infoworld.com/article/4166693/the-best-new-features-in-python-3-15.html)
- [PEP 589 — TypedDict](https://peps.python.org/pep-0589/)
- [typing — Python documentation](https://docs.python.org/3/library/typing.html)
- [typing_extensions documentation](https://typing-extensions.readthedocs.io/)
- [TypeScript handbook and release notes](https://www.typescriptlang.org/docs/) as shipped in 7.0.2
