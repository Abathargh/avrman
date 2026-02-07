import std/[unittest, os, strutils, tables, random, sets]
import ../codegen
import ../device/device


# Helper to create a test device
proc make_test_device(name = "", protocol = "avr109", mcu = "atmega328p",
                      speed = 57600, freq = 16000000, flush = false): Device =
  result.name     = name
  result.protocol = protocol
  result.mcu      = mcu
  result.speed    = speed
  result.freq     = freq
  result.flush    = flush
  result.ids      = initTable[uint16, OrderedSet[uint16]]()


# Helper to run test in isolated temp directory
template with_temp_dir(body: untyped) =
  let original_dir = getCurrentDir()
  let temp_dir = getTempDir() / "avrman_test_" & $rand(int.high)
  createDir(temp_dir)
  setCurrentDir(temp_dir)
  try:
    body
  finally:
    setCurrentDir(original_dir)
    removeDir(temp_dir)


suite "mcu support":
  test "is_supported returns true for valid mcus":
    check codegen.is_supported("atmega328p")
    check codegen.is_supported("atmega32u4")
    check codegen.is_supported("atmega2560")
    check codegen.is_supported("atmega16u4")
    check codegen.is_supported("atmega640")
    check codegen.is_supported("atmega644")
    check codegen.is_supported("atmega1280")
    check codegen.is_supported("atmega1281")
    check codegen.is_supported("atmega2561")

  test "is_supported returns false for invalid mcus":
    check not codegen.is_supported("atmega9")
    check not codegen.is_supported("attiny999")
    check not codegen.is_supported("invalid")
    check not codegen.is_supported("")

  test "mcu_map contains correct defines":
    check mcu_map["atmega328p"] == "USING_ATMEGA328P"
    check mcu_map["atmega32u4"] == "USING_ATMEGA32U4"
    check mcu_map["atmega2560"] == "USING_ATMEGA2560"

suite "nim project generation":
  test "generate nim project creates directory structure":
    with_temp_dir:
      let dev = make_test_device(mcu = "atmega328p")
      generate_nim_project(dev, "", "testproj", MIT)
      
      check dirExists("testproj")
      check fileExists("testproj/config.nims")
      check fileExists("testproj/.gitignore")
      check fileExists("testproj/testproj.nimble")
      check fileExists("testproj/testproj.nim")
      check fileExists("testproj/panicoverride.nim")

  test "generate nim project config contains mcu define":
    with_temp_dir:
      let dev = make_test_device(mcu = "atmega32u4")
      generate_nim_project(dev, "", "testproj", MIT)

      let config = readFile("testproj/config.nims")
      check "USING_ATMEGA32U4" in config

  test "generate nim project with device adds flash targets":
    with_temp_dir:
      let dev = make_test_device(name = "arduino_uno", mcu = "atmega328p")
      generate_nim_project(dev, "", "testproj", MIT)

      let config = readFile("testproj/config.nims")
      check "flash" in config
      check "avrdude" in config

  test "generate nim project with port adds hardcoded port":
    with_temp_dir:
      let dev = make_test_device(name = "arduino_uno", mcu = "atmega328p")
      generate_nim_project(dev, "/dev/ttyUSB0", "testproj", MIT)

      let config = readFile("testproj/config.nims")
      check "/dev/ttyUSB0" in config

  test "generate nim project without device omits flash targets":
    with_temp_dir:
      let dev = make_test_device(name = "", mcu = "atmega328p")
      generate_nim_project(dev, "", "testproj", MIT)

      let config = readFile("testproj/config.nims")
      check "task flash" notin config

  test "generate nim project raises on existing directory":
    with_temp_dir:
      createDir("testproj")
      let dev = make_test_device(mcu = "atmega328p")

      expect ConfigException:
        generate_nim_project(dev, "", "testproj", MIT)

  test "generate nim project includes panicoverride":
    with_temp_dir:
      let dev = make_test_device(mcu = "atmega328p")
      generate_nim_project(dev, "", "testproj", MIT)

      let panic = readFile("testproj/panicoverride.nim")
      check "panic" in panic.toLowerAscii

  test "generate nim project with flush flag":
    with_temp_dir:
      let dev = make_test_device(name = "arduino_leonardo", mcu = "atmega32u4", flush = true)
      generate_nim_project(dev, "", "testproj", MIT)

      let config = readFile("testproj/config.nims")
      check "-D" in config  # flush flag adds -D to avrdude


suite "c makefile project generation":
  test "generate c make project creates directory structure":
    with_temp_dir:
      let dev = make_test_device(mcu = "atmega328p")
      generate_c_project(dev, "", "testproj", cmake = false)

      check dirExists("testproj")
      check fileExists("testproj/Makefile")
      check fileExists("testproj/.gitignore")
      check dirExists("testproj/inc")
      check dirExists("testproj/src")
      check fileExists("testproj/src/main.c")

  test "generate c make project contains mcu and frequency":
    with_temp_dir:
      let dev = make_test_device(mcu = "atmega2560", freq = 16000000)
      generate_c_project(dev, "", "testproj", cmake = false)

      let makefile = readFile("testproj/Makefile")
      check "atmega2560" in makefile
      check "16000000" in makefile

  test "generate c make project with device adds flash target":
    with_temp_dir:
      let dev = make_test_device(name = "arduino_mega", mcu = "atmega2560")
      generate_c_project(dev, "", "testproj", cmake = false)

      let makefile = readFile("testproj/Makefile")
      check "flash" in makefile
      check "avrdude" in makefile

  test "generate c make project with port adds hardcoded port":
    with_temp_dir:
      let dev = make_test_device(name = "arduino_uno", mcu = "atmega328p")
      generate_c_project(dev, "/dev/ttyACM0", "testproj", cmake = false)

      let makefile = readFile("testproj/Makefile")
      check "/dev/ttyACM0" in makefile

  test "generate c make project without device omits flash target":
    with_temp_dir:
      let dev = make_test_device(name = "", mcu = "atmega328p")
      generate_c_project(dev, "", "testproj", cmake = false)

      let makefile = readFile("testproj/Makefile")
      check "flash:" notin makefile

  test "generate c make project with discovery":
    with_temp_dir:
      let dev = make_test_device(name = "arduino_uno", mcu = "atmega328p")
      generate_c_project(dev, "", "testproj", cmake = false)

      let makefile = readFile("testproj/Makefile")
      check "DEV_PORT" in makefile
      check "avrman device -p" in makefile


suite "c cmake project generation":
  test "generate c cmake project creates directory structure":
    with_temp_dir:
      let dev = make_test_device(mcu = "atmega328p")
      generate_c_project(dev, "", "testproj", cmake = true)

      check dirExists("testproj")
      check fileExists("testproj/CMakeLists.txt")
      check fileExists("testproj/.gitignore")
      check dirExists("testproj/inc")
      check dirExists("testproj/src")
      check fileExists("testproj/src/main.c")

  test "generate c cmake project contains mcu and frequency":
    with_temp_dir:
      let dev = make_test_device(mcu = "atmega644", freq = 8000000)
      generate_c_project(dev, "", "testproj", cmake = true)

      let cmake = readFile("testproj/CMakeLists.txt")
      check "atmega644" in cmake
      check "8000000" in cmake

  test "generate c cmake project with device adds flash target":
    with_temp_dir:
      let dev = make_test_device(name = "arduino_uno", mcu = "atmega328p")
      generate_c_project(dev, "/dev/ttyUSB0", "testproj", cmake = true)

      let cmake = readFile("testproj/CMakeLists.txt")
      check "flash" in cmake.toLowerAscii or "avrdude" in cmake

  test "generate c cmake project without device omits flash target":
    with_temp_dir:
      let dev = make_test_device(name = "", mcu = "atmega328p")
      generate_c_project(dev, "", "testproj", cmake = true)

      let cmake = readFile("testproj/CMakeLists.txt")
      check "avrdude" notin cmake

  test "generate c project raises on existing directory":
    with_temp_dir:
      createDir("testproj")
      let dev = make_test_device(mcu = "atmega328p")
      
      expect ConfigException:
        generate_c_project(dev, "", "testproj", cmake = true)


suite "progstring generation":
  test "generate_progstr includes protocol and mcu":
    let dev = make_test_device(protocol = "avr109", mcu = "atmega32u4")
    let progstr = dev.generate_progstr("")

    check "-c avr109" in progstr
    check "-p atmega32u4" in progstr

  test "generate_progstr includes speed when set":
    let dev = make_test_device(speed = 115200)
    let progstr = dev.generate_progstr("")

    check "-b 115200" in progstr

  test "generate_progstr omits speed when zero":
    let dev = make_test_device(speed = 0)
    let progstr = dev.generate_progstr("")

    check "-b" notin progstr

  test "generate_progstr includes flush flag":
    let dev = make_test_device(flush = true)
    let progstr = dev.generate_progstr("")

    check "-D" in progstr

  test "generate_progstr uses hardcoded port when provided":
    let dev = make_test_device()
    let progstr = dev.generate_progstr("/dev/ttyUSB0")

    check "-P /dev/ttyUSB0" in progstr

  test "generate_progstr uses nimble discovery variable":
    let dev = make_test_device()
    let progstr = dev.generate_progstr("", Nimble)

    check "dev_port" in progstr

  test "generate_progstr uses make discovery variable":
    let dev = make_test_device()
    let progstr = dev.generate_progstr("", Make)

    check "DEV_PORT" in progstr


suite "discovery generation":
  test "generate_discovery returns empty for unnamed device":
    let dev = make_test_device(name = "")
    let disc = dev.generate_discovery()

    check disc == ""

  test "generate_discovery nimble target includes gorge_ex":
    let dev = make_test_device(name = "arduino_uno")
    let disc = dev.generate_discovery(Nimble)

    check "gorge_ex" in disc
    check "avrman device -p arduino_uno" in disc

  test "generate_discovery make target uses shell":
    let dev = make_test_device(name = "arduino_mega")
    let disc = dev.generate_discovery(Make)

    check "$(shell" in disc
    check "avrman device -p arduino_mega" in disc
