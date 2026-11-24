# cli workspace conventions (zaplang-io/cli)

This is an official non-core Zap module. Target: parity with the popular Python
equivalents (`click` / `typer`).

## Layer boundary (read first)
- `cli` is the high-level declarative framework. It builds on Zap core's `argparse`
  `ArgumentParser` object ([zaplang-io/zap#997](https://github.com/zaplang-io/zap/issues/997))
  as the parsing engine. Do NOT reimplement token-level argv parsing here; extend or
  wrap core instead. If core parsing is missing something `cli` needs, that is a core
  gap — see Language-first below.

## Language-first (non-negotiable)
- All language or stdlib bugs discovered while building this module MUST be reported in `zaplang-io/zap` FIRST, and no workaround is permitted. Keep the dependent work blocked or draft and report the dependency; never build the library around a core defect.

## Python parity & signatures
- Match the equivalent `click` / `typer` API surface and naming as closely as the language allows.
- Where a function/method/decorator signature is ambiguous or there is any confusion about argument shape, defaults, or keyword-vs-positional, do NOT just pick one: present the options to the maintainer with concrete examples of what `click` and `typer` do, and let the maintainer decide. Record the chosen design in `DECISIONS.md`.

## Tests
- All test cases live in the `tests/` folder and use the `zap test` methodology (`zap test tests/`).
- Every PR MUST include extensive positive AND negative test cases — treat tests as a walled garden and as intent documentation, not a minimal smoke check. Cover edge cases, error paths, and malformed input.
- When fixing a bug, write the failing test first, then fix.

## CI
- CI runs against `ghcr.io/zaplang-io/zap:latest` and MUST continue to pin `zap:latest` until this module reaches a proper major (1.0) version release; only then pin a released toolchain version.

## Issues & PRs
- Keep issues concrete and testable with detailed bodies (repro or intended syntax, click/typer equivalent, references).
- Multi-issue features get an Epic with trackable sub-issues. Individual issues are 'M' sized.
- One issue, one PR. Rebase onto the latest default branch before raising or updating a PR.
- Documentation (README, DECISIONS.md, CHANGELOG) stays current with every PR.
