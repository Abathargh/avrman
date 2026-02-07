# Windows serial device discovery using SetupAPI and Registry
# Provides the same public API as device_linux.nim and device_macosx.nim

type
  Handle   = int
  DWord    = uint32
  Bool     = int32
  HKey     = Handle
  Long     = int32
  Guid     = object
    data1: uint32
    data2: uint16
    data3: uint16
    data4: array[8, uint8]

  DevInfoData = object
    cbSize:    DWord
    classGuid: Guid
    devInst:   DWord
    reserved:  pointer

const
  InvalidHandle      = Handle(-1)
  DigrfPresent       = 0x00000002'u32
  SpdrpHardwareId    = 1'u32
  KeyRead            = 0x20019'u32
  ErrorSuccess       = 0'i32

  # GUID for serial ports: {4D36E978-E325-11CE-BFC1-08002BE10318}
  GuidSerialPort = Guid(
    data1: 0x4D36E978'u32,
    data2: 0xE325'u16,
    data3: 0x11CE'u16,
    data4: [0xBF'u8, 0xC1'u8, 0x08'u8, 0x00'u8,
            0x2B'u8, 0xE1'u8, 0x03'u8, 0x18'u8]
  )

# SetupAPI imports
{.push importc, stdcall, dynlib: "setupapi.dll".}
proc SetupDiGetClassDevsA(
  classGuid: ptr Guid,
  enumerator: cstring,
  hwndParent: Handle,
  flags: DWord
): Handle

proc SetupDiEnumDeviceInfo(
  deviceInfoSet: Handle,
  memberIndex: DWord,
  deviceInfoData: ptr DevInfoData
): Bool

proc SetupDiGetDeviceRegistryPropertyA(
  deviceInfoSet: Handle,
  deviceInfoData: ptr DevInfoData,
  property: DWord,
  propertyRegDataType: ptr DWord,
  propertyBuffer: cstring,
  propertyBufferSize: DWord,
  requiredSize: ptr DWord
): Bool

proc SetupDiOpenDevRegKey(
  deviceInfoSet: Handle,
  deviceInfoData: ptr DevInfoData,
  scope: DWord,
  hwProfile: DWord,
  keyType: DWord,
  samDesired: DWord
): HKey

proc SetupDiDestroyDeviceInfoList(deviceInfoSet: Handle): Bool
{.pop.}

# Advapi32 (Registry) imports
{.push importc, stdcall, dynlib: "advapi32.dll".}
proc RegQueryValueExA(
  hKey: HKey,
  lpValueName: cstring,
  lpReserved: pointer,
  lpType: ptr DWord,
  lpData: pointer,
  lpcbData: ptr DWord
): Long

proc RegCloseKey(hKey: HKey): Long
{.pop.}

const
  DicsGlobal   = 1'u32
  DirkDevReg   = 1'u32
  BufSize      = 512


proc enumerate_serial_devices*(): seq[string] =
  ## Enumerates all serial (COM) ports on the system.
  ## Returns a sequence of port names like "COM1", "COM3", etc.
  result = @[]

  let devInfo = SetupDiGetClassDevsA(
    unsafeAddr GuidSerialPort,
    nil,
    0,
    DigrfPresent
  )

  if devInfo == InvalidHandle:
    return

  defer: discard SetupDiDestroyDeviceInfoList(devInfo)

  var devInfoData: DevInfoData
  devInfoData.cbSize = DWord(sizeof(DevInfoData))
  var idx: DWord = 0

  while SetupDiEnumDeviceInfo(devInfo, idx, addr devInfoData) != 0:
    # Open the device's registry key to get the port name
    let hKey = SetupDiOpenDevRegKey(
      devInfo,
      addr devInfoData,
      DicsGlobal,
      0,
      DirkDevReg,
      KeyRead
    )

    if hKey != HKey(InvalidHandle):
      var buf: array[BufSize, char]
      var bufLen: DWord = BufSize
      var regType: DWord

      if RegQueryValueExA(
        hKey,
        "PortName",
        nil,
        addr regType,
        addr buf[0],
        addr bufLen
      ) == ErrorSuccess:
        let portName = $cast[cstring](addr buf[0])
        # Only include COM ports (not LPT or other ports)
        if portName.startsWith("COM"):
          result.add(portName)

      discard RegCloseKey(hKey)

    inc idx


proc get_vid_pid*(port: string): tuple[vid: uint16, pid: uint16] =
  ## Given a port name (e.g., "COM3"), returns the USB vendor ID and product ID.
  ## Returns (0, 0) if not found or not a USB serial device.
  result = (0'u16, 0'u16)

  let devInfo = SetupDiGetClassDevsA(
    unsafeAddr GuidSerialPort,
    nil,
    0,
    DigrfPresent
  )

  if devInfo == InvalidHandle:
    return

  defer: discard SetupDiDestroyDeviceInfoList(devInfo)

  var devInfoData: DevInfoData
  devInfoData.cbSize = DWord(sizeof(DevInfoData))
  var idx: DWord = 0

  while SetupDiEnumDeviceInfo(devInfo, idx, addr devInfoData) != 0:
    # First check if this is the port we're looking for
    let hKey = SetupDiOpenDevRegKey(
      devInfo,
      addr devInfoData,
      DicsGlobal,
      0,
      DirkDevReg,
      KeyRead
    )

    var foundPort = false
    if hKey != HKey(InvalidHandle):
      var buf: array[BufSize, char]
      var bufLen: DWord = BufSize
      var regType: DWord

      if RegQueryValueExA(
        hKey,
        "PortName",
        nil,
        addr regType,
        addr buf[0],
        addr bufLen
      ) == ErrorSuccess:
        let portName = $cast[cstring](addr buf[0])
        foundPort = (portName == port)

      discard RegCloseKey(hKey)

    if foundPort:
      # Get the hardware ID which contains VID and PID
      var hwIdBuf: array[BufSize, char]
      var requiredSize: DWord

      if SetupDiGetDeviceRegistryPropertyA(
        devInfo,
        addr devInfoData,
        SpdrpHardwareId,
        nil,
        cast[cstring](addr hwIdBuf[0]),
        BufSize,
        addr requiredSize
      ) != 0:
        let hwId = $cast[cstring](addr hwIdBuf[0])
        # Hardware ID format: USB\VID_XXXX&PID_YYYY...
        let upper = hwId.toUpperAscii
        let vidIdx = upper.find("VID_")
        let pidIdx = upper.find("PID_")

        if vidIdx >= 0 and pidIdx >= 0:
          try:
            let vidStr = hwId[vidIdx + 4 .. vidIdx + 7]
            let pidStr = hwId[pidIdx + 4 .. pidIdx + 7]
            result = (vidStr.parseHexInt.uint16, pidStr.parseHexInt.uint16)
          except:
            discard
      return

    inc idx


when isMainModule:
  # small test
  echo "Enumerating serial devices..."
  for port in enumerate_serial_devices():
    let (vid, pid) = get_vid_pid(port)
    echo fmt"{port}: 0x{vid:04X} - 0x{pid:04X}"
