
task flash, "Loads the compiled binary onto the MCU":
$#exec(fmt"avrdude $# -U flash:w:{entry}.hex:i")


task flash_debug, "Loads the elf binary onto the MCU":
$#exec(fmt"avrdude $# -U flash:w:{entry}.elf:e")

