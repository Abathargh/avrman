import std/parseopt
import std/strutils
import std/tables
import std/os


const
  version = "v0.1.0"

  mcu_map = {
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

  shortFlags = {'a', 'c', 'h', 'f', 'v'}
  longFlags  = @["all", "clean", "help", "flash", "verbose"]
  usage = """
Avr manager for nim projects.
    
    avrman [options] command [command_options]

Options:
  -h, --help        shows this help message
  -v, --version     shows the current version

Commands:
  init              initializes an avr project
"""

  init_usage = """
Initializes an avr project.
    
    avrman init [options] PROJECT_NAME

Options:
  -m, --mcu         specifies the microcontroller part number
  -f, --fcpu        specifies the selected frequency
  -p, --prog        the progstring to use in the flash targets
  -s, --supported   prints a list of supported microcontroller part numbers
  -h, --help        shows this help message
"""

  config_tpl = staticRead("./templates/config.nims")
  base_tpl = staticRead("./templates/base.nim")
  panic_tpl = staticRead("./templates/panicoverride.nim")
  nimble_tpl = staticRead("./templates/tpl.nimble")
  flash_tpl = staticRead("./templates/tpl_flash.nimble")
  git_tpl = staticRead("./templates/gitignore")


proc supported() =
  stdout.write "supported microcontrollers: "
  for key in mcu_map.keys:
    stdout.write("$# " % key)
  stdout.writeLine("")


proc generate_project(mcu, fcpu, prog, proj: string) =
  if dirExists(proj):
    stdout.writeLine "a directory with the current project name already exists"
    quit(1)

  if os.execShellCmd("nimble init $#" % proj) != 0:
    stderr.writeLine "error during the project initialization"
    quit(1)
  
  setCurrentDir(proj)
    
  let mcu_def = mcu_map[mcu]
  writeFile("config.nims", config_tpl % @[mcu_def, mcu, fcpu, mcu, fcpu])
  writeFile(".gitignore", git_tpl)

  var f = open("$#.nimble" % proj, fmAppend)
  defer:
    f.close()
  f.write(nimble_tpl)
  if prog != "":
    f.write(flash_tpl % @[prog, mcu, prog, mcu])
  
  setCurrentDir("./src")
  writeFile("panicoverride.nim", panic_tpl)
  writeFile("$#.nim" % proj, base_tpl)


proc init(cmd_str: string) =
  var
    mcu = ""
    fcpu = ""
    prog = ""
    proj = ""
    pi = initOptParser(
      cmd_str, 
      shortNoVal = {'s', 'h'}, 
      longNoVal = @["supported", "help"]
    )

  for kind, opt, val in getopt(pi):
      case pi.kind
      of cmdEnd:
        break
      of cmdLongOption:
        case opt
        of "mcu":  mcu  = val.toLower
        of "fcpu": fcpu = val
        of "prog": prog = val
        of "supported": supported(); return
        of "help": echo init_usage; return
        else:
          echo "Unsupported long option $#" % opt
          quit(1)
      of cmdShortOption:
        case opt
        of "m": mcu  = val.toLower
        of "f": fcpu = val
        of "p": prog = val
        of "s": supported(); return
        of "h": echo init_usage; return
        else:
          echo "Unsupported short option $#" % opt
          quit(1)
      of cmdArgument:
        proj = opt
        # assert only arg?
        break

  if mcu == "":
    stderr.writeLine "you must specify an mcu"
    quit(1)
  
  if mcu notin mcu_map:
    stderr.writeLine "the passed mcu is not supported"
    quit(1)

  if fcpu == "":
    stdout.writeLine "using default F_CPU=16000000"
    f_cpu="16000000"

  if prog == "":
    stdout.writeLine "skipping flash targets generation"

  if proj == "":
    stderr.writeLine "you must specify a project name"
    quit(1)
  
  try:
    let f = fcpu.parseInt()
    if f <= 0: raise newException(ValueError, "")
  except ValueError:
    stderr.writeLine "you must pass a valid fcpu (positive integer)"
    quit(1)

  try:
    generate_project(mcu, fcpu, prog, proj)
  except:
    os.removeDir(proj)
    quit(1)


const
  commands = {
    "init": init,
  }.toTable


proc main() =
  var
    cmd = ""
    p = initOptParser("", shortFlags, longFlags)
  for kind, opt, val in getopt(p):
    case p.kind
    of cmdEnd:
      break
    of cmdLongOption:
      case opt
      of "help":    echo usage; return
      of "version": echo version; return
      else:
        echo "Unsupported long option $#" % opt
        quit(1)
    of cmdShortOption:
      case opt
      of "h": echo usage; quit(0)
      else:
        echo "Unsupported long option $#" % opt
        quit(1)
    of cmdArgument:
      cmd = opt
      break

  if cmd notin commands:
    stderr.writeLine "the passed command ('$#') is not supported" % cmd
    quit(1)
    
  let cmdFunc = commands[cmd]
  cmdFunc(p.cmdLineRest())


when isMainModule:
  main()
