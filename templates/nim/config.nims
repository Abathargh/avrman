switch("os", "standalone")
switch("cpu", "avr")
switch("mm", "none")
switch("define", "release")
switch("define", "$#")
switch("passC", "-DF_CPU=$#")
switch("passL", "-DF_CPU=$#")

switch("cc", "gcc")
switch("avr.standalone.gcc.options.linker", "-static")
switch("avr.standalone.gcc.exe", "avr-gcc")
switch("avr.standalone.gcc.linkerexe", "avr-gcc")

when defined(windows):
  switch("gcc.options.always", "-w -fmax-errors=3")


# avr lifecycle management tasks
import strformat

const entry = "$#"

task build, "Builds the project artefacts":
  exec fmt"nim c -o:{entry}.elf  {entry}"
  exec fmt"avr-objcopy -O ihex   {entry}.elf {entry}.hex"
  exec fmt"avr-objcopy -O binary {entry}.elf {entry}.bin"


task clean, "Deletes the previously built compiler artifacts":
  rmFile "{entry}.elf"
  rmFile "{entry}.hex"
  rmFile "{entry}.bin"
  rmDir  ".nimcache"

