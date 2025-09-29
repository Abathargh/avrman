import std/unittest
import ../nimprj

suite "nim codegen":
  test "generate progstr":
    expect ConfigException:
      discard generate_progstr("", "", "", "", "")

    expect ConfigException:
      discard generate_progstr("", "", "atmelice", "", "")

    expect ConfigException:
      discard generate_progstr("", "", "atmelice", "", "/dev/mock")

    expect ConfigException:
      discard generate_progstr("m328p", "fake_dev", "", "", "")

    let nodevcmd = generate_progstr("m328p", "", "atmelice", "", "/dev/ttyTEST")
    check(no_devcmd == "-c atmelice -p m328p -P /dev/ttyTEST")

    let dev_noport = generate_progstr("", "uno", "", "", "")
    check(dev_noport == """-c arduino -p atmega328p -B 115200 -P " & port & """")

    let dev_port = generate_progstr("", "mega", "", "", "/dev/ttyMock")
    check(dev_port == "-c stk500v2 -p atmega2560 -B 115200 -D -P /dev/ttyMock")
