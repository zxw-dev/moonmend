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
