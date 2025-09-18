import os, strutils, strformat

{.passL: "-framework IOKit".}
{.passL: "-framework CoreFoundation".}

type
  kern_return_t          = cint
  mach_port_t            = uint32
  io_object_t            = uint32
  io_iterator_t          = io_object_t
  io_registry_entry_t    = io_object_t
  CFTypeRef              = pointer
  CFStringRef            = pointer
  CFAllocatorRef         = pointer
  CFMutableDictionaryRef = pointer

const kIOMasterPortDefault* = mach_port_t(0)

# IOKit bindings
{.push importc, header: "<IOKit/IOKitLib.h>" .}
proc IOServiceMatching(name: cstring): CFMutableDictionaryRef
proc IOServiceGetMatchingServices(
  masterPort: mach_port_t,
  matching: CFMutableDictionaryRef,
  it: ptr io_iterator_t
): kern_return_t

proc IOIteratorNext(it: io_iterator_t): io_object_t
proc IOObjectRelease(obj: io_object_t): kern_return_t
proc IORegistryEntryCreateCFProperty(
  entry: io_registry_entry_t,
  key: CFStringRef,
  allocator: CFAllocatorRef,
  options: cint
): CFTypeRef

proc IORegistryEntryGetParentEntry(
  entry: io_registry_entry_t,
  plane: cstring,
  parent: ptr io_registry_entry_t
): kern_return_t
{.pop.}

# CoreFoundation bindings
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

proc CFGetTypeID(cf: CFTypeRef): int
proc CFNumberGetValue(number: CFTypeRef, theType: cint, valuePtr: pointer): bool
proc CFRelease(cf: CFTypeRef)
{.pop.}


# Constants
const
  kCFStringEncodingUTF8 = 0x08000100
  kCFNumberSInt32Type = 3

proc getCFStringProp(entry: io_registry_entry_t, key: cstring): string =
  let
    cfKey = CFStringCreateWithCString(nil, key, kCFStringEncodingUTF8)
    cfVal = IORegistryEntryCreateCFProperty(entry, cfKey, nil, 0)

  if cfVal == nil: return ""
  defer: CFRelease(cfVal)

  var buffer: array[256, char]
  if CFStringGetCString(cast[CFStringRef](cfVal), buffer[0].addr, buffer.len.cint, kCFStringEncodingUTF8):
    result = $cast[cstring](buffer[0].addr)

proc getCFIntProp(entry: io_registry_entry_t, key: cstring): int =
  let cfKey = CFStringCreateWithCString(nil, key, kCFStringEncodingUTF8)
  let cfVal = IORegistryEntryCreateCFProperty(entry, cfKey, nil, 0)
  if cfVal == nil: return -1
  defer: CFRelease(cfVal)

  var value: int32
  if CFNumberGetValue(cfVal, kCFNumberSInt32Type, addr value):
    result = value


proc matchTTYtoUSBVendorProduct(targetTTY: string): tuple[vid: uint16, pid: uint16] =
  var iter: io_iterator_t
  let matching = IOServiceMatching("IOSerialBSDClient")
  if IOServiceGetMatchingServices(kIOMasterPortDefault, matching, addr iter) != 0:
    echo "Failed to get IOSerialBSDClient devices"
    return

  var device = IOIteratorNext(iter)
  while device != 0:
    let callout = getCFStringProp(device, "IOCalloutDevice")
    if callout.endsWith(targetTTY):
      var parent: io_registry_entry_t
      if IORegistryEntryGetParentEntry(device, "IOService", addr parent) == 0:
        var grandparent: io_registry_entry_t
        if IORegistryEntryGetParentEntry(parent, "IOService", addr grandparent) == 0:
          let vendor = getCFIntProp(grandparent, "idVendor")
          let product = getCFIntProp(grandparent, "idProduct")
          echo "Match: ", callout
          echo fmt"  idVendor: 0x{vendor:X}"
          echo fmt"  idProduct: 0x{product:04X}"
          discard IOObjectRelease(grandparent)
        discard IOObjectRelease(parent)
    discard IOObjectRelease(device)
    device = IOIteratorNext(iter)

  discard IOObjectRelease(iter)

when isMainModule:
  matchTTYtoUSBVendorProduct("/dev/cu.usbmodem11201")
