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

## Development

Requirements:

- MoonBit toolchain
- Git

Run the executable:

```powershell
moon run cmd/main
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
