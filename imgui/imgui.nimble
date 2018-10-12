# Package

version     = "0.1.0"
author      = "Leonardo Mariscal"
description = "A new awesome nimble package"
license     = "MIT"
srcDir      = "src"
bin         = @["imgui"]


# Dependencies

requires "nim >= 0.19.0"

task bake, "build the generator":
  exec "nim c -r -d:ssl src/imgui.nim"
