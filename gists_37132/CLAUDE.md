# Code review standards

Apply these project-specific standards in addition to the default review checks.

## Linting and code quality

Never suppress, disable, or exclude files from linting, type checking, or any code quality tool. No ignore comments, no config exclusions, no disabled rules. A failing check means the underlying issue must be fixed, not silenced. Flag any diff that silences a tool instead of fixing the cause.

## Codebase ownership

Issues in code touched by the diff are in scope regardless of who introduced them. Do not wave away a problem as pre-existing, unrelated, or out of scope when it sits in the changed lines or is surfaced by the change. Cheap fixes (typos, renames, broken links) belong in the same change; expensive ones (flaky tests, deprecations, broad refactors) should be named explicitly.

## Reproducibility (configuration as code)

Any change to project or environment state must live in version-controlled config, never as a one-off command. The test: would a fresh clone and install reproduce the working state? A manually-built binding belongs in an install script, a manual env var in an example/deploy config, a system package in a setup script. Flag changes that depend on un-codified manual steps.

## Naming conventions

Every name answers: what does it hold, do, or represent? Use domain words. No filler, no type tag, no scope echo. Apply the language idiomatic casing on top of these rules.

- Spell names out; long-and-clear over short-and-clever. Mirror domain vocabulary.
- Drop type suffixes (`array`/`str`/`int`/`bool`/`dict`).
- Replace placeholder nouns (`data`/`info`/`value`/`item`/`result`/`output`) with what it actually is.
- Replace filler verbs (`process`/`handle`/`do`/`perform`/`execute`/`manage`) with what the function actually does.
- Start every function name with a verb; pick one verb per semantic and stay consistent. Match cost and intent:
  - reads: `get` cheap in-memory · `find` may miss · `list` collection · `fetch` network · `load` disk/cache · `calc` non-trivial derivation
  - shape: `parse` string → structured value · `serialize`/`format` structured value → string · `build`/`make` construct new value
  - writes: `save` persist · `create` new entity · `delete` remove · `ensure` make condition true (idempotent)
  - checks: `validate` check invariants (raises on failure)
- Name variables by what they hold, not how they are stored (`original image`, not `img1`); pluralise collections, singularise items.
- Drop scope echoes — inside `User`, the field is `email`, not `user email`.
- Phrase booleans as questions (`is`/`has`/`can`/`should`); prefer positive (`has value` over `is not empty`).
- Keep properties (`@property`, TS `get`/`set`) cheap and pure — no I/O or mutation; otherwise make it a method.
- Name constants by concept, not literal (`MAX_RETRY_ATTEMPTS`, never `THREE`).
- Use noun phrases for classes and types (`order processor`, not `process order`); no `T` prefix or `Type`/`Impl` suffix.
- End error classes with `Error` (`parse address Error`); keep one word order across siblings.

## Code comments

Code should not need comments. Prefer clear naming, simple structure, and obvious flow over an explanatory comment. Flag comments that exist to explain code that could instead be simplified.

## README files

README.md is for instructions, not explanations. Keep it minimalist.

## Diagrams in markdown

Diagrams in markdown must be Mermaid, not ASCII art.
