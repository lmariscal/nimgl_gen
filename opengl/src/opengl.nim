# Copyright 2018, NimGL contributors.

import os, strutils, httpclient, streams, xmlparser, xmltree, tables

# TODO: extensions hehe

when not isMainModule:
  echo "use nimgl's opengl generator as a cli command."
  quit(-1)

type
  Argument = tuple[ptype: string, name: string]
  EnumVal = object
    name: string
    val: string
    comment: string
  Command = object
    rtn: string
    name: string
    arguments: seq[Argument]

const
  header = """
# Copyright 2018, NimGL contributors.

import nimgl/glfw # used to get the glfwGetProcAddress procedure
import strutils

## OpenGL Bindings
## ===
##
## This code was automatically generated by nimgl_gen<https://github.com/lmariscal/nimgl_gen>`_
## with the opengl generator.
##
## NimGL is completely unaffiliated with OpenGL and Khronos, each Doc is under individual copyright
## you can find it in their appropiate file in the official repo<https://github.com/KhronosGroup/OpenGL-Refpages>`_
##
## NOTE: This bindings only support modern opengl (v3.2 >=) so fixed pipelines are not
## supported.

type
  GLvoid* = pointer
  GLeglImageOES* = distinct pointer
  GLsync* = distinct pointer
  ClContext* = distinct pointer
  ClEvent* = distinct pointer
  GLeglClientBufferEXT* = distinct pointer
  GLbyte* = int8
  GLshort* = int16
  GLintptr* = int
  GLintptrARB* = int
  GLsizeiptr* = int
  GLsizeiptrARB* = int
  GLclampx* = int32
  GLfixed* = int32
  GLint* = int32
  GLsizei* = int32
  GLvdpauSurfaceNV* = int32
  GLint64* = int64
  GLint64EXT* = int64
  GLubyte* = uint8
  GLhalf* = uint16
  GLhalfARB* = uint16
  GLhalfNV* = uint16
  GLushort* = uint16
  GLbitfield* = uint32
  GLhandleARB* = uint32
  GLenum* = uint32
  GLuint* = uint32
  GLuint64* = uint64
  GLuint64EXT* = uint64
  GLboolean* = bool
  GLchar* = char
  GLcharARB* = byte
  GLclampf* = float32
  GLfloat* = float32
  GLclampd* = float64
  GLdouble* = float64
  GLDEBUGPROC* = proc(source: GLenum, `type`: GLenum, id: GLuint, severity: GLenum, length: GLsizei, message: cstring, userParam: pointer): void {.cdecl.}
  GLDEBUGPROCARB* = GLDEBUGPROC
  GLDEBUGPROCKHR* = GLDEBUGPROC
  GLDEBUGPROCAMD* = GLDEBUGPROC
  GLVULKANPROCNV* = proc(): void {.cdecl.}
  GLPROCLOADERPROC* = proc(name: cstring): pointer {.cdecl.}

var
  glVersionMajor*: int
  glVersionMinor*: int

# Constants
const
  GL_INVALID_INDEX*: uint32 = uint32(0xFFFFFFFF)
  GL_TIMEOUT_IGNORED*: uint64 = uint64(0xFFFFFFFFFFFFFFFF)
  GL_TIMEOUT_IGNORED_APPLE*: uint64 = uint64(0xFFFFFFFFFFFFFFFF)
"""
  loader = """

proc glGetProcAddress(name: cstring): pointer =
  ## Gets a pointer to the procedure
  ## If `release` is not defined it will check that the address has been found.
  cglGetProcAddress(name)
  """
  footer = """

proc glInit*(loader: GLPROCLOADERPROC = getProcAddress): bool =
  ## Gets the opengl version that is supported and loads the proper functions
  cglGetProcAddress = loader

  cglGetString = cast[proc (name: GLenum): ptr GLubyte {.cdecl.}](cglGetProcAddress("glGetString"))
  if cglGetProcAddress == nil: return false

  var glVersion = cast[cstring](glGetString(GL_VERSION))
  if glVersion.isNil: return false

  # Thanks to David Herberth who made this version verifier
  var prefixes = ["OpenGL ES-CM ", "OpenGL ES-CL ", "OpenGL ES "]

  var version: string = $glVersion
  for p in prefixes:
    if version.startsWith(p):
      version = version.replace(p)
      break

  var major = ord(glVersion[0]) - ord('0')
  var minor = ord(glVersion[2]) - ord('0')

  glVersionMajor = major
  glVersionMinor = minor

  if (major == 1 and minor >= 0) or major > 1: load1_0()
  if (major == 1 and minor >= 1) or major > 1: load1_1()
  if (major == 1 and minor >= 2) or major > 1: load1_2()
  if (major == 1 and minor >= 3) or major > 1: load1_3()
  if (major == 1 and minor >= 4) or major > 1: load1_4()
  if (major == 1 and minor >= 5) or major > 1: load1_5()
  if (major == 2 and minor >= 0) or major > 2: load2_0()
  if (major == 2 and minor >= 1) or major > 2: load2_1()
  if (major == 3 and minor >= 0) or major > 3: load3_0()
  if (major == 3 and minor >= 1) or major > 3: load3_1()
  if (major == 3 and minor >= 2) or major > 3: load3_2()
  if (major == 3 and minor >= 3) or major > 3: load3_3()
  if (major == 4 and minor >= 0) or major > 4: load4_0()
  if (major == 4 and minor >= 1) or major > 4: load4_1()
  if (major == 4 and minor >= 2) or major > 4: load4_2()
  if (major == 4 and minor >= 3) or major > 4: load4_3()
  if (major == 4 and minor >= 4) or major > 4: load4_4()
  if (major == 4 and minor >= 5) or major > 4: load4_5()
  if (major == 4 and minor >= 6) or major > 4: load4_6()
  return true
"""
  keywords = ["addr", "and", "as", "asm", "bind", "block", "break", "case", "cast", "concept", "const", "continue",
              "converter", "defer", "discard", "distinct", "div", "do", "elif", "else", "end", "enum", "except",
              "export", "finally", "for", "from", "func", "if", "import", "in", "include", "interface", "is", "isnot",
              "iterator", "let", "macro", "method", "mixin", "mod", "nil", "not", "notin", "object", "of", "or", "out",
              "proc", "ptr", "raise", "ref", "return", "shl", "shr", "static", "template", "try", "tuple", "type",
              "using", "var", "when", "while", "xor", "yield"]
  usedConstants = ["GL_BYTE", "GL_SHORT", "GL_INT", "GL_FLOAT", "GL_DOUBLE", "GL_FIXED"]
  bannedConstants = ["GL_INVALID_INDEX", "GL_TIMEOUT_IGNORED", "GL_TIMEOUT_IGNORED_APPLE", "GL_ACTIVE_PROGRAM_EXT", "GL_NEXT_BUFFER_NV", "GL_SKIP_COMPONENTS4_NV", "GL_SKIP_COMPONENTS3_NV", "GL_SKIP_COMPONENTS2_NV", "GL_SKIP_COMPONENTS1_NV"]
  banned = ["glCreateSyncFromCLeventARB", "glGetTransformFeedbacki_v"]

var
  enums: seq[EnumVal] = @[]
  commands: seq[Command] = @[]
  loaded: seq[string] = @[]
  toload: seq[string] = @[]
  docaliases = {
    "glClearNamedFramebuffer": "glClearBuffer",
    "glClearFramebuffer": "glClearBuffer",
    "glDisable": "glEnable",
    "glDisableVertexArrayAttrib": "glEnableVertexAttribArray",
    "glDisableVertexAttribArray": "glEnableVertexAttribArray",
    "glEnableVertexArrayAttrib": "glEnableVertexAttribArray",
    "glVertexAttr": "glVertexAttribPointer",
    "glGenerateTextureMipmap": "glGenerateMipmap",
    "glFramebufferTexture1D": "glFramebufferTexture",
    "glFramebufferTexture3D": "glFramebufferTexture",
    "glGetBoolean": "glGet",
    "glGetDouble": "glGet",
    "glGetFixed": "glGet",
    "glGetFloat": "glGet",
    "glGetInteger64": "glGet",
    "glGetInteger": "glGet",
    "glNamedFramebufferTexture": "glFramebufferTexture",
    "glNamedFramebufferTextureLayer": "glFramebufferTextureLayer",
    "glReadnPixels": "glReadPixels",
    "glPolygonOffsetClamp": "glPolygonOffset",
    "glVertexArrayVertexBuffer": "glBindVertexBuffer",
    "glVertexArrayVertexBuffers": "glBindVertexBuffer"
  }.toTable()

  docCustom = {
    "glGetQueryBufferObject": "Missing: https://github.com/KhronosGroup/OpenGL-Refpages/issues/10",
    "glSpecializeShader": """Specializing a SPIR-V shader is analogous to compiling a GLSL shader. So if this function completes successfully, the shader object's compile status is GL_TRUE. If specialization fails, then the shader infolog has information explaining why and an OpenGL Error is generated.
  ## pEntryPoint​ must name a valid entry point. Also, the entry point's "execution model" (SPIR-V speak for "Shader Stage") must match the stage the shader object was created with. Specialization can also fail if pConstantIndex​ references a specialization constant index that the SPIR-V binary does not use. If specialization fails, the shader's info log is updated appropriately.
  ## Once specialized, SPIR-V shaders cannot be re-specialized. However, you can reload the SPIR-V binary data into them, which will allow them to be specialized again."""
  }.toTable()

  load1_0: seq[string] = @[]
  load1_1: seq[string] = @[]
  load1_2: seq[string] = @[]
  load1_3: seq[string] = @[]
  load1_4: seq[string] = @[]
  load1_5: seq[string] = @[]
  load2_0: seq[string] = @[]
  load2_1: seq[string] = @[]
  load3_0: seq[string] = @[]
  load3_1: seq[string] = @[]

  load3_2: seq[string] = @[]
  load3_3: seq[string] = @[]
  load4_0: seq[string] = @[]
  load4_1: seq[string] = @[]
  load4_2: seq[string] = @[]
  load4_3: seq[string] = @[]
  load4_4: seq[string] = @[]
  load4_5: seq[string] = @[]
  load4_6: seq[string] = @[]

  noRefPages: bool = false

proc getRegistry() =
  ## downloads the xml opengl registry
  let client  = newHttpClient()
  client.downloadFile("https://raw.githubusercontent.com/KhronosGroup/OpenGL-Registry/master/xml/gl.xml", "gl.xml")

proc newCommand(): Command =
  result.name      = ""
  result.rtn       = ""
  result.arguments = @[]

proc toProcVar(cmd: Command): string =
  result = "  c" & cmd.name & ": proc ("
  for i in cmd.arguments:
    result.add(i.name & ": " & i.ptype & ", ")
  if cmd.arguments.len > 0:
    result = result.substr(0, result.len - 3)
  result.add("): " & cmd.rtn & " {.cdecl.}\n")

proc transKeys(cmd: string): string =
  result = cmd
  result = result.replace("const ", "")
  result = result.replace("const", "")
  result = result.replace(" *", "*")
  result = result.replace("void*", "pointer")
  result = result.replace("GLchar*", "cstring")

  if result.contains('*'):
    let levels = result.count('*')
    result = result.replace("*", "")
    for i in 0..<levels:
      result = "ptr " & result

proc getCmd(name: string): (Command, bool) =
  for c in commands:
    if c.name == name:
      return (c, true)
  return (commands[0], false)

proc genLoader(load: seq[string], version: string): string =
  result = "\nproc load" & version & "() =\n"
  for name in load:
    let (cmd, state) = getCmd(name)
    if not state or loaded.contains(name): continue
    result.add("  c" & cmd.name & " = cast[")
    result.add("proc (")
    for i in cmd.arguments:
      result.add(i.name & ": " & i.ptype & ", ")
    if cmd.arguments.len > 0:
      result = result.substr(0, result.len - 3)
    result.add("): " & cmd.rtn & " {.cdecl.}](glGetProcAddress(\"" & cmd.name & "\"))\n")
    loaded.add(name)

let
  docOneLetter = ["x", "i", "f", "u", "v", "L", "P", "1", "2", "3", "4", "d"]
  docTwoLetter = ["fv", "iv", "2f", "4x", "4i", "1i", "3s", "4s", "4N", "ub", "2s", "1s"]
  docThreeLetter = ["4sv", "2dv", "P3u", "P4u", "4ub", "2fv", "4bv", "4iv", "4ui", "3dv", "3fv", "4dv", "4fv", "1ui",
                    "L1d", "i_v", "usv", "Sub", "4Ns"]
  docFourLetter = ["i64v", "4uiv", "L1dv", "64iv", "Data", "4Niv", "4Nbv"]
  docFiveLetter = ["4x2dv", "4x2fv", "2x3dv", "2x3fv", "2x4dv", "2x4fv", "3x2dv", "3x2fv", "3x4dv", "3x4fv", "i64_v",
                   "Count"]

proc getDoc(name: string, original: string, times: int): string =
  result = ""
  if noRefPages: return
  if not os.dirExists("refpages"):
    noRefPages = true
    return

  var path = ""
  if os.fileExists("refpages/gl2.1/" & name & ".xml"): path = "refpages/gl2.1/" & name & ".xml"
  elif os.fileExists("refpages/gl4/" & name & ".xml"): path = "refpages/gl4/" & name & ".xml"
  elif os.fileExists("refpages/es3.1/" & name & ".xml"): path = "refpages/es3.1/" & name & ".xml"
  elif os.fileExists("refpages/es3.0/" & name & ".xml"): path = "refpages/es3.0/" & name & ".xml"
  elif os.fileExists("refpages/es3/" & name & ".xml"): path = "refpages/es3/" & name & ".xml"
  elif os.fileExists("refpages/es2.0/" & name & ".xml"): path = "refpages/es2.0/" & name & ".xml"
  elif os.fileExists("refpages/es1.1/" & name & ".xml"): path = "refpages/es1.1/" & name & ".xml"
  if path == "":
    if times >= 4:
      echo "got stuck: " & name & " <- " & original
      quit(0)
    if docCustom.contains(name):
      return "  ## " & docCustom[name] & "\n"
    elif docAliases.contains(name):
      return getDoc(docAliases[name], "alias | " & original, times + 1)
    else:
      if name.contains("End"):
        return getDoc(name.replace("End", "Begin"), original, times + 1)
      elif name.contains("Getn"):
        return getDoc(name.replace("Getn", "Get"), original, times + 1)
      elif name.contains("ByRegion"):
        return getDoc(name.replace("ByRegion", ""), original, times + 1)
      elif name.endsWith("Matrix"):
        return getDoc(name.replace("Matrix", ""), original, times + 1)
      elif name.contains("Texture"):
        return getDoc(name.replace("Texture", "Tex"), original, times + 1)
      elif name.contains("Named"):
        return getDoc(name.replace("Named", ""), original, times + 1)
      elif name.endsWith("SubData"):
        return getDoc(name.replace("SubData", ""), original, times + 1)
      elif name.endsWith("Data"):
        return getDoc(name.replace("Data", ""), original, times + 1)
      elif name.contains("Framebuffer"):
        return getDoc(name.replace("Framebuffer", ""), original, times + 1)

      for l in docFiveLetter:
        if name.endsWith(l):
          return getDoc(name.substr(0, name.len - 6), original, times + 1)
      for l in docFourLetter:
        if name.endsWith(l):
          return getDoc(name.substr(0, name.len - 5), original, times + 1)
      for l in docThreeLetter:
        if name.endsWith(l):
          return getDoc(name.substr(0, name.len - 4), original, times + 1)
      for l in docTwoLetter:
        if name.endsWith(l):
          return getDoc(name.substr(0, name.len - 3), original, times + 1)
      for l in docOneLetter:
        if name.endsWith(l):
          return getDoc(name.substr(0, name.len - 2), original, times + 1)

      if name.contains("I"):
        return getDoc(name.replace("I", ""), original, times + 1)
      elif name.contains("L"):
        return getDoc(name.replace("L", ""), original, times + 1)
      elif name.contains("Array"):
        return getDoc(name.replace("Array", ""), original, times + 1)

      return "  # TODO T_T <- " & name & "\n"
      # echo name & " <- " & original
      # quit 0

  let file = newFileStream(path, fmRead)
  let xml  = file.parseXml()

  result.add("## ")
  let refpurpose = xml.child("refnamediv").child("refpurpose")
  result.add(refpurpose.innerText().capitalizeAscii())
  result.add("\n")

  let refsect = xml.child("refsect1")
  let varlist = refsect.child("variablelist")
  if varlist == nil:
    let para = refsect.child("para")
    result.add(para.innerText())
  else:
    let para = varlist.child("varlistentry").child("listitem").child("para")
    result.add(para.innerText())

  result = result.replace("\t", "")
  var lines = result.split("\n")
  for i in 0..<lines.len:
    lines[i] = lines[i].strip()
  discard lines.pop()
  result = lines.join("\n")
  result = result.replace("\n", "\n## ")
  result = result.indent(2, " ")
  result.add("\n")

proc main() =
  if not fileExists("gl.xml"):
    getRegistry()

  var
    file = newFileStream("gl.xml", fmRead)
    outCode = ""

  outCode.add(header)

  let xml = file.parseXml()

  # opengl procedures
  for i in xml.findAll("command"):
    var cmd  = newCommand()

    # proc name
    if i.child("proto") == nil: continue
    cmd.name = i.child("proto").child("name").innerText
    # return value
    cmd.rtn  = i.child("proto").innerText
    cmd.rtn  = cmd.rtn.substr(0, cmd.rtn.len - cmd.name.len - 1)
    if cmd.rtn.endsWith(" "):
      cmd.rtn = cmd.rtn.substr(0, cmd.rtn.len - 2)
    cmd.rtn = transKeys(cmd.rtn)

    # params
    for p in i.findAll("param"):
      var arg: Argument
      arg.name  = p.child("name").innerText
      arg.ptype = p.innerText
      arg.ptype = arg.ptype.substr(0, arg.ptype.len - arg.name.len - 1)

      if arg.ptype.endsWith(" "):
        arg.ptype = arg.ptype.substr(0, arg.ptype.len - 2)

      var usingKeyword = false
      for p in arg.name.split(" "):
        if keywords.contains(p): usingKeyword = true

      if usingKeyword:
        var word = ""
        for i in 0..<keywords.len:
          if arg.name.contains(keywords[i]):
            word = keywords[i]
            break
        arg.name = arg.name.replace(word, '`' & word & '`')

      arg.ptype = transKeys(arg.ptype)
      cmd.arguments.add(arg)

    # add it
    if not banned.contains(cmd.name) and not commands.contains(cmd):
      commands.add(cmd)

  # opengl consts
  for e in xml.findAll("enums"):
    for i in e.findAll("enum"):
      if i.attr("name") == "" or i.attr("value") == "" or bannedConstants.contains(i.attr("name")): continue

      var enumv: EnumVal
      enumv.name = i.attr("name")
      if usedConstants.contains(enumv.name):
        enumv.name = "E" & enumv.name
      enumv.val = i.attr("value")

      if i.attr("comment") == "": enumv.comment = ""
      else: enumv.comment = " ## " & i.attr("comment")
      enums.add(enumv)

  # separate the commands to its version
  for f in xml.findAll("feature"):
    let number = f.attr("number").parseFloat
    var current: ptr seq[string]
    if   number == 1.0: current = load1_0.addr
    elif number == 1.1: current = load1_1.addr
    elif number == 1.2: current = load1_2.addr
    elif number == 1.3: current = load1_3.addr
    elif number == 1.4: current = load1_4.addr
    elif number == 1.5: current = load1_5.addr
    elif number == 2.0: current = load2_0.addr
    elif number == 2.1: current = load2_1.addr
    elif number == 3.0: current = load3_0.addr
    elif number == 3.1: current = load3_1.addr

    elif number == 3.2: current = load3_2.addr
    elif number == 3.3: current = load3_3.addr
    elif number == 4.0: current = load4_0.addr
    elif number == 4.1: current = load4_1.addr
    elif number == 4.2: current = load4_2.addr
    elif number == 4.3: current = load4_3.addr
    elif number == 4.4: current = load4_4.addr
    elif number == 4.5: current = load4_5.addr
    elif number == 4.6: current = load4_6.addr

    for req in f.findAll("require"):
      for c in req.findAll("command"):
        current[].add(c.attr("name"))
        toload.add(c.attr("name"))

    # remove compatibility mode
    if number == 3.2:
      for r in f.findAll("remove"):
        for c in r.findAll("command"):
          for i in 0 ..< commands.len - 1:
            if commands[i].name == c.attr("name"):
              commands.del(i)
        for e in r.findAll("enum"):
          for i in 0 ..< enums.len - 1:
            if enums[i].name == e.attr("name"):
              enums.del(i)

  # add enums/constants
  for e in enums:
    outCode.add("  " & e.name & "*: GLenum = GLenum(" & e.val & ")" & e.comment & "\n")

  # make the pointers to procedures
  outCode.add("\n\n# Loaded Procedures\nvar\n")
  for cmd in commands:
    if toload.contains(cmd.name):
      outCode.add(cmd.toProcVar())
  outCode.add("  cglGetProcAddress: GLPROCLOADERPROC\n")
  outCode.add("  glNimDebugPreProc*: proc(name: string): void\n")
  outCode.add("  glNimDebugPostProc*: proc(name: string): void\n")

  outCode.add(loader)
  outCode.add(genLoader(load1_0, "1_0"))
  outCode.add(genLoader(load1_1, "1_1"))
  outCode.add(genLoader(load1_2, "1_2"))
  outCode.add(genLoader(load1_3, "1_3"))
  outCode.add(genLoader(load1_4, "1_4"))
  outCode.add(genLoader(load1_5, "1_5"))
  outCode.add(genLoader(load2_0, "2_0"))
  outCode.add(genLoader(load2_1, "2_1"))
  outCode.add(genLoader(load3_0, "3_0"))
  outCode.add(genLoader(load3_1, "3_1"))

  outCode.add(genLoader(load3_2, "3_2"))
  outCode.add(genLoader(load3_3, "3_3"))
  outCode.add(genLoader(load4_0, "4_0"))
  outCode.add(genLoader(load4_1, "4_1"))
  outCode.add(genLoader(load4_2, "4_2"))
  outCode.add(genLoader(load4_3, "4_3"))
  outCode.add(genLoader(load4_4, "4_4"))
  outCode.add(genLoader(load4_5, "4_5"))
  outCode.add(genLoader(load4_6, "4_6"))

  outCode.add("""

template glCallTemplate(cgl: any, name: string): untyped =
  when defined(opengl_debug):
    if glNimDebugPreProc != nil:
      glNimDebugPreProc(name)
  cgl
  when defined(opengl_debug):
    if glNimDebugPostProc != nil:
      glNimDebugPostProc(name)

template glTypedCallTemplate(cgl: any, name: string): untyped =
  when defined(opengl_debug):
    if glNimDebugPreProc != nil:
      glNimDebugPreProc(name)
  result = cgl
  when defined(opengl_debug):
    if glNimDebugPostProc != nil:
      glNimDebugPostProc(name)
  """)

  # wrappers for the win
  outCode.add("\n# Wrapper to add documentation and future manual modifications\n")
  for cmd in commands:
    if not toload.contains(cmd.name): continue
    outCode.add("proc " & cmd.name & "*(")
    for i in cmd.arguments:
      outCode.add(i.name & ": " & i.ptype & ", ")
    if cmd.arguments.len > 0:
      outCode = outCode.substr(0, outCode.len - 3)
    outCode.add("): " & cmd.rtn & " =\n")
    outCode.add(getDoc(cmd.name, cmd.name, 0))

    if cmd.rtn != "void":
      outCode.add("  glTypedCallTemplate(")
    else:
      outCode.add("  glCallTemplate(")
    outCode.add("c" & cmd.name & "(")
    for i in cmd.arguments:
      outCode.add(i.name & ", ")
    if cmd.arguments.len > 0:
      outCode = outCode.substr(0, outCode.len - 3)
    outCode.add("), \"" & cmd.name & "\")\n")

  outCode.add(footer)
  writeFile("gl.nim", outCode)

main()
