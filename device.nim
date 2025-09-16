import std/[os, strformat, strutils, sets, sugar, tables]
import serial


type Device = object
  name: string
  pid:  uint16


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
    Device(name: "Uno", pid: 0x0001),
    Device(name: "Mega2560", pid: 0x0010),
    Device(name: "LeonardoBootloader", pid: 0x0036),
    Device(name: "SerialAdapter", pid: 0x003b),
    Device(name: "DueProgrammingPort", pid: 0x003d),
    Device(name: "Due", pid: 0x003e),
    Device(name: "MegaADK", pid: 0x003f),
    Device(name: "Mega2560R3", pid: 0x0042),
    Device(name: "UnoR3", pid: 0x0043),
    Device(name: "MegaADKR3", pid: 0x0044),
    Device(name: "SerialR3", pid: 0x0045),
    Device(name: "ISP", pid: 0x0049),
    Device(name: "Leonardo ", pid: 0x8036),
    Device(name: "RobotControlBoard ", pid: 0x8038),
    Device(name: "RobotMotorBoard ", pid: 0x8039),
  ],
  0x1366: @[ # segger
    Device(name: "J-Link PLUS", pid: 0x0101),
    Device(name: "J-Link", pid: 0x1015),
  ],
}.toTable


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


proc get_vid_pid_linux(dev: string): tuple[vid: uint16, pid: uint16] =
  let
    dev_name = dev.split("/")[^1]
    tty_path = fmt"/sys/class/tty/{dev_name}/device"
    evt_path = fmt"/sys/class/tty/{dev_name}/device/uevent"

  if dirExists(tty_path) and fileExists(evt_path):
    for line in evt_path.lines:
      if "PRODUCT=" in line:
        let meta     = line.split("PRODUCT=")[^1]
        let meta_ids = meta.split("/")
        return (meta_ids[0].parseHexInt.uint16, meta_ids[1].parseHexInt.uint16)
  (0'u16, 0'u16)

template get_vid_pid(dev: string): tuple[vid: uint16, pid: uint16] =
  when defined(linux):
    get_vid_pid_linux(dev)
  else:
    raise CatchableError("avr device is only supported on linux")

proc find_device_port*(name: string): string =
  for port in listSerialPorts():
    let (vid, pid) = get_vid_pid(port)
    if vid in interesting_vids:
      for device in interesting_vids[vid]:
        if pid == device.pid and name == device.name:
          return port
  ""

when isMainModule:
  echo find_device_port("Uno")
