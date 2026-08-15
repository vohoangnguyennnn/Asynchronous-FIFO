VLIB ?= vlib
VLOG ?= vlog
VSIM ?= vsim
VDEL ?= vdel
VLOG_FLAGS ?= -sv -mfcu -cuname async_fifo_project

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
WORK_LIB := work
DO_FILE  := sim/questa.do

SOURCES := \
	rtl/reset_sync.sv \
	rtl/sync_2ff.sv \
	rtl/gray_counter.sv \
	rtl/async_fifo.sv \
	verification/async_fifo_sva.sv \
	verification/async_fifo_tb.sv

.PHONY: all compile sim gui clean help

all: sim

compile:
	@cd "$(ROOT_DIR)" && \
		if [ ! -d "$(WORK_LIB)" ]; then $(VLIB) $(WORK_LIB); fi
	@cd "$(ROOT_DIR)" && $(VLOG) $(VLOG_FLAGS) -work $(WORK_LIB) $(SOURCES)

sim: compile
	@cd "$(ROOT_DIR)" && $(VSIM) -c -do $(DO_FILE)

gui: compile
	@cd "$(ROOT_DIR)" && $(VSIM) -do $(DO_FILE)

clean:
	@cd "$(ROOT_DIR)" && \
		if [ -d "$(WORK_LIB)" ]; then $(VDEL) -lib $(WORK_LIB) -all; fi

help:
	@echo "make compile  Compile RTL and testbench"
	@echo "make sim      Run the testbench in terminal mode"
	@echo "make gui      Open Questa and load waveforms"
	@echo "make clean    Remove the compiled work library"
