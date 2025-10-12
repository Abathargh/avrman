import std/unittest
import ../device/device

suite "device tests":
  test "generate progstring":
    let dev1  = Device(mcu: "atmega328p", protocol: "arduino")
    let prog1 = dev1.generate_progstr()
    check(prog1 == "-c arduino -p atmega328p -P \" & dev_port & \"")

    let dev2  = Device(mcu: "atmega328p", protocol: "arduino")
    let prog2 = dev2.generate_progstr("/dev/ttyMOCK")
    check(prog2 == "-c arduino -p atmega328p -P /dev/ttyMOCK")

    let dev3  = Device(mcu: "m2560", protocol: "stk500v2", speed: 115200,
                       flush: true)
    let prog3 = dev3.generate_progstr("/dev/ttyMOCK")
    check(prog3 == "-c stk500v2 -p m2560 -b 115200 -D -P /dev/ttyMOCK")

  test "generate discovery string":
    discard
