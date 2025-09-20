## device implements some useful stuff for device discovery on various
## platforms.
## One thing I always wanted with this kind of libraries, was to automate
## everything regarding the loading and discovery process, so that's what this
## is about, a generic mechanism for device and pid/vid retrieval.

import std/[dirs, os, strutils, sets, sugar, tables]

## a target must define ‘enumerate_serial_devices‘ and ‘get_vid_pid‘

when defined(linux):
  include device_linux
elif defined(macosx):
  include device_macosx
else:
  type UnsupportedException = object of Exception
  iterator enumerate_serial_devices(): seq[string] =
    raise new_exception(UnsupportedException, "unsupported platform")

  proc get_vid_pid(dev: string): tuple[vid: uint16, pid: uint16] =
    raise new_exception(UnsupportedException, "unsupported platform")


type Device = object
  vid:  uint16
  pid:  uint16
  mcu:  string
  opts: string


# this is a table with every interesting device that may be used to flash an
# avr mcu

const interesting_vids = {
  0x3EB'u16: @[ # atmel
    Device(name: "JTAG-ICE-mkII", pid: 0x2103),
    Device(name: "AVR-ISP-mkII", pid: 0x2104),
    Device(name: "AVRONE!", pid: 0x2105),
    Device(name: "STK600", pid: 0x2106),
    Device(name: "AVR Dragon", pid: 0x2107),
    Device(name: "AVR JTAGICE3", pid: 0x2110),
    Device(name: "AVR JTAGICE3-v3.x", pid: 0x2140),
    Device(name: "ICE debugger", pid: 0x2141),
    Device(name: "ATMEGA328P-XMINI", pid: 0x2145),
  ],
  0x2341: @[ # arduino
    Device(name: "Uno", pid: 0x0001, mcu: "m328p", opts: "-b 11520"),
    Device(name: "Mega2560", pid: 0x0010, mcu: "m2560", opts: "-D -b 11520"),
    Device(name: "LeonardoBootloader", pid: 0x0036),
    Device(name: "SerialAdapter", pid: 0x003b),
    Device(name: "DueProgrammingPort", pid: 0x003d),
    Device(name: "Due", pid: 0x003e),
    Device(name: "MegaADK", pid: 0x003f),
    Device(name: "Mega2560R3", pid: 0x0042, mcu: "m2560", opts: "-D -b 11520"),
    Device(name: "UnoR3", pid: 0x0043, mcu: "m328p", opts: "-b 11520"),
    Device(name: "MegaADKR3", pid: 0x0044),
    Device(name: "SerialR3", pid: 0x0045),
    Device(name: "ISP", pid: 0x0049),
    Device(name: "Leonardo ", pid: 0x8036, mcu: "m32u4", opts: "-b 57600"),
    Device(name: "RobotControl ", pid: 0x8038, mcu: "m32u4", opts: "-b 57600"),
    Device(name: "RobotMotor ", pid: 0x8039, mcu: "m32u4", opts: "-b 57600"),
  ],
  0x1366: @[ # segger
    Device(name: "J-Link PLUS", pid: 0x0101),
    Device(name: "J-Link", pid: 0x1015),
  ],
}.toTable

# The following two here are just a const sequence of the names of the device
# above, and a const concatenated version of the same, to print with
# avrman device -l, for convenience

const supported_devices* = collect(initHashSet()):
  for device_list in interesting_vids.values:
    for device in device_list:
      {device.name}


const supported_devices_str* = (
  block:
    var dev_str: seq[string] = @[]
    for device_list in interesting_vids.values:
      for device in device_list:
        dev_str.add(device.name)
    dev_str
).join("\n")


proc levenshtein(s1, s2: string): int =
  var supp = newSeq[seq[int]](s1.len + 1)
  for i in 0..s1.len:
    supp[i] = newSeq[int](s2.len + 1)

  for i in 0..s1.len:
    supp[i][0] = i

  for j in 0..s2.len:
    supp[0][j] = j

  for i in 1..s1.len:
    for j in 1..s2.len:
      if s1[i - 1] != s2[j-1]:
        let minimum = min(min(supp[i][j-1], supp[i-1][j]), supp[i-1][j-1])
        supp[i][j] = minimum + 1
      else:
        supp[i][j] = supp[i-1][j-1]

  supp[s1.len][s2.len]

proc closest_guess*(name: string): string =
  ## levenshtein distance for the supported devices
  var min_name = ""
  var min_len  = int.high

  for device_name in supported_devices:
    let distance = levenshtein(name, device_name)
    if distance < min_len:
      min_name = device_name
      min_len = distance

  min_name

proc find_device_port*(name: string): string =
  for port in enumerate_serial_devices():
    let (vid, pid) = get_vid_pid(port)
    if vid in interesting_vids:
      for device in interesting_vids[vid]:
        if pid == device.pid and name == device.name:
          return port
  ""
