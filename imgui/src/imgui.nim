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
##
## This code was automatically generated by nimgl_gen<https://github.com/lmariscal/nimgl_gen>`_
## with the imgui generator.

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
    compile: "private/cimgui/cimgui/cimgui_auto.cpp".}
  {.pragma: imgui_lib, cdecl.}

"""
  dtypes_header = """
  Pair* = object
    key*: ImGuiID
    val*: int32
  ImDrawListSharedData* = object
"""

# Enums
# Types
# Structs

proc translateTypes(dtype: string, name: string): tuple[dtype: string, name: string] =
  result.dtype = dtype
  result.name = name
  result.dtype = result.dtype.replace("const ", "")
  result.dtype = result.dtype.replace("const", "")

  if result.dtype.find("/*") != -1:
    result.dtype = result.dtype[0..<result.dtype.find("/*")]

  var ptrcount = result.dtype.count('*')
  result.dtype = result.dtype.replace("*", "")

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

proc getConstants(node: JsonNode): string =
  result = "const\n"
  for name, obj in node["enums"].pairs:
    if obj.len < 0: continue
    for data in obj:
      var dname = data["name"].getStr()
      if dname.endsWith("_"):
        dname = dname[0 ..< dname.len - 1]
      dname = dname.replace("__", "_")
      result.add("  " & dname & " = " & $data["calc_value"].getInt().int32 & "\n")

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

proc main() =
  let structs_and_enums = readFile("structs_and_enums.json")
  let typedefs = readFile("typedefs_dict.json")
  let json_td = parseJson(typedefs)
  let json_sne = parseJson(structs_and_enums)
  var out_data = ""
  out_data.add(header)
  out_data.add(getConstants(json_sne))
  out_data.add(getTypes(json_td))
  out_data.add(getStructs(json_sne))
  writeFile("imgui.nim", out_data)

main()