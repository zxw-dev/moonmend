///|
fn print_usage() -> Unit {
  println(
    "MoonMend - MoonBit API migration and safe upgrade assistant\n\n" +
    "Usage:\n" +
    "  moonmend diff <old.mbti> <new.mbti> [--format markdown|json] [--output <path>]\n" +
    "  moonmend plan <old.mbti> <new.mbti> [--format markdown|json|diff] [--output <path>]\n",
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
      Ok(())
    }
    Some(path) => write_report(path, report)
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
  let plan = @lib.diff_interfaces(old, new) |> @lib.plan_migration
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
      Ok(())
    }
    Some(path) => write_report(path, report)
  }
}

///|
fn run(args : Array[String]) -> Result[Unit, String] {
  if args.length() < 2 {
    return Err("missing command")
  }
  match args[1] {
    "diff" => run_diff(args)
    "plan" => run_plan(args)
    "help" | "--help" | "-h" => {
      print_usage()
      Ok(())
    }
    command => Err("unknown command \{command}")
  }
}

///|
/// Entry point for the MoonMend CLI.
fn main {
  match run(@env.args()) {
    Ok(_) => ()
    Err(message) => {
      println("error: \{message}\n")
      print_usage()
      @sys.exit(2)
    }
  }
}
