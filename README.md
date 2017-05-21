[![Build Status](https://travis-ci.org/jbush001/LispMicrocontroller.svg?branch=master)](https://travis-ci.org/jbush001/LispMicrocontroller)
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/8f4aff19a2d242f892acc10b98950f46)](https://www.codacy.com/app/jbush001/LispMicrocontroller?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=jbush001/LispMicrocontroller&amp;utm_campaign=Badge_Grade)

This is a simple microcontroller that runs a compiled LISP dialect.  Details of operation are in the [wiki](https://github.com/jbush001/LispMicrocontroller/wiki).

## Running in simulation

This uses Icarus Verilog for simulation (http://iverilog.icarus.com/). Tests are located in the tests/ directory. Run them as follows:

    make test

The test runner searches files for patterns that begin with 'CHECK:'. The output of the program will be compared to whatever comes after this declaration. If they do not match, an error will be flagged.

### Manually running a program

* Compile the LISP sources.
This produces two files: program.hex, which has the raw program machine code and is loaded by the simulator, and program.lst, which is informational and shows details of the generated code.  For example:

        ./compile.py tests/test1.lisp

Note that any writes to register index 0 will be printed to standard out by the simulation test harness, which is how most simulation tests work.

* Run simulation.
The simulator will read rom.hex each time it starts.

        vvp sim.vvp

## Running in hardware

This has only been tested under Quartus/Altera with the Cyclone II starter kit.  There are a couple of projects located
under the fpga/ directory:
  - 7seg: simple program that displays numbers on the 4-digit, 7 segment display
  - game: a little arcade-style demo with animated sprites

### To build:

* Compile the LISP sources.
These are located in the project directory, but must be compiled from the top directory.
For example, from LispMicrocontroller/

        ./compile.py fpga/game/game.lisp

    rom.hex will be created in the top level LispMicrocontroller/ directory.

* Synthesize the design
Open the program file (for example, fpga/game/game.qpf).  Note that the synthesis tools will
read rom.hex to create the values for program ROM.  If you recompile the LISP sources (thereby changing rom.hex), the design must be re-synthesized.

* Run using the programmer included with Quartus.
