# Package

version       = "0.1.0"
author        = "mar"
description   = "An AVR project manager."
license       = "BSD-3-Clause"
bin           = @["avrman"]


# Dependencies

requires "nim >= 1.6.14"

after build:
  exec("strip -s " & bin[0])
  exec("upx --best " & bin[0])