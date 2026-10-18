// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "zxw-dev/moonmend"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/zxw-dev/moonmend"

license = "Apache-2.0"

keywords = [ "moonbit", "developer-tools", "api-migration", "semver" ]

preferred_target = "native"

description = "MoonBit API migration and safe upgrade assistant"

import {
  "moonbitlang/x@0.5.5",
  "moonbitlang/async@0.22.5",
}
