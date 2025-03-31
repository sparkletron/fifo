#******************************************************************************
# file:    tb_cocotb.py
#
# author:  JAY CONVERTINO
#
# date:    2024/12/09
#
# about:   Brief
# Cocotb test bench
#
# license: License MIT
# Copyright 2024 Jay Convertino
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
#
#******************************************************************************

import random
import itertools

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer, Event
from cocotb.binary import BinaryValue
from cocotbext.fifo.xilinx import xilinxFIFOsource, xilinxFIFOsink

# Function: random_bool
# Return a infinte cycle of random bools
#
# Returns: List
def random_bool():
  temp = []

  for x in range(0, 256):
    temp.append(bool(random.getrandbits(1)))

  return itertools.cycle(temp)

# Function: start_clock
# Start the simulation clock generator.
#
# Parameters:
#   dut - Device under test passed from cocotb test function
def start_clock(dut):
  cocotb.start_soon(Clock(dut.wr_clk, 1, units="ns").start())
  cocotb.start_soon(Clock(dut.rd_clk, 1, units="ns").start())
  cocotb.start_soon(Clock(dut.data_count_clk, 1, units="ns").start())

# Function: reset_dut
# Cocotb coroutine for resets, used with await to make sure system is reset.
async def reset_dut(dut):
  dut.rd_rstn.value = 0
  dut.wr_rstn.value = 0
  dut.data_count_rstn.value = 0
  await Timer(5, units="ns")
  dut.rd_rstn.value = 1
  dut.wr_rstn.value = 1
  dut.data_count_rstn.value = 1

# Function: single_word
# Coroutine that is identified as a test routine. This routine tests for writing a single word, and
# then reading a single word.
#
# Parameters:
#   dut - Device under test passed from cocotb.
@cocotb.test()
async def single_word(dut):

    start_clock(dut)

    fifo_source  = xilinxFIFOsource(dut, "wr", dut.wr_clk, dut.wr_rstn, dut.FWFT.value != 0, dut.ACK_ENA.value != 0)
    fifo_sink = xilinxFIFOsink(dut, "rd", dut.rd_clk, dut.rd_rstn, dut.FWFT.value != 0)

    await reset_dut(dut)

    for x in range(255, -1, -1):

        await fifo_source.write(x)

        rx_data = await fifo_sink.read(x)

        assert rx_data == x, "Input data does not match output"

# Function: full_empty
# Coroutine that is identified as a test routine. This routine tests for writing till the fifo is full,
# Then reading from the full FIFO.
#
# Parameters:
#   dut - Device under test passed from cocotb.
@cocotb.test()
async def full_empty(dut):

    start_clock(dut)

    fifo_source  = xilinxFIFOsource(dut, "wr", dut.wr_clk, dut.wr_rstn, dut.FWFT.value != 0, dut.ACK_ENA.value != 0)
    fifo_sink = xilinxFIFOsink(dut, "rd", dut.rd_clk, dut.rd_rstn, dut.FWFT.value != 0)

    await reset_dut(dut)

    for x in range(255, -1, -1):

        temp = []

        for i in range(dut.FIFO_DEPTH.value):
          temp.append(x)

        await fifo_source.write(temp)

        rx_data = await fifo_sink.read(temp)
        for y in rx_data:
          assert y == x, "Input data does not match output"

        await RisingEdge(dut.rd_clk)

# Function: in_reset
# Coroutine that is identified as a test routine. This routine tests if device stays
# in unready state when in reset.
#
# Parameters:
#   dut - Device under test passed from cocotb.
@cocotb.test()
async def in_reset(dut):

    start_clock(dut)

    dut.rd_rstn.value = 0

    dut.wr_rstn.value = 0

    await Timer(10, units="ns")

    assert dut.rd_empty.value.integer == 1, "Empty is 0, not empty in reset!"

# Function: no_clock
# Coroutine that is identified as a test routine. This routine tests if no ready when clock is lost
# and device is left in reset.
#
# Parameters:
#   dut - Device under test passed from cocotb.
@cocotb.test()
async def no_clock(dut):

    dut.rd_rstn.value = 0

    dut.rd_clk.value = 0

    dut.wr_rstn.value = 0

    dut.rd_clk.value = 0

    await Timer(5, units="ns")

    assert dut.rd_empty.value.integer == 1, "Empty is 0, not empty in reset!"
