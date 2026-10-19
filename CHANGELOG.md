# Changelog

## 0.1.0 - 2026-10-19

- Added generated `.mbti` parsing for functions, structs, enums, traits, type
  aliases, constants, and impls.
- Added deterministic interface diffing with rename inference.
- Added breaking/non-breaking compatibility summaries and CI gates.
- Added JSON, Markdown, migration plan, and unified diff output.
- Added safe identifier migration, `moon check` / `moon test` verification, and
  rollback.
- Added fixtures, 14 unit tests, CLI smoke tests, and GitHub Actions CI.

### Known limitations

- Source migration is identifier-level rather than full AST-level rewriting.
- Only deterministic function and struct renames are applied automatically.
- Module moves and import-path rewrites are not automated.
