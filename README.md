This is a simple microcontroller that runs a compiled LISP dialect.  Details of operation are in the [wiki](https://github.com/jbush001/LispMicrocontroller/wiki).

## Running in simulation

This has been tested with Icarus Verilog (http://iverilog.icarus.com/), although other tool flows are probably similar.  Tests can be run as follows:

### Automated tests

<pre>
    make test 
</pre>

Tests are located in the tests/ directory.  The test runner will search files for 'CHECK:'.  The output of the program will be compared to whatever comes after this declaration.  If they do not match, an error will be flagged.

### Manually running a program

* Compile the LISP sources.  
This will produce two files: program.hex, which has the raw program machine code and is loaded by the simulator, and program.lst, which is informational and shows details of the generated code.  For example:

<pre>
    ./compile.py tests/test1.lisp
</pre>

Note that any writes to register index 0 will be printed to standard out by the simulation test harness, which is how most simulation tests work.

* Run simulation.  
The simulator will read rom.hex each time it starts.

<pre>
    vvp sim.vvp
</pre>

## Running in hardware

This has only been tested under Quartus/Altera with the Cyclone II starter kit.  There are a couple of projects located 
under the fpga/ directory:
  - 7seg: simple program that displays numbers on the 4-digit, 7 segment display
  - game: a little arcade-style demo with animated sprites

### To build:

* Compile the LISP sources.  
These are located in the project directory, but must be compiled from the top directory.
For example, from LispMicrocontroller/

<pre>
     ./compile.py fpga/game/game.lisp
</pre>

rom.hex will be created in the top level LispMicrocontroller/ directory.

* Synthesize the design 

Open the program file (for example, fpga/game/game.qpf).  Note that the synthesis tools will 
read rom.hex to create the values for program ROM.  If you recompile the LISP sources (thereby changing rom.hex), the 
design must be re-synthesized.

* Run using the programmer included with Quartus.


