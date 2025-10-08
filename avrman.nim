import std/parseopt
import std/strformat
import std/strutils
import std/tables
import std/sets
import std/os

import device/device
import compiler
import codegen

const
  version = "v0.3.0"

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
  device            interacts with the avr devices connected to this machine
"""

  init_usage = """
Initializes an avr project.

    avrman init [options] PROJECT_NAME

Options:
  -f, --fcpu        specifies the selected frequency
  -m, --mcu         specifies the microcontroller part number
  -d, --device      specifies the device used to program the microcontroller
  -p, --programmer  specifies the programmer to use
  -P, --port        specifies the port to use to program the device
  -s, --supported   prints a list of supported microcontroller part numbers
  -h, --help        shows this help message
  --nosrc           specifies to nimble not to use the default src directory
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
  -o, --option      specifies an additional option to pass to the nim compiler
  -m, --mcu         specifies the microcontroller part number
  -s, --show        shows the elf/hex dump instead of just compiling
  -x, --hex         compiles to hex instead of elf
  -v, --verbose     prints more info
  -h, --help        shows this help message
"""

  device_usage = """
Interacts with the avr devices connected to this machine. This can be used
to list the current connected devices, get metadata related to them, perform
simple read/write operations.

    avrman device [options]

Options:
  -p, --port      retrieves the port associated to the specified device
  -l, --list      list the names of the supported devices to be retrieved with
                  the port option
  -h, --help      shows this help message
"""


proc printError(msg: string) =
  try:
    stderr.writeLine msg
  except IOError:
    discard


proc init(cmd_str: string): bool =
  if cmd_str == "":
    printError "you must specify a project name"
    return false

  var
    mcu     = ""
    fcpu    = ""
    devname = ""
    port    = ""
    proj    = ""
    program = ""
    nosrc   = false
    cproj   = false
    cmake   = false

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
        of "mcu":        mcu     = val.toLower
        of "fcpu":       fcpu    = val
        of "device":     devname = val
        of "programmer": program = val
        of "port":       port    = val
        of "nosrc":      nosrc   = true
        of "cproject":   cproj   = true
        of "cmake":      cmake   = true
        of "supported": supported(); return true
        of "help": echo init_usage; return true
        else:
          echo "Unsupported long option $#" % opt
          return false
      of cmdShortOption:
        case opt
        of "m": mcu     = val.toLower
        of "f": fcpu    = val
        of "d": devname = val
        of "p": program = val
        of "P": port    = val
        of "s": supported(); return true
        of "h": echo init_usage; return true
        else:
          echo "Unsupported short option $#" % opt
          return false
      of cmdArgument:
        proj = opt
        # assert only arg?
        break

  # is the passed device (if any) a programmer?
  let norm_dev = devname.to_lower_ascii.replace("-", "")
  let is_prog  = device.is_supported(norm_dev) and get_device(norm_dev).mcu != ""

  if (norm_dev == "" or is_prog) and mcu == "":
    printError "you must specify an mcu or a mcu-based device"
    return false

  if not codegen.is_supported(mcu):
    printError "the passed mcu is not supported"
    return false

  if proj == "":
    printError "you must specify a project name"
    return false

  # if we're here, we have a valid mcu and project

  try:
    var device = default(Device)

    if devname != "":
      device = get_device(devname)

    if program != "": device.protocol = program
    if mcu     != "": device.mcu = mcu

    if fcpu == "" and device.freq == 0:
      stdout.writeLine "using default F_CPU=16000000"
      device.freq = 16_000_000

    if fcpu != "":
      try:
        let f = fcpu.parseInt()
        if f <= 0: raise newException(ValueError, "")
        device.freq = f
      except ValueError:
        printError "you must pass a valid fcpu (positive integer)"
        return false

    if cproj:
      generate_c_project(device, port, proj, cmake)
    else:
      generate_nim_project(device, port, proj, nosrc)
  except CatchableError:
    let err = getCurrentException()
    let msg = getCurrentExceptionMsg()
    printError("Error ($#): $#" % [err.repr, msg])
    os.removeDir(proj)
    return false
  true


proc compile(cmd_str: string): bool =
  if cmd_str == "":
    printError "you must specify a file name"
    return false

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
      of "help":    echo compile_usage; return true
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
      of "h": echo compile_usage; return true
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
  true

proc device(cmd_str: string): bool =
  if cmd_str == "":
    printError "you must specify a device name"
    return false

  var
    port      = false
    devstr    = ""
    pi = initOptParser(
      cmd_str,
      shortNoVal = {'l', 'p', 'h'},
      longNoVal = @["config", "list", "port", "help"]
    )

  for kind, opt, val in getopt(pi):
    case pi.kind
    of cmdEnd:
      break
    of cmdLongOption:
      case opt
      of "port":   port = true
      of "list":   echo supported_names_str; return true
      of "help":   echo device_usage; return true
      else:
        echo "Unsupported long option $#" % opt
        return false
    of cmdShortOption:
      case opt
      of "p": port   = true
      of "l": echo supported_names_str; return true
      of "h": echo device_usage; return true
      else:
        echo "Unsupported short option $#" % opt
        return false
    of cmdArgument:
      devstr = opt
      break

  if devstr == "":
    printError "you must specify a device name"
    return false

  try:
    if not device.is_supported(devstr):
      let closest = closest_guess(devstr)
      printError fmt"unsupported device '{devstr}', did you mean '{closest}'?"
      return false

    let device    = get_device(devstr)
    let port_name = device.find_port()

    if port:
      if  port_name == "":
        printError fmt"no connected device for '{devstr}'"
        return false
      echo port_name
    else:
      let curr_pstr = device.generate_progstr(port_name)
      let port_str  = if port_name == "": "not connected" else: port_name
      echo fmt """{device.name}
      port:        {port_str}
      prog_string: {curr_pstr}
      """

  except CatchableError:
    let err = getCurrentException()
    let msg = getCurrentExceptionMsg()
    printError("Error ($#): $#" % [err.repr, msg])
    return false
  true


const
  commands = {
    "init":    avrman.init,
    "compile": compile,
    "device":  device,
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
