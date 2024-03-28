import std/parseopt
import std/strutils
import std/tables
import std/os

import nimprj
import cprj


const
  version = "v0.1.0"

  shortFlags = {'h', 'v'}
  longFlags  = @["help", "version"]
  usage = """
avr manager for nim and c projects.
    
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
  --nosrc           specifies to nimble not to use the default `src` directory
  --cproject        initializes a C project instead of a nim one
  --cmake           uses CMake instead of plain make; checked only if using 
                    --cproject 
"""


proc init(cmd_str: string) =
  var
    mcu   = ""
    fcpu  = ""
    prog  = ""
    proj  = ""
    nosrc = false
    cproj = false
    cmake = false
    pi = initOptParser(
      cmd_str, 
      shortNoVal = {'s', 'h'}, 
      longNoVal = @["supported", "help", "nosrc", "cproject", "cmake"]
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
        of "nosrc":      nosrc = true
        of "cproject":   cproj = true
        of "cmake":      cmake = true
        of "supported": nimprj.supported(); return
        of "help": echo init_usage; return
        else:
          echo "Unsupported long option $#" % opt
          quit(1)
      of cmdShortOption:
        case opt
        of "m": mcu  = val.toLower
        of "f": fcpu = val
        of "p": prog = val
        of "s": nimprj.supported(); return
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
  
  if not nimprj.is_supported(mcu):
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
    if cproj:
      cprj.generate_project(mcu, fcpu, prog, proj, cmake)
    else:
      nimprj.generate_project(mcu, fcpu, prog, proj, nosrc)
  except CatchableError:
    let err = getCurrentException()
    let msg = getCurrentExceptionMsg()
    stderr.writeLine("Error ($#): $#" % [err.repr, msg])
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
      of "h": echo usage; return
      of "v": echo version; return
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
