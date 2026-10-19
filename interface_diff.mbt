///|
/// A public API change between two interface snapshots.
pub(all) enum DiffChange {
  FunctionAdded(ApiFunction)
  FunctionRemoved(ApiFunction)
  FunctionModified(ApiFunction, ApiFunction)
  FunctionRenamed(String, ApiFunction)
  StructAdded(ApiStruct)
  StructRemoved(ApiStruct)
  StructModified(ApiStruct, ApiStruct)
  StructRenamed(String, ApiStruct)
  NamedAdded(ApiNamedDeclaration)
  NamedRemoved(ApiNamedDeclaration)
  NamedModified(ApiNamedDeclaration, ApiNamedDeclaration)
}

///|
/// Compatibility impact of a public API change.
pub(all) enum CompatibilityLevel {
  Breaking
  NonBreaking
  Unknown
}

///|
/// The deterministic diff between two interface snapshots.
pub(all) struct InterfaceDiff {
  old_package : String
  new_package : String
  changes : Array[DiffChange]
}

///|
fn function_signature_equal(old : ApiFunction, new : ApiFunction) -> Bool {
  if old.return_type != new.return_type ||
    old.parameters.length() != new.parameters.length() {
    return false
  }
  let mut index = 0
  while index < old.parameters.length() {
    let old_parameter = old.parameters[index]
    let new_parameter = new.parameters[index]
    if old_parameter.name != new_parameter.name ||
      old_parameter.type_name != new_parameter.type_name {
      return false
    }
    index += 1
  }
  true
}

///|
fn function_shape_equal(old : ApiFunction, new : ApiFunction) -> Bool {
  if old.return_type != new.return_type ||
    old.parameters.length() != new.parameters.length() {
    return false
  }
  let mut index = 0
  while index < old.parameters.length() {
    if old.parameters[index].type_name != new.parameters[index].type_name {
      return false
    }
    index += 1
  }
  true
}

///|
fn struct_shape_equal(old : ApiStruct, new : ApiStruct) -> Bool {
  if old.fields.length() != new.fields.length() {
    return false
  }
  let mut index = 0
  while index < old.fields.length() {
    if old.fields[index].name != new.fields[index].name ||
      old.fields[index].type_name != new.fields[index].type_name {
      return false
    }
    index += 1
  }
  true
}

///|
fn min_int(a : Int32, b : Int32) -> Int32 {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn edit_distance(left : String, right : String) -> Int32 {
  let mut previous = Array::make(right.length() + 1, 0)
  let mut column = 0
  while column <= right.length() {
    previous[column] = column
    column += 1
  }
  let mut row = 1
  while row <= left.length() {
    let current = Array::make(right.length() + 1, 0)
    current[0] = row
    column = 1
    while column <= right.length() {
      let substitute_cost = if left.get_char(row - 1) ==
        right.get_char(column - 1) {
        0
      } else {
        1
      }
      current[column] = min_int(
        min_int(previous[column] + 1, current[column - 1] + 1),
        previous[column - 1] + substitute_cost,
      )
      column += 1
    }
    previous = current
    row += 1
  }
  previous[right.length()]
}

///|
fn name_similarity_percent(left : String, right : String) -> Int32 {
  let maximum = if left.length() > right.length() {
    left.length()
  } else {
    right.length()
  }
  if maximum == 0 {
    return 100
  }
  100 - edit_distance(left, right) * 100 / maximum
}

///|
fn best_function_rename(
  old : ApiFunction,
  candidates : Array[ApiFunction],
  matched : Array[Bool],
) -> Int32? {
  let mut best = -1
  let mut best_score = -1
  let mut tied = false
  let mut index = 0
  while index < candidates.length() {
    if !matched[index] && function_shape_equal(old, candidates[index]) {
      let score = name_similarity_percent(old.name, candidates[index].name)
      if score >= 50 {
        if score > best_score {
          best = index
          best_score = score
          tied = false
        } else if score == best_score {
          tied = true
        }
      }
    }
    index += 1
  }
  if best >= 0 && !tied {
    Some(best)
  } else {
    None
  }
}

///|
fn best_struct_rename(
  old : ApiStruct,
  candidates : Array[ApiStruct],
  matched : Array[Bool],
) -> Int32? {
  let mut best = -1
  let mut best_score = -1
  let mut tied = false
  let mut index = 0
  while index < candidates.length() {
    if !matched[index] && struct_shape_equal(old, candidates[index]) {
      let score = name_similarity_percent(old.name, candidates[index].name)
      if score >= 50 {
        if score > best_score {
          best = index
          best_score = score
          tied = false
        } else if score == best_score {
          tied = true
        }
      }
    }
    index += 1
  }
  if best >= 0 && !tied {
    Some(best)
  } else {
    None
  }
}

///|
fn collect_functions(
  declarations : Array[ApiDeclaration],
) -> Array[ApiFunction] {
  let functions : Array[ApiFunction] = []
  for declaration in declarations {
    match declaration {
      Function(function) => functions.push(function)
      _ => ()
    }
  }
  functions
}

///|
fn collect_structs(declarations : Array[ApiDeclaration]) -> Array[ApiStruct] {
  let structs : Array[ApiStruct] = []
  for declaration in declarations {
    match declaration {
      Function(_) => ()
      Struct(struct_) => structs.push(struct_)
      _ => ()
    }
  }
  structs
}

///|
fn collect_named_declarations(
  declarations : Array[ApiDeclaration],
) -> Array[ApiNamedDeclaration] {
  let named : Array[ApiNamedDeclaration] = []
  for declaration in declarations {
    match declaration {
      Enum(value)
      | Trait(value)
      | TypeAlias(value)
      | Const(value)
      | Impl(value) => named.push(value)
      Function(_) | Struct(_) => ()
    }
  }
  named
}

///|
fn diff_functions(
  old : Array[ApiFunction],
  new : Array[ApiFunction],
  changes : Array[DiffChange],
) -> Unit {
  let old_matched = Array::make(old.length(), false)
  let new_matched = Array::make(new.length(), false)
  let mut old_index = 0
  while old_index < old.length() {
    let mut new_index = 0
    while new_index < new.length() {
      if !new_matched[new_index] && old[old_index].name == new[new_index].name {
        old_matched[old_index] = true
        new_matched[new_index] = true
        if !function_signature_equal(old[old_index], new[new_index]) {
          changes.push(
            DiffChange::FunctionModified(old[old_index], new[new_index]),
          )
        }
        break
      }
      new_index += 1
    }
    old_index += 1
  }
  old_index = 0
  while old_index < old.length() {
    if !old_matched[old_index] {
      match best_function_rename(old[old_index], new, new_matched) {
        Some(new_index) => {
          old_matched[old_index] = true
          new_matched[new_index] = true
          changes.push(
            DiffChange::FunctionRenamed(old[old_index].name, new[new_index]),
          )
        }
        None => changes.push(DiffChange::FunctionRemoved(old[old_index]))
      }
    }
    old_index += 1
  }
  let mut new_index = 0
  while new_index < new.length() {
    if !new_matched[new_index] {
      changes.push(DiffChange::FunctionAdded(new[new_index]))
    }
    new_index += 1
  }
}

///|
fn diff_structs(
  old : Array[ApiStruct],
  new : Array[ApiStruct],
  changes : Array[DiffChange],
) -> Unit {
  let old_matched = Array::make(old.length(), false)
  let new_matched = Array::make(new.length(), false)
  let mut old_index = 0
  while old_index < old.length() {
    let mut new_index = 0
    while new_index < new.length() {
      if !new_matched[new_index] && old[old_index].name == new[new_index].name {
        old_matched[old_index] = true
        new_matched[new_index] = true
        if !struct_shape_equal(old[old_index], new[new_index]) {
          changes.push(
            DiffChange::StructModified(old[old_index], new[new_index]),
          )
        }
        break
      }
      new_index += 1
    }
    old_index += 1
  }
  old_index = 0
  while old_index < old.length() {
    if !old_matched[old_index] {
      match best_struct_rename(old[old_index], new, new_matched) {
        Some(new_index) => {
          old_matched[old_index] = true
          new_matched[new_index] = true
          changes.push(
            DiffChange::StructRenamed(old[old_index].name, new[new_index]),
          )
        }
        None => changes.push(DiffChange::StructRemoved(old[old_index]))
      }
    }
    old_index += 1
  }
  let mut new_index = 0
  while new_index < new.length() {
    if !new_matched[new_index] {
      changes.push(DiffChange::StructAdded(new[new_index]))
    }
    new_index += 1
  }
}

///|
fn diff_named_declarations(
  old : Array[ApiNamedDeclaration],
  new : Array[ApiNamedDeclaration],
  changes : Array[DiffChange],
) -> Unit {
  let old_matched = Array::make(old.length(), false)
  let new_matched = Array::make(new.length(), false)
  let mut old_index = 0
  while old_index < old.length() {
    let mut new_index = 0
    while new_index < new.length() {
      if !new_matched[new_index] &&
        old[old_index].kind == new[new_index].kind &&
        old[old_index].name == new[new_index].name {
        old_matched[old_index] = true
        new_matched[new_index] = true
        if old[old_index].signature != new[new_index].signature {
          changes.push(
            DiffChange::NamedModified(old[old_index], new[new_index]),
          )
        }
        break
      }
      new_index += 1
    }
    old_index += 1
  }
  old_index = 0
  while old_index < old.length() {
    if !old_matched[old_index] {
      changes.push(DiffChange::NamedRemoved(old[old_index]))
    }
    old_index += 1
  }
  let mut new_index = 0
  while new_index < new.length() {
    if !new_matched[new_index] {
      changes.push(DiffChange::NamedAdded(new[new_index]))
    }
    new_index += 1
  }
}

///|
/// Compare two normalized interface snapshots.
pub fn diff_interfaces(
  old : InterfaceSnapshot,
  new : InterfaceSnapshot,
) -> InterfaceDiff {
  let changes : Array[DiffChange] = []
  diff_functions(
    collect_functions(old.declarations),
    collect_functions(new.declarations),
    changes,
  )
  diff_structs(
    collect_structs(old.declarations),
    collect_structs(new.declarations),
    changes,
  )
  diff_named_declarations(
    collect_named_declarations(old.declarations),
    collect_named_declarations(new.declarations),
    changes,
  )
  { old_package: old.package_name, new_package: new.package_name, changes, }
}

///|
fn parameter_string(parameter : ApiParameter) -> String {
  match parameter.name {
    None => parameter.type_name
    Some(name) => "\{name} : \{parameter.type_name}"
  }
}

///|
pub fn ApiFunction::signature_string(self : ApiFunction) -> String {
  let parameters = self.parameters.map(parameter_string).join(", ")
  "\{self.name}(\{parameters}) -> \{self.return_type}"
}

///|
pub fn ApiStruct::summary_string(self : ApiStruct) -> String {
  let fields = self.fields
    .map(field => "\{field.name} : \{field.type_name}")
    .join(", ")
  "\{self.name} { \{fields} }"
}

///|
pub fn DiffChange::kind(self : DiffChange) -> String {
  match self {
    FunctionAdded(_) => "function_added"
    FunctionRemoved(_) => "function_removed"
    FunctionModified(_, _) => "function_modified"
    FunctionRenamed(_, _) => "function_renamed"
    StructAdded(_) => "struct_added"
    StructRemoved(_) => "struct_removed"
    StructModified(_, _) => "struct_modified"
    StructRenamed(_, _) => "struct_renamed"
    NamedAdded(value) => "\{value.kind}_added"
    NamedRemoved(value) => "\{value.kind}_removed"
    NamedModified(_, _) => "named_declaration_modified"
  }
}

///|
pub fn CompatibilityLevel::name(self : CompatibilityLevel) -> String {
  match self {
    Breaking => "breaking"
    NonBreaking => "non-breaking"
    Unknown => "unknown"
  }
}

///|
pub fn DiffChange::compatibility(self : DiffChange) -> CompatibilityLevel {
  match self {
    FunctionAdded(_) | StructAdded(_) | NamedAdded(_) => NonBreaking
    FunctionRemoved(_)
    | FunctionModified(_, _)
    | FunctionRenamed(_, _)
    | StructRemoved(_)
    | StructModified(_, _)
    | StructRenamed(_, _)
    | NamedRemoved(_)
    | NamedModified(_, _) => Breaking
  }
}

///|
pub fn DiffChange::to_json(self : DiffChange) -> Json {
  match self {
    FunctionAdded(function) =>
      Json::object({
        "kind": Json::string("function_added"),
        "compatibility": Json::string("non-breaking"),
        "function": function.to_json(),
      })
    FunctionRemoved(function) =>
      Json::object({
        "kind": Json::string("function_removed"),
        "compatibility": Json::string("breaking"),
        "function": function.to_json(),
      })
    FunctionModified(old, new) =>
      Json::object({
        "kind": Json::string("function_modified"),
        "compatibility": Json::string("breaking"),
        "old": old.to_json(),
        "new": new.to_json(),
      })
    FunctionRenamed(old_name, function) =>
      Json::object({
        "kind": Json::string("function_renamed"),
        "compatibility": Json::string("breaking"),
        "old_name": Json::string(old_name),
        "new": function.to_json(),
      })
    StructAdded(struct_) =>
      Json::object({
        "kind": Json::string("struct_added"),
        "compatibility": Json::string("non-breaking"),
        "struct": struct_.to_json(),
      })
    StructRemoved(struct_) =>
      Json::object({
        "kind": Json::string("struct_removed"),
        "compatibility": Json::string("breaking"),
        "struct": struct_.to_json(),
      })
    StructModified(old, new) =>
      Json::object({
        "kind": Json::string("struct_modified"),
        "compatibility": Json::string("breaking"),
        "old": old.to_json(),
        "new": new.to_json(),
      })
    StructRenamed(old_name, struct_) =>
      Json::object({
        "kind": Json::string("struct_renamed"),
        "compatibility": Json::string("breaking"),
        "old_name": Json::string(old_name),
        "new": struct_.to_json(),
      })
    NamedAdded(value) =>
      Json::object({
        "kind": Json::string("\{value.kind}_added"),
        "compatibility": Json::string("non-breaking"),
        "declaration": value.to_json(),
      })
    NamedRemoved(value) =>
      Json::object({
        "kind": Json::string("\{value.kind}_removed"),
        "compatibility": Json::string("breaking"),
        "declaration": value.to_json(),
      })
    NamedModified(old, new) =>
      Json::object({
        "kind": Json::string("\{old.kind}_modified"),
        "compatibility": Json::string("breaking"),
        "old": old.to_json(),
        "new": new.to_json(),
      })
  }
}

///|
pub fn DiffChange::to_markdown(self : DiffChange) -> String {
  let description = match self {
    FunctionAdded(function) => "Added function `\{function.signature_string()}`"
    FunctionRemoved(function) =>
      "Removed function `\{function.signature_string()}`"
    FunctionModified(old, new) =>
      "Modified function `\{old.signature_string()}` to `\{new.signature_string()}`"
    FunctionRenamed(old_name, function) =>
      "Renamed function `\{old_name}` to `\{function.signature_string()}`"
    StructAdded(struct_) => "Added struct `\{struct_.summary_string()}`"
    StructRemoved(struct_) => "Removed struct `\{struct_.summary_string()}`"
    StructModified(old, new) =>
      "Modified struct `\{old.summary_string()}` to `\{new.summary_string()}`"
    StructRenamed(old_name, struct_) =>
      "Renamed struct `\{old_name}` to `\{struct_.summary_string()}`"
    NamedAdded(value) => "Added \{value.kind} `\{value.name}`"
    NamedRemoved(value) => "Removed \{value.kind} `\{value.name}`"
    NamedModified(old, new) =>
      "Modified \{old.kind} `\{old.name}` from `\{old.signature}` to `\{new.signature}`"
  }
  "- [\{self.compatibility().name()}] \{description}"
}

///|
fn count_compatibility(
  changes : Array[DiffChange],
  level : CompatibilityLevel,
) -> Int32 {
  changes
  .filter(change => change.compatibility().name() == level.name())
  .length()
}

///|
pub fn InterfaceDiff::breaking_count(self : InterfaceDiff) -> Int32 {
  count_compatibility(self.changes, Breaking)
}

///|
pub fn InterfaceDiff::non_breaking_count(self : InterfaceDiff) -> Int32 {
  count_compatibility(self.changes, NonBreaking)
}

///|
pub fn InterfaceDiff::unknown_count(self : InterfaceDiff) -> Int32 {
  count_compatibility(self.changes, Unknown)
}

///|
pub fn InterfaceDiff::has_breaking_changes(self : InterfaceDiff) -> Bool {
  self.breaking_count() > 0
}

///|
pub fn InterfaceDiff::to_json(self : InterfaceDiff) -> Json {
  Json::object({
    "old_package": Json::string(self.old_package),
    "new_package": Json::string(self.new_package),
    "summary": Json::object({
      "breaking": Json::number(self.breaking_count().to_double()),
      "non_breaking": Json::number(self.non_breaking_count().to_double()),
      "unknown": Json::number(self.unknown_count().to_double()),
      "has_breaking": Json::boolean(self.has_breaking_changes()),
    }),
    "changes": Json::array(self.changes.map(change => change.to_json())),
  })
}

///|
pub fn InterfaceDiff::to_json_string(self : InterfaceDiff) -> String {
  self.to_json().stringify(indent=2)
}

///|
pub fn InterfaceDiff::to_markdown(self : InterfaceDiff) -> String {
  let lines : Array[String] = [
    "# MoonMend Interface Diff",
    "",
    "- Old package: `\{self.old_package}`",
    "- New package: `\{self.new_package}`",
    "- Changes: \{self.changes.length()}",
    "- Breaking changes: \{self.breaking_count()}",
    "- Non-breaking changes: \{self.non_breaking_count()}",
    "- Unknown changes: \{self.unknown_count()}",
    "",
  ]
  if self.changes.is_empty() {
    lines.push("No public API changes detected.")
  } else {
    for change in self.changes {
      lines.push(change.to_markdown())
    }
  }
  lines.join("\n")
}
