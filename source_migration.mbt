///|
/// One source file participating in a migration preview.
pub(all) struct SourceFile {
  path : String
  content : String
}

///|
/// Before and after content for a changed source file.
pub(all) struct FileMigration {
  path : String
  before : String
  after : String
}

///|
/// A deterministic set of source edits produced by automatic plan actions.
pub(all) struct MigrationPreview {
  files : Array[FileMigration]
}

///|
fn is_identifier_start(char : Char?) -> Bool {
  guard char is Some(value) else { return false }
  value == '_' || value.is_ascii_alphabetic()
}

///|
fn is_identifier_continue(char : Char?) -> Bool {
  guard char is Some(value) else { return false }
  value == '_' || value.is_ascii_alphabetic() || value.is_ascii_digit()
}

///|
fn replacement_for_token(
  token : String,
  actions : Array[MigrationAction],
) -> String? {
  for action in actions {
    if action.strategy.name() == "automatic" {
      match (action.before, action.after) {
        (Some(before), Some(after)) => if token == before { return Some(after) }
        _ => ()
      }
    }
  }
  None
}

///|
fn append_char(
  segments : Array[String],
  content : String,
  index : Int32,
) -> Unit {
  segments.push(content[index:index + 1].to_owned())
}

///|
/// Replace identifier tokens while leaving line comments and string/char
/// literals unchanged.
pub fn replace_identifiers(
  content : String,
  actions : Array[MigrationAction],
) -> String {
  let segments : Array[String] = []
  let mut index = 0
  let mut in_line_comment = false
  let mut in_string = false
  let mut in_char = false
  while index < content.length() {
    let char = content.get_char(index)
    if in_line_comment {
      if char == Some('\n') {
        in_line_comment = false
      }
      append_char(segments, content, index)
      index += 1
      continue
    }
    if in_string || in_char {
      if char == Some('\\') && index + 1 < content.length() {
        append_char(segments, content, index)
        index += 1
        append_char(segments, content, index)
        index += 1
        continue
      }
      if in_string && char == Some('"') {
        in_string = false
      } else if in_char && char == Some('\'') {
        in_char = false
      }
      append_char(segments, content, index)
      index += 1
      continue
    }
    if char == Some('/') &&
      index + 1 < content.length() &&
      content.get_char(index + 1) == Some('/') {
      segments.push("//")
      index += 2
      in_line_comment = true
      continue
    }
    if char == Some('"') {
      in_string = true
      append_char(segments, content, index)
      index += 1
      continue
    }
    if char == Some('\'') {
      in_char = true
      append_char(segments, content, index)
      index += 1
      continue
    }
    if is_identifier_start(char) {
      let start = index
      index += 1
      while index < content.length() &&
            is_identifier_continue(content.get_char(index)) {
        index += 1
      }
      let token = content[start:index].to_owned()
      match replacement_for_token(token, actions) {
        Some(replacement) => segments.push(replacement)
        None => segments.push(token)
      }
      continue
    }
    append_char(segments, content, index)
    index += 1
  }
  segments.join("")
}

///|
/// Apply automatic plan actions to a set of source files.
pub fn preview_source_migration(
  files : Array[SourceFile],
  plan : MigrationPlan,
) -> MigrationPreview {
  let changed : Array[FileMigration] = []
  let actions = plan.actions.filter(action => {
    action.strategy.name() == "automatic"
  })
  if actions.is_empty() {
    return { files: changed, }
  }
  for file in files {
    let after = replace_identifiers(file.content, actions)
    if after != file.content {
      changed.push({ path: file.path, before: file.content, after, })
    }
  }
  { files: changed, }
}

///|
pub fn MigrationPreview::is_empty(self : MigrationPreview) -> Bool {
  self.files.is_empty()
}

///|
fn append_full_file_diff(lines : Array[String], file : FileMigration) -> Unit {
  let before_lines = file.before.split("\n").to_array()
  let after_lines = file.after.split("\n").to_array()
  lines.push("--- a/\{file.path}")
  lines.push("+++ b/\{file.path}")
  lines.push("@@ -1,\{before_lines.length()} +1,\{after_lines.length()} @@")
  for line in before_lines {
    lines.push("-\{line}")
  }
  for line in after_lines {
    lines.push("+\{line}")
  }
}

///|
pub fn MigrationPreview::to_unified_diff(self : MigrationPreview) -> String {
  if self.files.is_empty() {
    return "# No automatic source changes found."
  }
  let lines : Array[String] = []
  for file in self.files {
    append_full_file_diff(lines, file)
  }
  lines.join("\n")
}
