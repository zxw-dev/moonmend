///|
test "product name" {
  assert_eq(product_name(), "MoonMend")
}

///|
test "parse interface snapshot" {
  let source =
    #|package "zxw-dev/example"
    #|
    #|// Values
    #|pub fn add(a : Int, b : Int) -> Int
    #|
    #|// Types and methods
    #|pub struct User {
    #|  name : String
    #|  age : Int
    #|}
  let result = parse_interface(source)
  guard result is Ok(snapshot) else { fail("expected a valid snapshot") }
  assert_eq(snapshot.package_name, "zxw-dev/example")
  assert_eq(snapshot.declarations.length(), 2)
  assert_eq(
    snapshot.to_json_string(),
    "{\n" +
    "  \"package_name\": \"zxw-dev/example\",\n" +
    "  \"declarations\": [\n" +
    "    {\n" +
    "      \"kind\": \"function\",\n" +
    "      \"value\": {\n" +
    "        \"name\": \"add\",\n" +
    "        \"parameters\": [\n" +
    "          {\n" +
    "            \"name\": \"a\",\n" +
    "            \"type_name\": \"Int\"\n" +
    "          },\n" +
    "          {\n" +
    "            \"name\": \"b\",\n" +
    "            \"type_name\": \"Int\"\n" +
    "          }\n" +
    "        ],\n" +
    "        \"return_type\": \"Int\"\n" +
    "      }\n" +
    "    },\n" +
    "    {\n" +
    "      \"kind\": \"struct\",\n" +
    "      \"value\": {\n" +
    "        \"name\": \"User\",\n" +
    "        \"fields\": [\n" +
    "          {\n" +
    "            \"name\": \"name\",\n" +
    "            \"type_name\": \"String\"\n" +
    "          },\n" +
    "          {\n" +
    "            \"name\": \"age\",\n" +
    "            \"type_name\": \"Int\"\n" +
    "          }\n" +
    "        ]\n" +
    "      }\n" +
    "    }\n" +
    "  ]\n" +
    "}",
  )
}

///|
test "parse unnamed and nested generic parameters" {
  let source =
    #|package "zxw-dev/example"
    #|pub fn lookup(Map[String, Array[Int]], index? : Int) -> String?
  let result = parse_interface(source)
  guard result is Ok(snapshot) else { fail("expected a valid snapshot") }
  guard snapshot.declarations[0] is Function(function) else {
    fail("expected a function")
  }
  assert_eq(function.parameters.length(), 2)
  assert_eq(function.parameters[0].name, None)
  assert_eq(function.parameters[0].type_name, "Map[String, Array[Int]]")
  assert_eq(function.parameters[1].name, Some("index?"))
  assert_eq(function.return_type, "String?")
}

///|
test "reject malformed parameter" {
  let source =
    #|package "zxw-dev/example"
    #|pub fn broken(value : ) -> Int
  assert_true(parse_interface(source) is Err(_))
}

///|
test "reject unterminated struct" {
  let source =
    #|package "zxw-dev/example"
    #|pub struct User {
    #|  name : String
  assert_true(parse_interface(source) is Err(_))
}

///|
test "diff snapshots classify additions removals modifications and renames" {
  let old_source =
    #|package "zxw-dev/example"
    #|pub fn add(a : Int, b : Int) -> Int
    #|pub fn get_user(id : Int, active : Bool) -> User?
    #|pub fn legacy_lookup(id : Int) -> User?
    #|pub struct User {
    #|  name : String
    #|  age : Int
    #|}
  let new_source =
    #|package "zxw-dev/example"
    #|pub fn add(a : Int, b : Int) -> String
    #|pub fn fetch_user(id : Int, active : Bool) -> User?
    #|pub fn delete_user(id : Int) -> Unit
    #|pub struct User {
    #|  name : String
    #|  age : UInt
    #|}
  let old = parse_interface(old_source)
  let new = parse_interface(new_source)
  guard old is Ok(old_snapshot) else { fail("old snapshot is invalid") }
  guard new is Ok(new_snapshot) else { fail("new snapshot is invalid") }
  let diff = diff_interfaces(old_snapshot, new_snapshot)
  assert_eq(diff.changes.length(), 5)
  let kinds = diff.changes.map(change => change.kind()).join(",")
  assert_eq(
    kinds, "function_modified,function_renamed,function_removed,function_added,struct_modified",
  )
  assert_eq(diff.breaking_count(), 4)
  assert_eq(diff.non_breaking_count(), 1)
  assert_eq(diff.unknown_count(), 0)
  assert_true(diff.has_breaking_changes())
  assert_true(diff.to_json_string().contains("\"has_breaking\": true"))
  assert_true(diff.to_markdown().contains("[breaking]"))
  assert_true(diff.to_json_string().contains("\"function_renamed\""))
  assert_true(diff.to_markdown().contains("Renamed function `get_user`"))
}

///|
test "diff snapshots are deterministic when there are no changes" {
  let source =
    #|package "zxw-dev/example"
    #|pub fn ping() -> Unit
  let snapshot = match parse_interface(source) {
    Ok(snapshot) => snapshot
    Err(message) => abort(message)
  }
  let diff = diff_interfaces(snapshot, snapshot)
  assert_true(diff.changes.is_empty())
  assert_eq(
    diff.to_markdown(),
    "# MoonMend Interface Diff\n\n" +
    "- Old package: `zxw-dev/example`\n" +
    "- New package: `zxw-dev/example`\n" +
    "- Changes: 0\n" +
    "- Breaking changes: 0\n" +
    "- Non-breaking changes: 0\n" +
    "- Unknown changes: 0\n\n" +
    "No public API changes detected.",
  )
}

///|
test "ambiguous rename candidates remain added and removed" {
  let old_source =
    #|package "zxw-dev/example"
    #|pub fn alpha() -> Unit
  let new_source =
    #|package "zxw-dev/example"
    #|pub fn omega() -> Unit
  let old = match parse_interface(old_source) {
    Ok(snapshot) => snapshot
    Err(message) => abort(message)
  }
  let new = match parse_interface(new_source) {
    Ok(snapshot) => snapshot
    Err(message) => abort(message)
  }
  let diff = diff_interfaces(old, new)
  let kinds = diff.changes.map(change => change.kind()).join(",")
  assert_eq(kinds, "function_removed,function_added")
}

///|
test "migration plan assigns strategies and renders dry run" {
  let old_source =
    #|package "zxw-dev/example"
    #|pub fn get_user(id : Int) -> User?
    #|pub fn remove_user(id : Int) -> Unit
    #|pub struct User {
    #|  name : String
    #|}
  let new_source =
    #|package "zxw-dev/example"
    #|pub fn fetch_user(id : Int) -> User?
    #|pub fn create_user(name : String) -> User
    #|pub struct User {
    #|  name : String
    #|  active : Bool
    #|}
  let old = parse_interface(old_source)
  let new = parse_interface(new_source)
  guard old is Ok(old_snapshot) else { fail("old snapshot is invalid") }
  guard new is Ok(new_snapshot) else { fail("new snapshot is invalid") }
  let plan = diff_interfaces(old_snapshot, new_snapshot) |> plan_migration
  assert_eq(plan.actions.length(), 4)
  let strategies = plan.actions.map(action => action.strategy.name()).join(",")
  assert_eq(strategies, "automatic,manual,informational,manual")
  assert_true(plan.to_json_string().contains("\"strategy\": \"automatic\""))
  assert_true(plan.to_markdown().contains("## automatic (1)"))
  assert_true(plan.to_unified_diff().contains("-get_user"))
  assert_true(plan.to_unified_diff().contains("+fetch_user"))
}

///|
test "migration plan reports no automatic changes" {
  let old_source =
    #|package "zxw-dev/example"
    #|pub fn old_api() -> Unit
  let new_source =
    #|package "zxw-dev/example"
    #|pub fn completely_new() -> Unit
  let old = match parse_interface(old_source) {
    Ok(snapshot) => snapshot
    Err(message) => abort(message)
  }
  let new = match parse_interface(new_source) {
    Ok(snapshot) => snapshot
    Err(message) => abort(message)
  }
  let plan = plan_migration(diff_interfaces(old, new))
  assert_eq(plan.to_unified_diff(), "# No automatic changes to preview.")
}

///|
test "source migration replaces identifiers outside comments and strings" {
  let old_source =
    #|package "zxw-dev/example"
    #|pub fn get_user(id : Int) -> User?
  let new_source =
    #|package "zxw-dev/example"
    #|pub fn fetch_user(id : Int) -> User?
  let old = match parse_interface(old_source) {
    Ok(snapshot) => snapshot
    Err(message) => abort(message)
  }
  let new = match parse_interface(new_source) {
    Ok(snapshot) => snapshot
    Err(message) => abort(message)
  }
  let plan = plan_migration(diff_interfaces(old, new))
  let source =
    #|let user = get_user(1)
    #|let text = "get_user"
    #|// get_user should remain in comments
    #|let other = get_user_extra(2)
  let actual = replace_identifiers(source, plan.actions)
  let expected =
    #|let user = fetch_user(1)
    #|let text = "get_user"
    #|// get_user should remain in comments
    #|let other = get_user_extra(2)
  assert_eq(actual, expected)
}

///|
test "source migration preview renders a unified diff" {
  let plan : MigrationPlan = {
    old_package: "zxw-dev/example",
    new_package: "zxw-dev/example",
    actions: [
      {
        strategy: Automatic,
        kind: "rename_function",
        target: "fetch_user",
        before: Some("get_user"),
        after: Some("fetch_user"),
        description: "rename",
      },
    ],
  }
  let preview = preview_source_migration(
    [{ path: "src/main.mbt", content: "let user = get_user(1)\n", }],
    plan,
  )
  assert_false(preview.is_empty())
  let diff = preview.to_unified_diff()
  assert_true(diff.contains("--- a/src/main.mbt"))
  assert_true(diff.contains("-let user = get_user(1)"))
  assert_true(diff.contains("+let user = fetch_user(1)"))
}
