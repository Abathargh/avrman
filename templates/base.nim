# This is a basic example of an application that can be compiled for the avr
# backend. The example lights up an LED connected on the 0th pin of the first 
# port available in the specified MCU.

import avr_io


when compiles(portA):
  const ledPort = portA
elif compiles(portB):
  const ledPort = portB
elif compiles(portC):
  const ledPort = portC
elif compiles(portD):
  const ledPort = portD


proc main =
  ledPort.asOutputPin(0)
  ledPort.setPin(0)
  while true:
    discard


main()
