///|
fn parse_package_name(text : String) -> String? {
  if !text.has_prefix("package ") {
    return None
  }
  let raw = text[8:].trim().to_owned()
  if raw.length() < 2 ||
    raw.get_char(0) != Some('"') ||
    raw.get_char(raw.length() - 1) != Some('"') {
    return None
  }
  Some(raw[1:raw.length() - 1].to_owned())
}

///|
fn split_top_level(text : String) -> Array[String] {
  let result : Array[String] = []
  let mut start = 0
  let mut index = 0
  let mut depth = 0
  while index < text.length() {
    let char = text.get_char(index)
    match char {
      Some('(' | '[' | '{' | '<') => depth += 1
      Some(')' | ']' | '}' | '>') => if depth > 0 { depth -= 1 }
      Some(',') =>
        if depth == 0 {
          result.push(text[start:index].trim().to_owned())
          start = index + 1
        }
      _ => ()
    }
    index += 1
  }
  result.push(text[start:].trim().to_owned())
  result
}

///|
fn parse_parameter(text : String) -> Result[ApiParameter, String] {
  let trimmed = text.trim().to_owned()
  if trimmed.is_empty() {
    return Err("empty parameter")
  }
  match trimmed.find(":") {
    None => Ok({ name: None, type_name: trimmed, })
    Some(colon) => {
      let name = trimmed[:colon].trim().to_owned()
      let type_name = trimmed[colon + 1:].trim().to_owned()
      if name.is_empty() {
        return Err("parameter name is empty")
      }
      if type_name.is_empty() {
        return Err("parameter type is empty")
      }
      Ok({ name: Some(name), type_name, })
    }
  }
}

///|
fn parse_function(text : String) -> Result[ApiFunction, String] {
  let rest = if text.has_prefix("pub(all) fn ") {
    text[12:]
  } else if text.has_prefix("pub(open) fn ") {
    text[13:]
  } else {
    text[7:]
  }
  let open_paren = match rest.find("(") {
    Some(index) => index
    None => return Err("function is missing an opening parenthesis")
  }
  let close_paren = match rest.find(")") {
    Some(index) => index
    None => return Err("function is missing a closing parenthesis")
  }
  if close_paren < open_paren {
    return Err("function parentheses are out of order")
  }
  let name = rest[:open_paren].trim().to_owned()
  if name.is_empty() {
    return Err("function name is empty")
  }
  let parameters_text = rest[open_paren + 1:close_paren]
  let parameters : Array[ApiParameter] = []
  if !parameters_text.trim().is_empty() {
    for parameter_text in split_top_level(parameters_text.to_owned()) {
      match parse_parameter(parameter_text) {
        Ok(parameter) => parameters.push(parameter)
        Err(message) => return Err("invalid parameter in \{name}: \{message}")
      }
    }
  }
  let tail = rest[close_paren + 1:].trim().to_owned()
  let return_type = if tail.is_empty() {
    "Unit"
  } else if tail.has_prefix("->") {
    let parsed = tail[2:].trim().to_owned()
    if parsed.is_empty() {
      return Err("function \{name} has an empty return type")
    }
    parsed
  } else {
    return Err("function \{name} has an invalid return clause")
  }
  Ok({ name, parameters, return_type, })
}

///|
fn struct_name(text : String) -> String? {
  let rest = if text.has_prefix("pub(all) struct ") {
    text[16:]
  } else {
    text[11:]
  }
  let name = match rest.find("{") {
    Some(index) => rest[:index]
    None => rest
  }
  let name = name.trim().to_owned()
  if name.is_empty() {
    None
  } else {
    Some(name)
  }
}

///|
fn parse_field(text : String) -> Result[ApiField, String] {
  match text.find(":") {
    None => Err("field is missing a type")
    Some(colon) => {
      let name = text[:colon].trim().to_owned()
      let type_name = text[colon + 1:].trim().to_owned()
      if name.is_empty() {
        return Err("field name is empty")
      }
      if type_name.is_empty() {
        return Err("field type is empty")
      }
      Ok({ name, type_name, })
    }
  }
}

///|
fn parse_struct(
  lines : Array[StringView],
  start : Int32,
  text : String,
) -> Result[(ApiStruct, Int32), String] {
  let name = match struct_name(text) {
    Some(name) => name
    None => return Err("struct name is empty")
  }
  let fields : Array[ApiField] = []
  let mut index = start + 1
  while index < lines.length() {
    let field_line = lines[index].trim().to_owned()
    index += 1
    if field_line.is_empty() || field_line.has_prefix("//") {
      continue
    }
    if field_line == "}" {
      return Ok(({ name, fields, }, index))
    }
    match parse_field(field_line) {
      Ok(field) => fields.push(field)
      Err(message) => return Err("invalid field in struct \{name}: \{message}")
    }
  }
  Err("unterminated struct \{name}")
}

///|
fn declaration_rest(text : String) -> String {
  if text.has_prefix("pub(all) ") {
    text[9:].to_owned()
  } else if text.has_prefix("pub(open) ") {
    text[10:].to_owned()
  } else if text.has_prefix("pub ") {
    text[4:].to_owned()
  } else {
    text
  }
}

///|
fn declaration_name(text : String) -> String {
  let mut index = 0
  while index < text.length() {
    match text.get_char(index) {
      Some(char) =>
        if char.is_ascii_whitespace() ||
          char == '{' ||
          char == '=' ||
          char == ':' {
          break
        }
      None => break
    }
    index += 1
  }
  text[:index].trim().to_owned()
}

///|
fn parse_named_block(
  lines : Array[StringView],
  start : Int32,
  text : String,
  kind : String,
) -> Result[(ApiNamedDeclaration, Int32), String] {
  let rest = declaration_rest(text)
  let keyword = kind + " "
  if !rest.has_prefix(keyword) {
    return Err("missing \{kind} keyword")
  }
  let tail = rest[keyword.length():].trim().to_owned()
  let name = declaration_name(tail)
  if name.is_empty() {
    return Err("\{kind} name is empty")
  }
  let body : Array[String] = []
  let mut depth = 1
  let mut index = start + 1
  while index < lines.length() {
    let line = lines[index].trim().to_owned()
    index += 1
    if line.is_empty() || line.has_prefix("//") {
      continue
    }
    let mut line_depth = depth
    for char in line {
      if char == '{' {
        line_depth += 1
      } else if char == '}' {
        line_depth -= 1
      }
    }
    if line_depth == 0 {
      let signature = "\{kind} \{name} { \{body.join("; ")} }"
      return Ok(({ kind, name, signature, }, index))
    }
    depth = line_depth
    body.push(line)
  }
  Err("unterminated \{kind} \{name}")
}

///|
fn parse_named_line(text : String) -> Result[ApiNamedDeclaration, String] {
  let rest = declaration_rest(text)
  let (kind, keyword) = if rest.has_prefix("type ") {
    ("type_alias", "type ")
  } else if rest.has_prefix("const ") {
    ("const", "const ")
  } else if rest.has_prefix("using ") {
    ("using", "using ")
  } else if rest.has_prefix("impl ") {
    ("impl", "impl ")
  } else {
    return Err("unsupported named declaration")
  }
  let tail = rest[keyword.length():].trim().to_owned()
  if tail.is_empty() {
    return Err("\{kind} declaration is empty")
  }
  let name = if kind == "impl" { tail } else { declaration_name(tail) }
  Ok({ kind, name, signature: rest, })
}

///|
fn is_named_block(text : String, keyword : String) -> Bool {
  let rest = declaration_rest(text)
  rest.has_prefix(keyword + " ") && rest.contains("{")
}

///|
/// Parse a generated `.mbti` interface into a normalized snapshot.
///
/// Known declarations are normalized into stable public models. Unknown public
/// declarations are retained in `unsupported` instead of aborting the parse.
pub fn parse_interface(source : String) -> Result[InterfaceSnapshot, String] {
  let lines = source.split("\n").to_array()
  let mut package_name : String? = None
  let declarations : Array[ApiDeclaration] = []
  let unsupported : Array[UnsupportedDeclaration] = []
  let mut index = 0
  while index < lines.length() {
    let text = lines[index].trim().to_owned()
    let line_number = index + 1
    if text.is_empty() || text.has_prefix("//") {
      index += 1
      continue
    }
    if text.has_prefix("package ") {
      match parse_package_name(text) {
        Some(name) =>
          match package_name {
            None => package_name = Some(name)
            Some(_) =>
              return Err("duplicate package declaration at line \{line_number}")
          }
        None => return Err("invalid package declaration at line \{line_number}")
      }
      index += 1
      continue
    }
    if text.has_prefix("pub fn ") ||
      text.has_prefix("pub(all) fn ") ||
      text.has_prefix("pub(open) fn ") {
      match parse_function(text) {
        Ok(function) => declarations.push(ApiDeclaration::Function(function))
        Err(message) => return Err("line \{line_number}: \{message}")
      }
      index += 1
      continue
    }
    if text.has_prefix("pub struct ") || text.has_prefix("pub(all) struct ") {
      match parse_struct(lines, index, text) {
        Ok((struct_, next_index)) => {
          declarations.push(ApiDeclaration::Struct(struct_))
          index = next_index
        }
        Err(message) => return Err("line \{line_number}: \{message}")
      }
      continue
    }
    if is_named_block(text, "enum") {
      match parse_named_block(lines, index, text, "enum") {
        Ok((declaration, next_index)) => {
          declarations.push(ApiDeclaration::Enum(declaration))
          index = next_index
        }
        Err(message) => return Err("line \{line_number}: \{message}")
      }
      continue
    }
    if is_named_block(text, "trait") {
      match parse_named_block(lines, index, text, "trait") {
        Ok((declaration, next_index)) => {
          declarations.push(ApiDeclaration::Trait(declaration))
          index = next_index
        }
        Err(message) => return Err("line \{line_number}: \{message}")
      }
      continue
    }
    let rest = declaration_rest(text)
    if rest.has_prefix("type ") ||
      rest.has_prefix("const ") ||
      rest.has_prefix("using ") ||
      rest.has_prefix("impl ") {
      match parse_named_line(text) {
        Ok(declaration) =>
          match declaration.kind {
            "type_alias" =>
              declarations.push(ApiDeclaration::TypeAlias(declaration))
            "const" => declarations.push(ApiDeclaration::Const(declaration))
            "impl" => declarations.push(ApiDeclaration::Impl(declaration))
            _ => unsupported.push({ line: line_number, text, })
          }
        Err(message) => return Err("line \{line_number}: \{message}")
      }
      index += 1
      continue
    }
    if text.has_prefix("pub ") || text.has_prefix("pub(") {
      unsupported.push({ line: line_number, text, })
    }
    index += 1
  }
  match package_name {
    None => Err("missing package declaration")
    Some(package_name) => Ok({ package_name, declarations, unsupported, })
  }
}
