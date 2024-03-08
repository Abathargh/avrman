# avrman

Avrman is a tool for managing nim projects targetting AVR microcontrollers.

It is tightly coupled with the [avr_io](https://github.com/Abathargh/avr_io) 
library, which is not a dependency, but it is used as the base dependency for 
projects created with this tool.

- [avrman](#avrman)
  - [Dependencies](#dependencies)
  - [Build](#build)
  - [Usage](#usage)
    - [Init](#init)
    - [Creating C projects](#creating-c-projects)
  - [License](#license)

## Dependencies

This tools does not use any third party libraries. Note that projects created 
with this tool depend on ```avr_io```.

**Requires nim >= 2.0.0.**

## Build

```bash 
git clone https://github.com/Abathargh/avrman
cd avrman
nimble build
```

## Usage

```bash
Avr manager for nim projects.
    
    avrman [options] command [command_options]

Options:
  -h, --help        shows this help message
  -v, --version     shows the current version

Commands:
  init              initializes an avr project
```

You can use the ```-h``` option with each subcommand to get a command-specific 
help prompt. 

### Init

The init command can be used to initialize a new avr project. For example, the 
following command will initialize a project for an ATMega644 running at 8KHz, 
using atmelice as its programmer:

```bash
avrman init -m:atmega644 -f:8000000 -p:"atmelice" test644
```

Note that:

- The m/mcu option is required. A complete list of supported microcontrollers 
can be obtained with the ```-s``` flag.
- The frequency defaults to 16MHz if not specified.
- If no prog string is provided, no ```flash*``` nimble targets will be 
generated.


### Creating C projects

You can also use this tool to manage a C project for an avr chip, by using the 
```--cproject``` flag.
For example, you can use the following command to initialize a Makefile-based 
C project for an arduino uno:

```bash
avrman init -m:atmega328p -f:16000000 -p:"arduino -b 115200 -P /dev/ttyACM0" \ 
  --cproject  test328p
```

If you wisht to use CMake instead, you can use the ```--cmake``` flag:

```bash
avrman init -m:atmega328p -f:16000000 -p:"arduino -b 115200 -P /dev/ttyACM0" \ 
  --cproject --cmake  test328p
```

## License

This application is licensed under the 
[BSD 3-Clause "New" or "Revised" License](LICENSE).
