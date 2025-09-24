## device implements some useful stuff for device discovery on various
## platforms.
## One thing I always wanted with this kind of libraries, was to automate
## everything regarding the loading and discovery process, so that's what this
## is about, a generic mechanism for device and pid/vid retrieval.

import std/[dirs, json, os, sequtils, strformat, strutils, sets, sugar, tables]

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


type Device* = object
  name:     string
  protocol: string
  mcu:      string
  ids:      Table[uint16, OrderedSet[uint16]]
  speed:    int
  flush:    bool


# this is a table with every interesting device that may be used to flash an
# avr mcu

proc parse_ids(node: JsonNode): Table[uint16, OrderedSet[uint16]] =
  for key, val in node.pairs:
    var vid = key.parse_hex_int.uint16
    for pid in val:
      if vid notin result: result[vid] = initOrderedSet[uint16]()
      result[vid].incl pid.get_str.parse_hex_int.uint16


proc parse_dev(node: JsonNode): Device =
  # mandatory fields
  result.name     = get_str   node["name"]
  result.protocol = get_str   node["protocol"]
  result.ids      = parse_ids node["id_map"]

  # non-mandatory fields
  result.mcu      =     get_str(node.get_or_default("mcu"), "")
  result.speed    =     get_int( node.get_or_default("speed"), -1)
  result.flush    = not get_bool(node.get_or_default("dis_flush"), false)


const devices* = (proc(): Table[string, Device] =
  let boards = "device/boards.json".read_file.parse_json
  let progs  = "device/programmers.json".read_file.parse_json
  for board in boards:
    let jboard = board.parse_dev
    let tname  = jboard.name.to_lower_ascii.replace("-", "")
    result[tname] = jboard

  for prog in progs:
    let jprog = prog.parse_dev
    let tname = jprog.name.to_lower_ascii.replace("-", "")
    result[tname]  = jprog
)()

# The following two here are just a const sequence of the names of the device
# above, and a const concatenated version of the same, to print with
# avrman device -l, for convenience

const supported_names* = collect(initHashSet()):
  for name in devices.keys:
    {name}


const supported_names_str* = supported_names.to_seq.join("\n")


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

  for device_name in supported_names:
    let distance = levenshtein(name, device_name)
    if distance < min_len:
      min_name = device_name
      min_len = distance
  min_name


proc same_name(s1, s2: string): bool =
  let trim1 = s1.to_lower_ascii.replace("_", "")
  trim1 == s2


proc find_device_port*(name: string): string =
  for port in enumerate_serial_devices():
    let (vid, pid) = get_vid_pid(port)
    for dev_name, dev in devices.pairs:
      if vid in dev.ids and pid in dev.ids[vid] and same_name(name, dev_name):
        return port
  ""


proc get_device_config*(name: string): string =
  let dev = devices[name]
  var conf_str = fmt"-c {dev.protocol}"
  if dev.mcu   != "": conf_str.add fmt" -p {dev.mcu}"
  if dev.speed != -1: conf_str.add fmt" -b {dev.speed}"
  if dev.flush:       conf_str.add fmt" -D"
  conf_str