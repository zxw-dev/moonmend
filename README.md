# MoonMend

[![CI](https://github.com/zxw-dev/moonmend/actions/workflows/ci.yml/badge.svg)](https://github.com/zxw-dev/moonmend/actions/workflows/ci.yml)

MoonMend is a MoonBit API migration and safe upgrade assistant.

It compares the public interfaces of two package versions, reports breaking
changes, and prepares verifiable migration patches for changes that can be
applied safely.

## Status

MoonMend `v0.1.0` is a working MVP for the MoonBit October 2026 Hackathon.
It provides a MoonBit library, a native CLI, automated tests, migration
rollback, and GitHub Actions CI.

## Implemented Capabilities

- Read and normalize generated `.mbti` interfaces.
- Classify added, removed, modified, and renamed declarations.
- Report `breaking`, `non-breaking`, and `unknown` compatibility levels.
- Generate JSON and Markdown diff reports.
- Generate deterministic migration plans.
- Preview real unified source diffs.
- Apply automatic identifier renames.
- Run `moon check` and `moon test` after migration.
- Restore original files when verification fails.
- Preserve unsupported public declarations in the snapshot output.

## Interface Parser

The first parser iteration handles generated interfaces containing:

- package declarations
- public functions and parameters
- public structs and fields
- enums, traits, type aliases, constants, and impls
- nested generic types

It produces a normalized `InterfaceSnapshot` with deterministic JSON output.
Unsupported public declarations are preserved in the snapshot's `unsupported`
list instead of being silently ignored.

```moonbit
let snapshot = parse_interface(source)
match snapshot {
  Ok(snapshot) => println(snapshot.to_json_string())
  Err(message) => println("parse error: " + message)
}
```

Example inputs are available under `fixtures/v1` and `fixtures/v2`.
Extended declaration examples are in `fixtures/extended-v1.mbti` and
`fixtures/extended-v2.mbti`.

## Interface Diff

`diff_interfaces` compares two snapshots and produces a deterministic list of
added, removed, modified, and renamed functions or structs.

```moonbit
let diff = diff_interfaces(old_snapshot, new_snapshot)
println(diff.to_json_string())
println(diff.to_markdown())
```

Renames are reported only when the API shape is identical and the name
similarity is high enough; ambiguous candidates remain separate removals and
additions.

## Dependencies

- [`moonbitlang/x`](https://github.com/moonbitlang/x), Apache-2.0, used for
  cross-platform file input and output.
- [`moonbitlang/async`](https://github.com/moonbitlang/async), Apache-2.0, used
  to run `moon check` and `moon test` during migration verification.

## Installation

Requirements:

- MoonBit toolchain
- Git

```powershell
git clone https://github.com/zxw-dev/moonmend.git
cd moonmend
moon update
moon check
moon test
```

## Development

Run the executable:

```powershell
moon run cmd/main -- diff fixtures/v1/pkg.generated.mbti fixtures/v2/pkg.generated.mbti
```

Output JSON instead:

```powershell
moon run cmd/main -- diff fixtures/v1/pkg.generated.mbti fixtures/v2/pkg.generated.mbti --format json
```

Fail the command when a breaking API change is detected:

```powershell
moon run cmd/main -- diff fixtures/v1/pkg.generated.mbti fixtures/v2/pkg.generated.mbti --fail-on-breaking
```

Write the report to a file:

```powershell
moon run cmd/main -- diff fixtures/v1/pkg.generated.mbti fixtures/v2/pkg.generated.mbti --output report.md
```

Generate a dry-run migration plan:

```powershell
moon run cmd/main -- plan fixtures/v1/pkg.generated.mbti fixtures/v2/pkg.generated.mbti
```

Generate plan JSON or a unified diff preview:

```powershell
moon run cmd/main -- plan fixtures/v1/pkg.generated.mbti fixtures/v2/pkg.generated.mbti --format json
moon run cmd/main -- plan fixtures/v1/pkg.generated.mbti fixtures/v2/pkg.generated.mbti --format diff
```

Preview and apply automatic source migrations:

```powershell
moon run cmd/main -- migrate fixtures/demo-project fixtures/v1/pkg.generated.mbti fixtures/v2/pkg.generated.mbti
moon run cmd/main -- migrate fixtures/demo-project fixtures/v1/pkg.generated.mbti fixtures/v2/pkg.generated.mbti --apply
```

`--apply` runs `moon check` and `moon test` in the target project. If either
command fails, MoonMend restores all modified files.

Run tests:

```powershell
moon test
```

Run the CLI smoke suite locally with Bash:

```bash
bash scripts/ci-smoke.sh
```

Format and update generated interfaces:

```powershell
moon fmt
moon info
```

## Limitations

- Automatic migration currently handles deterministic function and struct
  renames. Signature, enum, trait, alias, constant, and impl changes require
  manual review.
- Source rewriting is token-aware but not AST-based. It skips strings, chars,
  and line comments, but does not resolve same-named identifiers through full
  MoonBit name resolution.
- Module moves, visibility changes, and import-path rewrites are not automatic.
- Trait, enum, alias, constant, and impl declarations are normalized as stable
  interface signatures for diffing rather than fully decomposed semantic ASTs.
- Rollback restores file contents; it does not undo unrelated user changes made
  concurrently in the same files.

## AI Use

AI tools may assist with implementation, tests, and documentation. MoonMend's
runtime behavior is deterministic and does not call a model. The participant
must review the parser scope, migration rules, tests, and security boundaries.

## Repository Layout

```text
cmd/main/          CLI executable
moonmend.mbt       Library entry point
*_test.mbt         Blackbox tests
*_wbtest.mbt       Whitebox tests
fixtures/          Interface, migration, and rollback examples
scripts/           CLI smoke tests
docs/              Reproducible demo instructions
.github/workflows/ CI
PROPOSAL.md        Hackathon project proposal
```

## License

Apache-2.0
