import std/[strformat, strutils, tables, syncio, os]
import device/device


const
  mcu_map* = {
    "atmega16u4": "USING_ATMEGA16U4",
    "atmega32u4": "USING_ATMEGA32U4",
    "atmega328p": "USING_ATMEGA328P",
    "atmega640":  "USING_ATMEGA640",
    "atmega644":  "USING_ATMEGA644",
    "atmega1280": "USING_ATMEGA1280",
    "atmega1281": "USING_ATMEGA1281",
    "atmega2560": "USING_ATMEGA2560",
    "atmega2561": "USING_ATMEGA2561",
  }.toTable

  config_tpl  = staticRead("./templates/nim/config.nims")
  base_tpl    = staticRead("./templates/nim/base.nim")
  panic_tpl*  = staticRead("./templates/nim/panicoverride.nim")
  nimble_tpl  = staticRead("./templates/nim/tpl.nimble")
  flash_tpl   = staticRead("./templates/nim/tpl_flash.nimble")
  git_nim_tpl = staticRead("./templates/nim/gitignore")

  start_tpl  = "### AVRMAN CONFIGURATION START ###"
  end_tpl    = "### AVRMAN CONFIGURATION END   ###"


type ConfigException* = object of ValueError

proc is_supported*(mcu: string) : bool = mcu in mcu_map


proc supported*() =
  stdout.write "supported microcontrollers: "
  for key in mcu_map.keys:
    stdout.write("$# " % key)
  stdout.writeLine("")


proc delete_src_dir(proj, nimble_file: string) =
  let data = readFile(nimble_file)
  var f = open(nimble_file, FileMode.fmWrite)
  defer: f.close()

  for line in data.splitLines():
    if "srcDir" in line:
      continue
    f.writeLine(line)

  for (kind, path) in walkDir(fmt"./{proj}/src"):
    case kind
    of pcFile:
      let new_path = path.split("/")[^1]
      moveFile(path, fmt"./{proj}/{new_path}")
    else: continue

  removeDir("./src")


proc generate_nim_project*(dev: Device, port, proj: string, nosrc: bool) =
  if dirExists(proj):
    raise new_exception(ConfigException, fmt"./{proj} already exists")

  if os.execShellCmd("nimble init $#" % proj) != 0:
    raise new_exception(ConfigException, "error initializing the project")

  setCurrentDir(proj)
    
  let mcu_def = mcu_map[dev.mcu]
  let freq    = $dev.freq
  let mcu     = dev.mcu
  writeFile("config.nims", config_tpl % [mcu_def, mcu, freq, mcu, freq])
  writeFile(".gitignore", git_nim_tpl)

  let filename = "$#.nimble" % proj
  if nosrc:
    delete_src_dir(proj, filename)

  var f = open(filename, fmAppend)
  defer:  f.close()

  f.write(nimble_tpl)
  if dev.name != "" or port != "":
    let progstr = dev.generate_progstr(port)
    let discovery = if port != "": "" else: dev.generate_discovery()
    f.write(flash_tpl % [discovery, progstr])
  
  if not nosrc:
    setCurrentDir("./src")
  writeFile("panicoverride.nim", panic_tpl)
  writeFile("$#.nim" % proj, base_tpl)


const
  make_tpl   = staticRead("./templates/c/make_tpl")
  makef_tpl  = staticRead("./templates/c/make_flash_tpl")
  cmake_tpl  = staticRead("./templates/c/cmake_tpl")
  cmakef_tpl = staticRead("./templates/c/cmake_flash_tpl")
  git_c_tpl  = staticRead("./templates/c/gitignore")
  main_tpl   = staticRead("./templates/c/main_tpl")


proc generate_c_project*(dev: Device, port, proj: string, cmake: bool) =
  if dirExists(proj):
    stdout.writeLine "a directory with the current project name already exists"
    quit(1)

  createDir(proj)
  setCurrentDir(proj)

  if cmake:
    if dev.name != "" or port != "":
      # TODO CMake port discovery - study how to execute stuff with cmake
      writeFile("CMakeLists.txt", cmakef_tpl % [dev.mcu, $dev.freq, ""])
    else:
      writeFile("CMakeLists.txt", cmake_tpl  % [dev.mcu, $dev.freq])
  else:
    if dev.name != "" or port != "":
      let disc    = dev.generate_discovery(FlashTarget.Make)
      let progstr = dev.generate_progstr(port)
      writeFile("Makefile", makef_tpl % [dev.mcu, $dev.freq, disc, progstr])
    else:
      writeFile("Makefile", make_tpl  % [dev.mcu, $dev.freq])

  writeFile(".gitignore", git_c_tpl)

  createDir("inc")
  createDir("src")
  setCurrentDir("./src")
  writeFile("main.c", main_tpl)
