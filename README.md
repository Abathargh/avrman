# avrman

avrman (*avr manager*) is a tool for managing nim projects targetting AVR microcontrollers.

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
with this tool depend on ```avr_io```. If port discovery is used, `avrdude` 
should be separately installed.

**Requires nim >= 2.0.0.**

## Build

```bash 
git clone https://github.com/Abathargh/avrman
cd avrman
nimble build
```

Or simply install using:

```bash
nimble install avrman
```

## Usage

```bash
avr manager for nim and c projects.

    avrman [options] command [command_options]

Options:
  -h, --help        shows this help message
  -v, --version     shows the current version

Commands:
  init              initializes an avr project
  compile           compiles an avr file with the default avrman options
  device            interacts with the avr devices connected to this machine
```

You can use the ```-h``` option with each subcommand to get a command-specific 
help prompt. 

### Init

For example, the following command will initialize a project for an ATMega644 
running at 8KHz, using atmelice as its programmer:

```bash
avrman init -m:atmega644 -f:8000000 -p:"atmelice" test644
```

Note that:

- The m/mcu option is required. A complete list of supported microcontrollers 
can be obtained with the ```-s``` flag.
- The frequency defaults to 16MHz if not specified.
- If no prog string is provided, no ```flash*``` nimble targets will be 
generated.

You can also specify devices, that avrman may know about. In that case it will 
take care of mostly everything by itself (and even of port discovery):

```bash
avrman init --device:uno test_arduino
```

### Creating C projects

You can also use this tool to manage a C project for an avr chip, by using the 
```--cproject``` flag.
For example, you can use the following command to initialize a Makefile-based 
C project for an arduino uno:

```bash
avrman init -m:atmega328p -f:16000000 -p:"arduino -b 115200 -P /dev/ttyACM0" \ 
  --cproject  test328p
```

If you wish to use CMake instead, you can use the ```--cmake``` flag:

```bash
avrman init -m:atmega328p -f:16000000 -p:"arduino -b 115200 -P /dev/ttyACM0" \ 
  --cproject --cmake  test328p
```

Device can also be used for c projects:

```bash
avrman init --device:uno --cproject test_arduino
```

But port discovery is only supported for `make` ones.

## Compile

The compile subcommand can be used for quick, one-off checks, when you do not 
want to generate a whole project and take care of everything.

Let's say you have a simple nim program save into `example.nim`. Then to 
quickly compile it, you can use `avrman compile example.nim`.

This is useful if you want to quickly produce a hex/elf and check its content 
to compare code being generated.

## Device 

To get information about connected devices (e.g. programmers, arduino boards), 
the following command can be used:

```bash
avrman device uno
avrman device --list # to show the full list of supported devices
```


## License

This application is licensed under the 
[BSD 3-Clause "New" or "Revised" License](LICENSE).
