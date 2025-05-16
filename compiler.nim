import std/strformat
import std/strutils
import std/streams
import std/osproc
import std/tables
import std/paths
import std/files
import std/os
import nimprj


template withDir(dir: string, body: untyped): untyped =
  let current = os.getCurrentDir()
  try:
    setCurrentDir(dir)
    body
  finally:
    setCurrentDir(current)


proc wrap_exec_cmd(cmd: string, args: seq[string]): (string, string, int) =
  let
    process = startProcess(cmd, args = args, options = {poUsePath})
    stdout  = process.outputStream.readAll()
    stderr  = process.errorStream.readAll()
    code    = process.waitForExit()

  process.close()

  return (stdout, stderr, code)

proc get_panic_path(file: string): (string, string, bool) =
  const panic_override = "panicoverride.nim"

  let
    absolute       = file.expandTilde().absolutePath()
    (dir, _, _)    = splitFile(absolute)
    panic_path     = dir.Path / panic_override.Path
    panic_path_str = $panic_path

  if fileExists(panic_path_str):
    stderr.writeLine fmt"panicoverride already exists in {dir}"
    return ("", "", false)

  (panic_path_str, dir, true)

template with_panic_override(file: string, body: untyped): untyped =
  ## Injects a temporary panicoverride.nim, and deletes it once work is done.
  ## If one already exists in the current dir, no work is performed and an
  ## error message is printed.
  ##
  ## Note: the file is injected in the actual directory where the file being
  ## compiled is located into.
  let (panic_path, dir, path_ok) = get_panic_path(file)
  if not path_ok:
    return

  withDir dir:
    try:
      writeFile(panic_path, panic_tpl)
      body
    finally:
      removeFile(panic_path)


const
  cmd = "nim"
  first = "c"
  avrman_flags = """
--os:standalone --cpu:avr --mm:none --threads:off --define:release
--define:$# --passC:"-mmcu=$#" --passL:"-mmcu=$#"
--avr.standalone.gcc.options.linker:"-static"
--avr.standalone.gcc.exe:avr-gcc
--avr.standalone.gcc.linkerexe:avr-gcc
-o:$#.elf $#
"""

when hostOS == "windows":
  const
    flags = avrman_flags + """--gcc.options.always:"-w -fmax-errors=3")"""
else:
  const
    flags = avrman_flags


proc compile_file*(file, mcu: string; opts: seq[string]; hex, show, ver: bool) =
  let
    mcu_flag     = mcu_map[mcu]
    (_, name, _) = splitFile(file)
    full_cmd     = flags % [mcu_flag, mcu, mcu, name, file]
    args         = @[first] & opts & full_cmd.split_whitespace()

  with_panic_override(file):
    let (cstdout, cstderr, ccode) = wrap_exec_cmd(cmd, args)
    if ccode != 0:
      stderr.writeLine &"could not compile the file, original error: {cstderr}"
      return

    if ver:
      stdout.writeLine cstdout

    if hex:
      const hex_cmd = "avr-objcopy"
      let   hex_flags = @["-O", "ihex", fmt"{name}.elf", fmt"{name}.hex"]

      let (_, hstderr, hcode) = wrap_exec_cmd(hex_cmd, hex_flags)
      if hcode != 0:
        stderr.writeLine &"could not convert to hex, original error: {hstderr}"
        return

    if show:
      let ext  = if hex: "hex" else: "elf"
      defer:
        removeFile(fmt"{name}.{ext}")

      case ext
      of "hex":
        try:
          let file = readFile(fmt"{name}.{ext}")
          stdout.write file
        except:
          stderr.write fmt"could not open '{name}.{ext}'"
      of "elf":
        const dump_cmd   = "avr-objdump"
        let   dump_flags = @["-D", fmt"{name}.elf"]

        let (dstdout, dstderr, dcode) = wrap_exec_cmd(dump_cmd, dump_flags)
        if dcode != 0:
          stderr.writeLine &"error executing objdump, original error: {dstderr}"
          return

        stdout.writeLine dstdout