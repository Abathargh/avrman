task flash, "Loads the compiled binary onto the MCU":
  exec("avrdude -c $# -p $# -U flash:w:" & bin[0] & ".hex:i")

task flash_debug, "Loads the elf binary onto the MCU":
  exec("avrdude -c $# -p $# -U flash:w:" & bin[0] & ".elf:e")
