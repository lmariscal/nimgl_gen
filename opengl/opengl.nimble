# Package

version     = "0.1.0"
author      = "Leonardo Mariscal"
description = "opengl bindings generator"
license     = "MIT"
srcDir      = "src"
bin         = @["opengl"]

# Dependencies

requires "nim >= 0.18.0", "figures"

task bake, "build the generator":
  exec "nim c -r -d:ssl src/opengl.nim"
