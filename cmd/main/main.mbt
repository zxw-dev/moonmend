///|
fn print_usage() -> Unit {
  println(
    "MoonMend - MoonBit API migration and safe upgrade assistant\n\n" +
    "Usage:\n" +
    "  moonmend diff <old.mbti> <new.mbti> [--format markdown|json] [--output <path>] [--fail-on-breaking]\n" +
    "  moonmend plan <old.mbti> <new.mbti> [--format markdown|json|diff] [--output <path>] [--fail-on-breaking]\n" +
    "  moonmend migrate <project> <old.mbti> <new.mbti> [--apply] [--output <patch>]\n",
  )
}

///|
fn option_value(args : Array[String], name : String) -> String? {
  let mut index = 0
  while index + 1 < args.length() {
    if args[index] == name {
      return Some(args[index + 1])
    }
    index += 1
  }
  None
}

///|
fn has_flag(args : Array[String], name : String) -> Bool {
  for arg in args {
    if arg == name {
      return true
    }
  }
  false
}

///|
fn enforce_compatibility_gate(
  diff : @lib.InterfaceDiff,
  args : Array[String],
) -> Result[Unit, String] {
  if has_flag(args, "--fail-on-breaking") && diff.has_breaking_changes() {
    Err("\{diff.breaking_count()} breaking API change(s) detected")
  } else {
    Ok(())
  }
}

///|
fn load_snapshot(path : String) -> Result[@lib.InterfaceSnapshot, String] {
  let source = @fs.read_file_to_string(path) catch {
    @fs.IOError(message) => return Err("failed to read \{path}: \{message}")
  }
  match @lib.parse_interface(source) {
    Ok(snapshot) => Ok(snapshot)
    Err(message) => Err("failed to parse \{path}: \{message}")
  }
}

///|
fn write_report(path : String, report : String) -> Result[Unit, String] {
  try {
    @fs.write_string_to_file(path, report)
    Ok(())
  } catch {
    @fs.IOError(message) => Err("failed to write \{path}: \{message}")
  }
}

///|
fn join_path(parent : String, child : String) -> String {
  if parent.is_empty() {
    child
  } else if parent.has_suffix("/") || parent.has_suffix("\\") {
    parent + child
  } else {
    parent + "/" + child
  }
}

///|
fn should_skip_directory(name : String) -> Bool {
  name == ".git" ||
  name == "_build" ||
  name == "target" ||
  name == ".mooncakes" ||
  name == ".moonagent"
}

///|
fn collect_source_files(
  current : String,
  relative : String,
  files : Array[@lib.SourceFile],
) -> Result[Unit, String] {
  let entries = @fs.read_dir(current) catch {
    @fs.IOError(message) =>
      return Err("failed to read directory \{current}: \{message}")
  }
  for name in entries {
    let path = join_path(current, name)
    let relative_path = if relative.is_empty() {
      name
    } else {
      relative + "/" + name
    }
    let is_dir = @fs.is_dir(path) catch {
      @fs.IOError(message) =>
        return Err("failed to inspect \{path}: \{message}")
    }
    if is_dir {
      if !should_skip_directory(name) {
        match collect_source_files(path, relative_path, files) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      }
    } else if name.has_suffix(".mbt") {
      let content = @fs.read_file_to_string(path) catch {
        @fs.IOError(message) => return Err("failed to read \{path}: \{message}")
      }
      files.push({ path: relative_path, content, })
    }
  }
  Ok(())
}

///|
fn load_source_files(
  project : String,
) -> Result[Array[@lib.SourceFile], String] {
  let files : Array[@lib.SourceFile] = []
  match collect_source_files(project, "", files) {
    Ok(_) => Ok(files)
    Err(message) => Err(message)
  }
}

///|
fn write_source_file(
  project : String,
  path : String,
  content : String,
) -> Result[Unit, String] {
  let full_path = join_path(project, path)
  @fs.write_string_to_file(full_path, content) catch {
    @fs.IOError(message) =>
      return Err("failed to write \{full_path}: \{message}")
  }
  Ok(())
}

///|
fn rollback_preview(
  project : String,
  preview : @lib.MigrationPreview,
) -> Result[Unit, String] {
  for file in preview.files {
    match write_source_file(project, file.path, file.before) {
      Ok(_) => ()
      Err(message) => return Err("rollback failed: \{message}")
    }
  }
  Ok(())
}

///|
async fn run_moon_command(
  project : String,
  command : String,
) -> Result[(Int32, String), String] {
  let arguments = if command == "check" { ["check"] } else { ["test"] }
  let (code, output) = @process.collect_output_merged(
    "moon",
    arguments,
    cwd=project,
    no_console_window=true,
  ) catch {
    _ => return Err("failed to run moon \{command} in \{project}")
  }
  Ok((code, output.text()))
}

///|
async fn verify_migration(
  project : String,
  preview : @lib.MigrationPreview,
) -> Result[Unit, String] {
  let (check_code, check_output) = match run_moon_command(project, "check") {
    Ok(result) => result
    Err(message) => {
      rollback_preview(project, preview) |> ignore
      return Err(message)
    }
  }
  if check_code != 0 {
    let rollback = rollback_preview(project, preview)
    match rollback {
      Ok(_) =>
        Err("moon check failed; changes were rolled back.\n\{check_output}")
      Err(message) => Err("moon check failed and rollback failed: \{message}")
    }
  } else {
    let (test_code, test_output) = match run_moon_command(project, "test") {
      Ok(result) => result
      Err(message) => {
        rollback_preview(project, preview) |> ignore
        return Err(message)
      }
    }
    if test_code != 0 {
      match rollback_preview(project, preview) {
        Ok(_) =>
          Err("moon test failed; changes were rolled back.\n\{test_output}")
        Err(message) => Err("moon test failed and rollback failed: \{message}")
      }
    } else {
      Ok(())
    }
  }
}

///|
async fn run_migrate(args : Array[String]) -> Result[Unit, String] {
  if args.length() < 5 {
    return Err("migrate requires <project> <old.mbti> <new.mbti>")
  }
  let project = args[2]
  let old = match load_snapshot(args[3]) {
    Ok(snapshot) => snapshot
    Err(message) => return Err(message)
  }
  let new = match load_snapshot(args[4]) {
    Ok(snapshot) => snapshot
    Err(message) => return Err(message)
  }
  let plan = @lib.diff_interfaces(old, new) |> @lib.plan_migration
  let files = match load_source_files(project) {
    Ok(files) => files
    Err(message) => return Err(message)
  }
  let preview = @lib.preview_source_migration(files, plan)
  let patch = preview.to_unified_diff()
  match option_value(args, "--output") {
    None => println(patch)
    Some(path) =>
      match write_report(path, patch) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
  }
  if preview.is_empty() {
    println("No automatic source changes found.")
    return Ok(())
  }
  if !has_flag(args, "--apply") {
    println("Dry run only. Re-run with --apply to write these changes.")
    return Ok(())
  }
  for file in preview.files {
    match write_source_file(project, file.path, file.after) {
      Ok(_) => ()
      Err(message) => {
        rollback_preview(project, preview) |> ignore
        return Err(
          "failed to apply migration and rollback was attempted: \{message}",
        )
      }
    }
  }
  match verify_migration(project, preview) {
    Ok(_) => {
      println(
        "Migration applied successfully: \{preview.files.length()} file(s) changed.",
      )
      Ok(())
    }
    Err(message) => Err(message)
  }
}

///|
fn run_diff(args : Array[String]) -> Result[Unit, String] {
  if args.length() < 4 {
    return Err("diff requires <old.mbti> and <new.mbti>")
  }
  let old = match load_snapshot(args[2]) {
    Ok(snapshot) => snapshot
    Err(message) => return Err(message)
  }
  let new = match load_snapshot(args[3]) {
    Ok(snapshot) => snapshot
    Err(message) => return Err(message)
  }
  let format = match option_value(args, "--format") {
    None => "markdown"
    Some(format) => format
  }
  let diff = @lib.diff_interfaces(old, new)
  let report = match format {
    "markdown" => diff.to_markdown()
    "json" => diff.to_json_string()
    _ => return Err("unsupported format \{format}; expected markdown or json")
  }
  match option_value(args, "--output") {
    None => {
      println(report)
      enforce_compatibility_gate(diff, args)
    }
    Some(path) =>
      match write_report(path, report) {
        Ok(_) => enforce_compatibility_gate(diff, args)
        Err(message) => Err(message)
      }
  }
}

///|
fn run_plan(args : Array[String]) -> Result[Unit, String] {
  if args.length() < 4 {
    return Err("plan requires <old.mbti> and <new.mbti>")
  }
  let old = match load_snapshot(args[2]) {
    Ok(snapshot) => snapshot
    Err(message) => return Err(message)
  }
  let new = match load_snapshot(args[3]) {
    Ok(snapshot) => snapshot
    Err(message) => return Err(message)
  }
  let format = match option_value(args, "--format") {
    None => "markdown"
    Some(format) => format
  }
  let diff = @lib.diff_interfaces(old, new)
  let plan = diff |> @lib.plan_migration
  let report = match format {
    "markdown" => plan.to_markdown()
    "json" => plan.to_json_string()
    "diff" => plan.to_unified_diff()
    _ =>
      return Err(
        "unsupported format \{format}; expected markdown, json, or diff",
      )
  }
  match option_value(args, "--output") {
    None => {
      println(report)
      enforce_compatibility_gate(diff, args)
    }
    Some(path) =>
      match write_report(path, report) {
        Ok(_) => enforce_compatibility_gate(diff, args)
        Err(message) => Err(message)
      }
  }
}

///|
async fn run(args : Array[String]) -> Result[Unit, String] {
  if args.length() < 2 {
    return Err("missing command")
  }
  match args[1] {
    "diff" => run_diff(args)
    "plan" => run_plan(args)
    "migrate" => run_migrate(args)
    "help" | "--help" | "-h" => {
      print_usage()
      Ok(())
    }
    command => Err("unknown command \{command}")
  }
}

///|
/// Entry point for the MoonMend CLI.
async fn main {
  match run(@env.args()) {
    Ok(_) => ()
    Err(message) => {
      println("error: \{message}\n")
      print_usage()
      @sys.exit(2)
    }
  }
}
