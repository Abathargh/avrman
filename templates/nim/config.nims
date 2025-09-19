switch("os", "standalone")
switch("cpu", "avr")
switch("gc", "none")
switch("threads", "off")
switch("stackTrace", "off")
switch("lineTrace", "off")
switch("define", "release")
switch("define", "$#")
switch("passC", "-mmcu=$# -DF_CPU=$#")
switch("passL", "-mmcu=$# -DF_CPU=$#")
switch("nimcache", ".nimcache")

switch("cc", "gcc")
switch("avr.standalone.gcc.options.linker", "-static")
switch("avr.standalone.gcc.exe", "avr-gcc")
switch("avr.standalone.gcc.linkerexe", "avr-gcc")

when defined(windows):
  switch("gcc.options.always", "-w -fmax-errors=3")
