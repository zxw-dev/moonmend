# MoonMend Demo

This walkthrough uses the committed fixtures and can be reproduced from the
repository root.

## 1. Inspect compatibility

```powershell
moon run cmd/main -- diff fixtures/v1/pkg.generated.mbti fixtures/v2/pkg.generated.mbti
```

Expected summary:

```text
Changes: 5
Breaking changes: 4
Non-breaking changes: 1
```

## 2. Enforce a CI gate

```powershell
moon run cmd/main -- diff fixtures/v1/pkg.generated.mbti fixtures/v2/pkg.generated.mbti --fail-on-breaking
```

The report is printed and the command exits with code `2`.

## 3. Generate a migration plan

```powershell
moon run cmd/main -- plan fixtures/v1/pkg.generated.mbti fixtures/v2/pkg.generated.mbti
moon run cmd/main -- plan fixtures/v1/pkg.generated.mbti fixtures/v2/pkg.generated.mbti --format json
moon run cmd/main -- plan fixtures/v1/pkg.generated.mbti fixtures/v2/pkg.generated.mbti --format diff
```

The plan separates automatic, manual, and informational actions.

## 4. Preview source migration

```powershell
moon run cmd/main -- migrate fixtures/demo-project fixtures/v1/pkg.generated.mbti fixtures/v2/pkg.generated.mbti
```

The command rewrites nothing and prints a unified diff for `main.mbt` and
`main_test.mbt`.

## 5. Apply and verify

Run the complete success and rollback flow with:

```bash
bash scripts/ci-smoke.sh
```

The smoke test copies the demo project to temporary directories, applies the
migration, verifies both MoonBit commands, introduces a failing test, and
confirms that MoonMend restores the original files.
