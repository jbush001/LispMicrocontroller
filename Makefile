#
# Copyright 2011-2012 Jeff Bush
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


VERILOG_SRCS =	ulisp.v \
		testbench.v \
		rom.v \
		ram.v \
		lisp_core.v

IVFLAGS=-Wall -Winfloop -Wno-sensitivity-entire-array

sim.vvp: $(VERILOG_SRCS)
	iverilog -o $@ $(IVFLAGS) $(VERILOG_SRCS)

test: sim.vvp FORCE
	python tests/runtests.py

clean:
	rm sim.vvp

FORCE:
