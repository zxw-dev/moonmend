///|
/// How a migration action should be handled.
pub(all) enum MigrationStrategy {
  Automatic
  Manual
  Informational
}

///|
/// One action in a migration plan.
pub(all) struct MigrationAction {
  strategy : MigrationStrategy
  kind : String
  target : String
  before : String?
  after : String?
  description : String
}

///|
/// A dry-run migration plan derived from an interface diff.
pub(all) struct MigrationPlan {
  old_package : String
  new_package : String
  actions : Array[MigrationAction]
}

///|
pub fn MigrationStrategy::name(self : MigrationStrategy) -> String {
  match self {
    Automatic => "automatic"
    Manual => "manual"
    Informational => "informational"
  }
}

///|
fn optional_string_json(value : String?) -> Json {
  match value {
    None => Json::null()
    Some(value) => Json::string(value)
  }
}

///|
pub fn MigrationAction::to_json(self : MigrationAction) -> Json {
  Json::object({
    "strategy": Json::string(self.strategy.name()),
    "kind": Json::string(self.kind),
    "target": Json::string(self.target),
    "before": optional_string_json(self.before),
    "after": optional_string_json(self.after),
    "description": Json::string(self.description),
  })
}

///|
fn action_from_change(change : DiffChange) -> MigrationAction {
  match change {
    FunctionRenamed(old_name, function) =>
      {
        strategy: Automatic,
        kind: "rename_function",
        target: function.name,
        before: Some(old_name),
        after: Some(function.name),
        description: "Replace calls to function \{old_name} with \{function.name}.",
      }
    StructRenamed(old_name, struct_) =>
      {
        strategy: Automatic,
        kind: "rename_struct",
        target: struct_.name,
        before: Some(old_name),
        after: Some(struct_.name),
        description: "Replace references to struct \{old_name} with \{struct_.name}.",
      }
    FunctionModified(old, new) =>
      {
        strategy: Manual,
        kind: "review_function_signature",
        target: new.name,
        before: Some(old.signature_string()),
        after: Some(new.signature_string()),
        description: "Review the changed function signature and update call sites manually.",
      }
    StructModified(old, new) =>
      {
        strategy: Manual,
        kind: "review_struct_shape",
        target: new.name,
        before: Some(old.summary_string()),
        after: Some(new.summary_string()),
        description: "Review changed fields and update constructors or field access manually.",
      }
    FunctionRemoved(function) =>
      {
        strategy: Manual,
        kind: "review_removed_function",
        target: function.name,
        before: Some(function.signature_string()),
        after: None,
        description: "The function was removed; replace or redesign affected call sites.",
      }
    StructRemoved(struct_) =>
      {
        strategy: Manual,
        kind: "review_removed_struct",
        target: struct_.name,
        before: Some(struct_.summary_string()),
        after: None,
        description: "The struct was removed; replace affected type uses manually.",
      }
    FunctionAdded(function) =>
      {
        strategy: Informational,
        kind: "new_function",
        target: function.name,
        before: None,
        after: Some(function.signature_string()),
        description: "A new function is available; no migration is required.",
      }
    StructAdded(struct_) =>
      {
        strategy: Informational,
        kind: "new_struct",
        target: struct_.name,
        before: None,
        after: Some(struct_.summary_string()),
        description: "A new struct is available; no migration is required.",
      }
  }
}

///|
/// Convert an interface diff into a deterministic dry-run plan.
pub fn plan_migration(diff : InterfaceDiff) -> MigrationPlan {
  {
    old_package: diff.old_package,
    new_package: diff.new_package,
    actions: diff.changes.map(action_from_change),
  }
}

///|
pub fn MigrationPlan::to_json(self : MigrationPlan) -> Json {
  Json::object({
    "old_package": Json::string(self.old_package),
    "new_package": Json::string(self.new_package),
    "actions": Json::array(self.actions.map(action => action.to_json())),
  })
}

///|
pub fn MigrationPlan::to_json_string(self : MigrationPlan) -> String {
  self.to_json().stringify(indent=2)
}

///|
fn append_strategy_actions(
  lines : Array[String],
  plan : MigrationPlan,
  strategy : MigrationStrategy,
) -> Unit {
  let actions = plan.actions.filter(action => {
    action.strategy.name() == strategy.name()
  })
  lines.push("## \{strategy.name()} (\{actions.length()})")
  lines.push("")
  if actions.is_empty() {
    lines.push("- None")
  } else {
    for action in actions {
      lines.push("- `\{action.kind}` `\{action.target}`: \{action.description}")
    }
  }
  lines.push("")
}

///|
pub fn MigrationPlan::to_markdown(self : MigrationPlan) -> String {
  let lines : Array[String] = [
    "# MoonMend Migration Plan",
    "",
    "- Old package: `\{self.old_package}`",
    "- New package: `\{self.new_package}`",
    "- Actions: \{self.actions.length()}",
    "",
  ]
  append_strategy_actions(lines, self, Automatic)
  append_strategy_actions(lines, self, Manual)
  append_strategy_actions(lines, self, Informational)
  lines.join("\n")
}

///|
/// Render a review-only unified diff preview for automatic actions.
///
/// Applying the preview requires a later migration step that resolves source
/// locations and verifies the result.
pub fn MigrationPlan::to_unified_diff(self : MigrationPlan) -> String {
  let actions = self.actions.filter(action => {
    action.strategy.name() == "automatic" &&
    action.before is Some(_) &&
    action.after is Some(_)
  })
  if actions.is_empty() {
    return "# No automatic changes to preview."
  }
  let lines : Array[String] = ["--- a/**/*.mbt", "+++ b/**/*.mbt"]
  for action in actions {
    let before = match action.before {
      Some(value) => value
      None => continue
    }
    let after = match action.after {
      Some(value) => value
      None => continue
    }
    lines.push("@@ \{action.kind}: \{action.target} @@")
    lines.push("-\{before}")
    lines.push("+\{after}")
  }
  lines.join("\n")
}
