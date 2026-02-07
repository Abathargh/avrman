import std/[os, osproc, strformat, strutils, syncio, tables]
import device/device


const
  mcu_map* = (proc(): Table[string, string] =
    for kind, path in walkDir("./avr_io/src/avr_io/private"):
      if kind != pcFile: continue
      var (_, name, _) = splitFile(path)
      if name.starts_with("at"):
        if name.starts_with("atmegas"):
          name.delete(6..6)
      result[name] = fmt"USING_{name.toUpperAscii()}"
  )()

  config_tpl  = staticRead("./templates/nim/config.nims")
  base_tpl    = staticRead("./templates/nim/base.nim")
  panic_tpl*  = staticRead("./templates/nim/panicoverride.nim")
  nimble_tpl  = staticRead("./templates/nim/tpl.nimble")
  flash_tpl   = staticRead("./templates/nim/tpl_flash.nimble")
  git_nim_tpl = staticRead("./templates/nim/gitignore")


type ConfigException* = object of ValueError

proc is_supported*(mcu: string) : bool = mcu in mcu_map


proc supported*() =
  stdout.write "supported microcontrollers: "
  for key in mcu_map.keys:
    stdout.write("$# " % key)
  stdout.writeLine("")


type
  License* = enum ## \
    ## Available licenses from nimble interactive mode.
    MIT         = "MIT"
    GPL2        = "GPL2.0"
    Apache2     = "Apache-2.0"
    ISC         = "ISC"
    GPL3        = "GPL-3.0"
    BSD3        = "BSD-3-Clause"
    LGPL2_1     = "LGPL-2.1"
    LGPL3       = "LGPL-3.0"
    LGPL_ex     = "LGPL-3.0-linking-exception"
    EPL2        = "EPL-2.0"
    AGPL3       = "AGPL-3.0"
    Proprietary = "Proprietary"
    Other       = "Other"


template withNewDir(d: string, code: untyped): untyped =
  if dirExists(proj):
    raise new_exception(ConfigException, fmt"./{proj} already exists")
  
  createDir(proj)
  let original = getCurrentDir()

  try:
    setCurrentDir(d)
    code
  finally:
    setCurrentDir(original)


proc generate_nim_project*(dev: Device, port, proj: string, license: License) =
  withNewDir(proj):
    let mcu_def = mcu_map[dev.mcu]
    let freq    = $dev.freq
    let author  = getEnv("USER", getEnv("USERNAME"))
    
    let (vers_long, code) = execCmdEx("nim --version")
    if code != 0:
      raise new_exception(ConfigException, "the nim compiler is not installed")

    let vers = vers_long.splitLines()[0].splitWhitespace()[3]

    writeFile("panicoverride.nim", panic_tpl)
    writeFile(".gitignore", git_nim_tpl)
    writefile(fmt"{proj}.nimble", nimble_tpl % [author, $license, proj, vers])
    writeFile(fmt"{proj}.nim", base_tpl)

    var config_cont = config_tpl % [mcu_def, freq, freq, proj]
    if dev.name != "" or port != "":
      let progstr = dev.generate_progstr(port)
      let discovery = if port != "": "" else: dev.generate_discovery()
      config_cont &= flash_tpl % [discovery, progstr, discovery, progstr]
   
    writeFile("config.nims", config_cont)


const
  make_tpl   = staticRead("./templates/c/make_tpl")
  makef_tpl  = staticRead("./templates/c/make_flash_tpl")
  cmake_tpl  = staticRead("./templates/c/cmake_tpl")
  cmakef_tpl = staticRead("./templates/c/cmake_flash_tpl")
  git_c_tpl  = staticRead("./templates/c/gitignore")
  main_tpl   = staticRead("./templates/c/main_tpl")


proc generate_c_project*(dev: Device, port, proj: string, cmake: bool) =
  withNewDir(proj):
    if cmake:
      if dev.name != "" or port != "":
        if port == "":
          stdout.writeLine "warning: port discovery is not supported with CMake"
        let progstr = dev.generate_progstr(port, FlashTarget.Make)
        writeFile("CMakeLists.txt", cmakef_tpl % [dev.mcu, $dev.freq, progstr])
      else:
        writeFile("CMakeLists.txt", cmake_tpl  % [dev.mcu, $dev.freq])
    else:
      if dev.name != "" or port != "":
        let disc    = dev.generate_discovery(FlashTarget.Make)
        let progstr = dev.generate_progstr(port, FlashTarget.Make)
        writeFile("Makefile", makef_tpl % [dev.mcu, $dev.freq, disc, progstr])
      else:
        writeFile("Makefile", make_tpl  % [dev.mcu, $dev.freq])

    writeFile(".gitignore", git_c_tpl)

    createDir("inc")
    createDir("src")
    setCurrentDir("./src")
    writeFile("main.c", main_tpl)

