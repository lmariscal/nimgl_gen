# Copyright 2018, NimGL contributors.

import os, strutils, streams, json
import unicode

when not isMainModule:
  echo "use nimgl's opengl generator as a cli command."
  quit(-1)

type
  IGEnum = object
    name: string
    value: int32

const
  header = """
# Copyright 2018, NimGL contributors.

## ImGUI Bindings
## ===
## This code was automatically generated by nimgl_gen<https://github.com/lmariscal/nimgl_gen>`_
## with the imgui generator.
##
## This bindings follow most of the original library
## You can check the original documentation `here <https://github.com/ocornut/imgui/blob/master/imgui.cpp>`_.
##
## Do to this library most of the binding libraries are written in C, we want
## to continue supporting only C libraries so you can always use the backend of
## your choice. We are binding `cimgui <https://github.com/Extrawurst/cimgui.git>`_
## which is a thin c wrapper of the c++ version. It is up to date and has great
## support.
##
## NOTE: Unless you want to compile witch cpp please provide a dll of the library,
## made with cimgui.
##
## Even tho we try to keep this bindings the closes to the source, this one specially
## needs some extra work to fully function with glfw, so there are some helper functions
## to help with the proccess
##
## HACK: If you are on windows be sure to compile the cimgui dll with visual studio and
## not with mingw.

when not defined(imguiSrc):
  when defined(windows):
    const imgui_dll* = "cimgui.dll"
  elif defined(macosx):
    const imgui_dll* = "cimgui.dylib"
  else:
    const imgui_dll* = "cimgui.so"
  {.pragma: imgui_lib, dynlib: imgui_dll, cdecl.}
else:
  {.compile: "private/cimgui/imgui/imgui.cpp",
    compile: "private/cimgui/imgui/imgui_draw.cpp",
    compile: "private/cimgui/imgui/imgui_demo.cpp",
    compile: "private/cimgui/imgui/imgui_widgets.cpp",
    compile: "private/cimgui/cimgui/cimgui.cpp".}
  {.pragma: imgui_lib, cdecl.}

"""
  dtypes_header = """
  Pair* = object
    key*: ImGuiID
    val*: int32
  ImVector* = object
    size*: int32
    capacity*: int32
    data*: pointer
  ImDrawListSharedData* = object
  ImGuiContext* = object
  igGLFWwindow* = object
  igSDL_Window* = object
  igSDL_Event* = object
"""

# Enums
# Types
# Structs

proc translateTypes(dtype: string, name: string): tuple[dtype: string, name: string] =
  result.dtype = dtype
  result.name = name
  result.dtype = result.dtype.replace("const ", "")
  result.dtype = result.dtype.replace("const", "")

  if result.dtype == "((void *)0)":
    result.dtype = "nil"

  if result.dtype.find("/*") != -1:
    result.dtype = result.dtype[0..<result.dtype.find("/*")]

  var ptrcount = result.dtype.count('*')
  result.dtype = result.dtype.replace("*", "")
  result.dtype = result.dtype.replace("&", "")

  if result.dtype.contains("[]"):
    ptrcount.inc
    result.dtype = result.dtype.replace("[]", "")

  if result.name == "type":
    result.name = "`type`"
  elif result.name == "ref":
    result.name = "`ref`"
  elif result.name == "ptr":
    result.name = "`ptr`"
  elif result.name == "out":
    result.name = "`out`"
  elif result.name == "in":
    result.name = "`in`"
  elif result.name == "char":
    result.name = "`char`"

  if result.name.startsWith("_"):
    result.name = result.name[1..<result.name.len]

  if result.dtype == "float":
    result.dtype = "float32"
  elif result.dtype == "double":
    result.dtype = "float64"
  elif result.dtype == "int":
    result.dtype = "int32"
  elif result.dtype == "short":
    result.dtype = "int16"
  elif result.dtype == "uint64_t":
    result.dtype = "uint64"
  elif result.dtype == "int64_t":
    result.dtype = "int64"

  elif result.dtype == "signed int":
    result.dtype = "uint32"
  elif result.dtype == "unsigned int":
    result.dtype = "uint32"
  elif result.dtype == "unsigned short":
    result.dtype = "uint16"
  elif result.dtype == "unsigned char":
    result.dtype = "char"
  elif result.dtype == "size_t":
    result.dtype = "uint32"
  elif result.dtype == "NULL":
    result.dtype = "nil"

  if result.dtype.contains("GLFWwindow"):
    result.dtype = "igGLFWwindow"
  elif result.dtype.contains("SDL_Window"):
    result.dtype = "igSDL_Window"
  elif result.dtype.contains("SDL_Event"):
    result.dtype = "igSDL_Event"

  if result.dtype.startsWith("ImVector"):
    result.dtype = "ImVector"
  if result.dtype == "FLT_MAX":
    result.dtype = "high(float32)"

  if result.dtype.startsWith("char()"):
    return ("proc(user_data: pointer): cstring {.cdecl.}", name)
  elif result.dtype.startsWith("void()(void user_data"):
    return ("proc(user_data: pointer, text: cstring): void {.cdecl.}", name)
  elif result.dtype.startsWith("void()(int x"):
    return ("proc(x: int32, y: int32): void {.cdecl.}", name)
  elif result.dtype.startsWith("void()(ImGuiSizeCallbackData data)"):
    return ("proc(data: ptr ImGuiSizeCallbackData): void {.cdecl.}", name)
  elif result.dtype.startsWith("int()(ImGuiInputTextCallbackData data)"):
    return ("proc(data: ptr ImGuiInputTextCallbackData): int32 {.cdecl.}", name)
  elif result.dtype.startsWith("void()(ImDrawList parent_list,ImDrawCmd cmd)"):
    return ("proc(parent_list: ptr ImDrawList, cmd: ptr ImDrawCmd): void {.cdecl.}", name)

  for i in 0 ..< ptrcount:
    result.dtype = "ptr " & result.dtype

  if result.dtype == "ptr char":
    result.dtype = "cstring"
  elif result.dtype == "ptr void":
    result.dtype = "pointer"

  if result.name.find("[") != -1:
    var num = result.name[result.name.find("[") + 1 ..< result.name.find("]")]
    result.dtype = "array[" & num & ", " & result.dtype & "]"
    result.name = result.name[0..<result.name.find("[")]
  elif result.dtype.find("[") != -1:
    var num = result.dtype[result.dtype.find("[") + 1 ..< result.dtype.find("]")]
    result.dtype = "ptr " & result.dtype[0..<result.dtype.find("[")]

  if result.dtype.endsWith(" "):
    result.dtype = result.dtype[0 ..< result.dtype.len - 1]
  result.dtype = result.dtype.replace("ptr void", "pointer")

proc getConstants(node: JsonNode): string =
  result = "const\n"
  for name, obj in node["enums"].pairs:
    if obj.len < 0: continue
    for data in obj:
      var dname = data["name"].getStr()
      if dname.endsWith("_"):
        dname = dname[0 ..< dname.len - 1]
      dname = dname.replace("__", "_")
      result.add("  " & dname & "* = " & $data["calc_value"].getInt().int32 & "\n")

proc getTypes(node: JsonNode): string =
  result = "\ntype\n"
  for name, obj in node:
    if obj.getStr().startsWith("struct "): continue
    let dtype = obj.getStr().translateTypes(name).dtype
    if dtype.contains("value_type") or name.contains("value_type"): continue
    result.add("  " & name & "* = " & dtype & "\n")

proc getStructs(node: JsonNode): string =
  result = "\n" & dtypes_header
  for name, obj in node["structs"].pairs:
    if name == "ImVector": continue
    if name == "Pair": continue
    result.add("  " & name & "* = object\n")
    if obj.len < 0: continue
    for data in obj:
      var (dtype, name) = data["type"].getStr().translateTypes(data["name"].getStr())

      if name.startsWith("_"):
        name = name[1..<name.len]
      if name == "}": continue
      name[0] = name[0].toLowerAscii

      result.add("    ")
      result.add(name & "*: ")
      result.add(dtype & "\n")

proc getDefinitions(node: JsonNode, impls: bool = false): string =
  result = "\n"
  var vararg = false
  for name, obj in node:
    if name == "igSetAllocatorFunctions": continue # need to add all the functions
    var pname = name
    if pname.startsWith("Im") and pname.contains("_"):
      pname = pname[pname.find("_") + 1 ..< pname.len]
      if pname.startsWith("Im") and not impls:
        pname = "new" & pname
    pname[0] = pname[0].toLowerAscii()
    if pname == "end":
      pname = "igEnd"
    result.add("proc " & pname & "*(")
    var args = false
    var argCount = 0

    for data in obj[0]["argsT"]:
      argCount.inc
      args = true
      let tipe = translateTypes(data["type"].getStr(), data["name"].getStr())
      if tipe.name == "...":
        vararg = true
        continue
      elif tipe.dtype == "va_list":
        vararg = true
        continue
      result.add(tipe.name & ": " & tipe.dtype)
      if obj[0]["defaults"].kind == JObject and obj[0]["defaults"].hasKey(tipe.name):
        var defVal = translateTypes(obj[0]["defaults"][tipe.name].getStr(), "").dtype
        if defVal.contains("("):
          result.add(", ")
        else:
          if defVal == "0xFFFFFFFF":
            defVal = "0xFFFFFFF"
          result.add(" = " & defVal & ", ")
      else:
        result.add(", ")
    if args:
      result = result[0 ..< result.len - 2]

    var ret = "void"
    if obj[0].hasKey("ret"):
      ret = translateTypes(obj[0]["ret"].getStr(), "").dtype
    result.add("): " & ret & " {.imgui_lib, importc: \"" & obj[0]["cimguiname"].getStr())
    if not vararg or argCount == 0:
      result.add("\".}\n")
    else:
      result.add("\", varargs.}\n")

proc main() =

  let structs_and_enums = readFile("structs_and_enums.json")
  let typedefs          = readFile("typedefs_dict.json")
  let definitions       = readFile("definitions.json")
  let impl_definitions  = readFile("impl_definitions.json")
  let json_td   = parseJson(typedefs)
  let json_sne  = parseJson(structs_and_enums)
  let json_defs = parseJson(definitions)
  let json_impl_defs = parseJson(impl_definitions)
  var out_data = ""
  out_data.add(header)
  out_data.add(getConstants(json_sne))
  out_data.add(getTypes(json_td))
  out_data.add(getStructs(json_sne))
  out_data.add(getDefinitions(json_defs))
  # out_data.add("\n# Implementations @TODO Make our own\n")
  # out_data.add(getDefinitions(json_impl_defs, true))
  writeFile("imgui.nim", out_data)

main()
