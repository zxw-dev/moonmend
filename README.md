# MoonMend

MoonMend is a MoonBit API migration and safe upgrade assistant.

It compares the public interfaces of two package versions, reports breaking
changes, and prepares verifiable migration patches for changes that can be
applied safely.

## Status

The project is under active development for the MoonBit October 2026
Hackathon. The initial scaffold provides a MoonBit library package, an
executable CLI package, and tests.

## Planned MVP

- Read and normalize two versions of generated `.mbti` interfaces.
- Classify added, removed, renamed, moved, and signature changes.
- Generate JSON and Markdown migration reports.
- Produce reviewable diffs for high-confidence migrations.
- Validate applied migrations with `moon check` and `moon test`.

## Interface Parser

The first parser iteration handles generated interfaces containing:

- package declarations
- public functions and parameters
- public structs and fields
- nested generic types

It produces a normalized `InterfaceSnapshot` with deterministic JSON output.
Unsupported public declarations fail explicitly instead of being silently
ignored.

```moonbit
let snapshot = parse_interface(source)
match snapshot {
  Ok(snapshot) => println(snapshot.to_json_string())
  Err(message) => println("parse error: " + message)
}
```

Example inputs are available under `fixtures/v1` and `fixtures/v2`.

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

## Development

Requirements:

- MoonBit toolchain
- Git

Run the executable:

```powershell
moon run cmd/main -- diff fixtures/v1/pkg.generated.mbti fixtures/v2/pkg.generated.mbti
```

Output JSON instead:

```powershell
moon run cmd/main -- diff fixtures/v1/pkg.generated.mbti fixtures/v2/pkg.generated.mbti --format json
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

Run tests:

```powershell
moon test
```

Format and update generated interfaces:

```powershell
moon fmt
moon info
```

## Repository Layout

```text
cmd/main/          CLI executable
moonmend.mbt       Library entry point
*_test.mbt         Blackbox tests
*_wbtest.mbt       Whitebox tests
PROPOSAL.md        Hackathon project proposal
```

## License

Apache-2.0
