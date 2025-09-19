import std/[os, strutils]

# IOKit and CoureFoundation procedure wrapping for nim
# This was quite a... fun? experience which I would not want to repeat any time
# soon lol


{.passL: "-framework IOKit".}
{.passL: "-framework CoreFoundation".}


type
  KernReturn             = cint
  MachPort               = uint32
  IoObject               = uint32
  IoIterator             = IoObject
  IoRegEntry             = IoObject
  CFTypeRef              = pointer
  CFStringRef            = pointer
  CFAllocatorRef         = pointer
  CFMutableDictionaryRef = pointer

{.push importc, header: "<IOKit/IOKitLib.h>" .}
proc IOServiceMatching(name: cstring): CFMutableDictionaryRef
proc IOServiceGetMatchingServices(
  masterPort: MachPort,
  matching: CFMutableDictionaryRef,
  it: ptr IoIterator
): KernReturn

proc IOIteratorNext(it: IoIterator): IoObject
proc IOObjectRelease(obj: IoObject): KernReturn
proc IORegistryEntryCreateCFProperty(
  entry: IoRegEntry,
  key: CFStringRef,
  allocator: CFAllocatorRef,
  options: cint
): CFTypeRef

proc IORegistryEntryGetParentEntry(
  entry: IoRegEntry,
  plane: cstring,
  parent: ptr IoRegEntry
): KernReturn
{.pop.}

{.push importc, header: "<CoreFoundation/CoreFoundation.h>".}
proc CFStringCreateWithCString(
  alloc: CFAllocatorRef,
  cStr: cstring,
  encoding: cint
): CFStringRef

proc CFStringGetCString(
  cfStr: CFStringRef,
  buffer: cstring,
  bufferSize: cint,
  encoding: cint
): bool

proc CFNumberGetValue(number: CFTypeRef, typ: cint, valuePtr: pointer): bool
proc CFRelease(cf: CFTypeRef)
{.pop.}


const
  port_default* = MachPort(0)
  enc_utf8      = 0x08000100
  sint32_type   = 3
  bufsize       = 256


# Utility stuff to make everything a bit more readable for the future

template to_cstr(buf: array[bufsize, char]): cstring =
  cast[cstring](buf[0].addr) # simple char array -> cstring


template with_parent(curr, res: IoRegEntry, code: untyped): untyped =
  try:
    if IORegistryEntryGetParentEntry(device, "IOService", addr res) == 0:
      code
  finally:
    discard IOObjectRelease(res)


iterator io_iterator(it: IoIterator): IoObject =
  var device = IOIteratorNext(it)
  while device != 0:
    yield device
    discard IOObjectRelease(device)
    device = IOIteratorNext(it)
  discard IOObjectRelease(it)


# Higher level wrappers for properties retrieval

proc get_cfs_string_prop(entry: IoRegEntry, key: cstring): string =
  let cfKey = CFStringCreateWithCString(nil, key, enc_utf8)
  let cfVal = IORegistryEntryCreateCFProperty(entry, cfKey, nil, 0)
  if  cfVal == nil: return ""
  defer: CFRelease(cfVal)

  var buf: array[bufsize, char]
  let cfs = cast[CFStringRef](cfVal)
  if CFStringGetCString(cfs, buf.to_cstr, bufsize, enc_utf8):
    result = $buf.to_cstr


proc get_cf_int_prop(entry: IoRegEntry, key: cstring): int =
  let cfKey = CFStringCreateWithCString(nil, key, enc_utf8)
  let cfVal = IORegistryEntryCreateCFProperty(entry, cfKey, nil, 0)
  if  cfVal == nil: return -1
  defer: CFRelease(cfVal)

  var value: int32
  if CFNumberGetValue(cfVal, sint32_type, addr value):
    result = value


iterator enumerate_serial_devices(): string =
  for kind, path in walkDir("/dev/"):
    let name = path.extractFilename
    if kind == pcFile and (name.startswith("tty.") or name.startswith("cu.")):
      yield path


proc get_vid_pid(port: string): tuple[vid: uint16, pid: uint16] =
  # USB metadata is stored in a different way under macosx then linux, and
  # to cross reference the port of the device (i.e. /dev/[tty | cu]....) one
  # must first identify the proper IOSerialBSDClient, go back into the
  # hierarchy and extract the vid/pid from there.
  var iter: IoIterator
  let matching = IOServiceMatching("IOSerialBSDClient")
  if IOServiceGetMatchingServices(port_default, matching, addr iter) != 0:
    return

  for device in io_iterator(iter):
    let callout = get_cfs_string_prop(device, "IOCalloutDevice")
    if callout.endsWith(port):
      var parent:      IoRegEntry
      var grandparent: IoRegEntry
      with_parent(device, parent):
        with_parent(parent, grandparent):
          let vendor  = get_cf_int_prop(grandparent, "idVendor")
          let product = get_cf_int_prop(grandparent, "idProduct")
          return (vendor.uint16, product.uint16)


when isMainModule:
  # small test
  for path in enumerate_serial_devices():
    let (vid, pid) = get_vid_pid(path)
    echo fmt"{path}: 0x{vid:X} - 0x{pid:X}"
