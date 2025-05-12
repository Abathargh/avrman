import std/strformat
import std/strutils
import std/tables
import std/syncio
import std/os


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

  config_tpl = staticRead("./templates/nim/config.nims")
  base_tpl   = staticRead("./templates/nim/base.nim")
  panic_tpl* = staticRead("./templates/nim/panicoverride.nim")
  nimble_tpl = staticRead("./templates/nim/tpl.nimble")
  flash_tpl  = staticRead("./templates/nim/tpl_flash.nimble")
  git_tpl    = staticRead("./templates/nim/gitignore")


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


proc generate_project*(mcu, fcpu, prog, proj: string, nosrc: bool) =
  if dirExists(proj):
    stdout.writeLine "a directory with the current project name already exists"
    quit(1)

  if os.execShellCmd("nimble init $#" % proj) != 0:
    stderr.writeLine "error during the project initialization"
    quit(1)
  
  setCurrentDir(proj)
    
  let mcu_def = mcu_map[mcu]
  writeFile("config.nims", config_tpl % [mcu_def, mcu, fcpu, mcu, fcpu])
  writeFile(".gitignore", git_tpl)

  let filename = "$#.nimble" % proj
  if nosrc:
    delete_src_dir(proj, filename)

  var f = open(filename, fmAppend)
  defer:
    f.close()
  f.write(nimble_tpl)
  if prog != "":
    f.write(flash_tpl % [prog, mcu, prog, mcu])
  
  if not nosrc:
    setCurrentDir("./src")
  writeFile("panicoverride.nim", panic_tpl)
  writeFile("$#.nim" % proj, base_tpl)
