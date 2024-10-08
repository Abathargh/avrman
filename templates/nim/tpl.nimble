requires "avr_io >= 0.3.0"

after build:
  when defined(windows):
    mvFile(bin[0] & ".exe", bin[0] & ".elf")
  else:
    mvFile(bin[0], bin[0] & ".elf")
  exec("avr-objcopy -O ihex " & bin[0] & ".elf " & bin[0] & ".hex")
  exec("avr-objcopy -O binary " & bin[0] & ".elf " & bin[0] & ".bin")

task clear, "Deletes the previously built compiler artifacts":
  rmFile(bin[0] & ".elf")
  rmFile(bin[0] & ".hex")
  rmFile(bin[0] & ".bin")
  rmDir(".nimcache")
