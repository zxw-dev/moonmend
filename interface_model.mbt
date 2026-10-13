///|
/// A parameter in a public function signature.
pub(all) struct ApiParameter {
  name : String?
  type_name : String
}

///|
/// A public function in a MoonBit interface snapshot.
pub(all) struct ApiFunction {
  name : String
  parameters : Array[ApiParameter]
  return_type : String
}

///|
/// A field in a public struct.
pub(all) struct ApiField {
  name : String
  type_name : String
}

///|
/// A public struct in a MoonBit interface snapshot.
pub(all) struct ApiStruct {
  name : String
  fields : Array[ApiField]
}

///|
/// A declaration that affects the public API.
pub(all) enum ApiDeclaration {
  Function(ApiFunction)
  Struct(ApiStruct)
}

///|
/// A deterministic, normalized view of one generated `.mbti` file.
pub(all) struct InterfaceSnapshot {
  package_name : String
  declarations : Array[ApiDeclaration]
}

///|
fn optional_string_to_json(value : String?) -> Json {
  match value {
    None => Json::null()
    Some(value) => Json::string(value)
  }
}

///|
pub fn ApiParameter::to_json(self : ApiParameter) -> Json {
  Json::object({
    "name": optional_string_to_json(self.name),
    "type_name": Json::string(self.type_name),
  })
}

///|
pub fn ApiFunction::to_json(self : ApiFunction) -> Json {
  Json::object({
    "name": Json::string(self.name),
    "parameters": Json::array(
      self.parameters.map(parameter => parameter.to_json()),
    ),
    "return_type": Json::string(self.return_type),
  })
}

///|
pub fn ApiField::to_json(self : ApiField) -> Json {
  Json::object({
    "name": Json::string(self.name),
    "type_name": Json::string(self.type_name),
  })
}

///|
pub fn ApiStruct::to_json(self : ApiStruct) -> Json {
  Json::object({
    "name": Json::string(self.name),
    "fields": Json::array(self.fields.map(field => field.to_json())),
  })
}

///|
pub fn ApiDeclaration::to_json(self : ApiDeclaration) -> Json {
  match self {
    Function(function) =>
      Json::object({
        "kind": Json::string("function"),
        "value": function.to_json(),
      })
    Struct(struct_) =>
      Json::object({
        "kind": Json::string("struct"),
        "value": struct_.to_json(),
      })
  }
}

///|
pub fn InterfaceSnapshot::to_json(self : InterfaceSnapshot) -> Json {
  Json::object({
    "package_name": Json::string(self.package_name),
    "declarations": Json::array(
      self.declarations.map(declaration => declaration.to_json()),
    ),
  })
}

///|
pub fn InterfaceSnapshot::to_json_string(self : InterfaceSnapshot) -> String {
  self.to_json().stringify(indent=2)
}
