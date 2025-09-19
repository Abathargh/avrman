import std/[dirs, paths, strformat, strutils]

# Linux = easy mode

proc enumerate_serial_devices(): seq[string] =
  for kind, path in walkDir("/dev/"):
    if kind == pcFile and path.extractFilename.startswith("tty"):
      result.add(path)


proc get_vid_pid(dev: string): tuple[vid: uint16, pid: uint16] =
  let dev_name = dev.split("/")[^1]
  let tty_path = fmt"/sys/class/tty/{dev_name}/device"
  let evt_path = fmt"/sys/class/tty/{dev_name}/device/uevent"

  if dirExists(tty_path) and fileExists(evt_path):
    for line in evt_path.lines:
      if "PRODUCT=" in line:
        let meta = line.split("PRODUCT=")[^1]
        let ids  = meta.split("/")
        return (ids[0].parseHexInt.uint16, ids[1].parseHexInt.uint16)
  (0'u16, 0'u16)
