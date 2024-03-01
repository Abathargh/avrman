# Package

version       = "0.1.0"
author        = "mar"
description   = "An AVR project manager."
license       = "BSD-3-Clause"
bin           = @["avrman"]


# Dependencies

requires "nim >= 2.0.0"

task clean, "deletes the previously built binary":
  if fileExists bin[0]:
    rmFile bin[0]
