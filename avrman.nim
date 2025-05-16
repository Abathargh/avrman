import std/parseopt
import std/strutils
import std/tables
import std/os

import compiler
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
  compile           compiles an avr file with the default avrman options
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

  compile_usage = """
Compiles an avr source file using the default avrman options. This means that
the file will be compiled for the avr target in release mode, with no memory
management strategy, for the standalone os.

    avrman compile [options] FILE_NAME

Options:
  -o. --option      specifies an additional option to pass to the nim compiler
  -m, --mcu         specifies the microcontroller part number
  -s, --show        shows the elf/hex dump instead of just compiling
  -x, --hex         compiles to hex instead of elf
  -v, --verbose     prints more info
  -h, --help        shows this help message
"""


proc printError(msg: string) = 
  try:
    stderr.writeLine msg
  except IOError:
    discard


proc init*(cmd_str: string): bool =
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
          return false
      of cmdShortOption:
        case opt
        of "m": mcu  = val.toLower
        of "f": fcpu = val
        of "p": prog = val
        of "s": nimprj.supported(); return
        of "h": echo init_usage; return
        else:
          echo "Unsupported short option $#" % opt
          return false
      of cmdArgument:
        proj = opt
        # assert only arg?
        break

  if mcu == "":
    printError "you must specify an mcu"
    return false
  
  if not nimprj.is_supported(mcu):
    printError "the passed mcu is not supported"
    return false

  if fcpu == "":
    stdout.writeLine "using default F_CPU=16000000"
    f_cpu="16000000"

  if prog == "":
    stdout.writeLine "skipping flash targets generation"

  if proj == "":
    printError "you must specify a project name"
    return false
  
  try:
    let f = fcpu.parseInt()
    if f <= 0: raise newException(ValueError, "")
  except ValueError:
    printError "you must pass a valid fcpu (positive integer)"
    return false

  try:
    if cproj:
      cprj.generate_project(mcu, fcpu, prog, proj, cmake)
    else:
      nimprj.generate_project(mcu, fcpu, prog, proj, nosrc)
  except CatchableError:
    let err = getCurrentException()
    let msg = getCurrentExceptionMsg()
    printError("Error ($#): $#" % [err.repr, msg])
    os.removeDir(proj)
    return false
  return true


proc compile*(cmd_str: string): bool =
  var
    file    = ""
    mcu     = ""
    show    = false
    hex     = false
    verbose = false
    options = newSeq[string]()
    pi = initOptParser(
      cmd_str,
      shortNoVal = {'s', 'x', 'v', 'h'},
      longNoVal = @["show", "hex", "verbose", "help"]
    )

  for kind, opt, val in getopt(pi):
    case pi.kind
    of cmdEnd:
      break
    of cmdLongOption:
      case opt
      of "option":  options.add(val)
      of "mcu":     mcu      = val.toLower
      of "show":    show     = true
      of "hex":     hex      = true
      of "verbose": verbose  = true
      of "help":    echo compile_usage; return
      else:
        echo "Unsupported long option $#" % opt
        return false
    of cmdShortOption:
      case opt
      of "o": options.add(val)
      of "m": mcu     = val.toLower
      of "s": show    = true
      of "x": hex     = true
      of "v": verbose = true
      of "h": echo compile_usage; return
      else:
        echo "Unsupported short option $#" % opt
        return false
    of cmdArgument:
      file = opt
      # assert only arg?
      break

  if file == "":
    printError "you must specify a file name"
    return false

  if mcu == "":
    stdout.writeLine "warning: no mcu, defaulting to atmega328p"
    mcu = "atmega328p"

  try:
      compiler.compile_file(file, mcu, options, hex, show, verbose)
  except CatchableError:
    let err = getCurrentException()
    let msg = getCurrentExceptionMsg()
    printError("Error ($#): $#" % [err.repr, msg])
    return false
  return true


const
  commands = {
    "init": init,
    "compile": compile,
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
    printError "the passed command ('$#') is not supported" % cmd
    quit(1)
  
  let cmdFunc = commands[cmd]
  if not cmdFunc p.cmdLineRest():
    quit(1)

when isMainModule:
  main()
