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
following command will initialize an 

```bash
avrman init -m:atmega644 -f:8000000 -p:"atmelice" test644
```

Note that:

- The m/mcu option is required. A complete list of supported microcontrollers 
can be obtained with the ```-s``` flag.
- The frequency defaults to 16MHz if not specified.
- If no prog string is provided, no ```flash*``` nimble targets will be 
generated.


## License

This application is licensed under the 
[BSD 3-Clause "New" or "Revised" License](LICENSE).
