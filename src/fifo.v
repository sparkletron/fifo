//******************************************************************************
// file:    fifo.v
//
// author:  JAY CONVERTINO
//
// date:    2021/06/29
//
// about:   Brief
// Wrapper to tie together fifo_ctrl, fifo_mem, and fifo_pipe. Emulates Xilinx
// FIFO core.
//
// license: License MIT
// Copyright 2021 Jay Convertino
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
//
//******************************************************************************

`timescale 1ns/100ps

/*
 * Module: fifo
 *
 * Wrapper to tie together fifo_ctrl, fifo_mem, and fifo_pipe.
 *
 * Parameters:
 *
 *    FIFO_DEPTH    - Depth of the fifo, must be a power of two number(divisable aka 256 = 2^8). Any non-power of two will be rounded up to the next closest.
 *    BYTE_WIDTH    - How many bytes wide the data in/out will be.
 *    COUNT_WIDTH   - Data count output width in bits. Should be the same power of two as fifo depth(256 for fifo depth... this should be 8).
 *    FWFT          - 1 for first word fall through mode. 0 for normal.
 *    RD_SYNC_DEPTH - Add in pipelining to read path. Defaults to 0.
 *    WR_SYNC_DEPTH - Add in pipelining to write path. Defaults to 0.
 *    DC_SYNC_DEPTH - Add in pipelining to data count path. Defaults to 0.
 *    COUNT_DELAY   - Delay count by one clock cycle of the data count clock. Set this to 0 to disable (only disable if read/write/data_count are on the same clock domain!).
 *    COUNT_ENA     - Enable the count output.
 *    DATA_ZERO     - Zero out data output when enabled.
 *    ACK_ENA       - Enable an ack when data is requested.
 *    RAM_TYPE      - Set the RAM type of the fifo.
 *
 * Ports:
 *
 *    rd_clk            - Clock for read data
 *    rd_rstn           - Negative edge reset for read.
 *    rd_en             - Active high enable of read interface.
 *    rd_valid          - Active high output that the data is valid.
 *    rd_data           - Output data
 *    rd_empty          - Active high output when read is empty.
 *    wr_clk            - Clock for write data
 *    wr_rstn           - Negative edge reset for write
 *    wr_en             - Active high enable of write interface.
 *    wr_ack            - Active high when enabled, that data write has been done.
 *    wr_data           - Input data
 *    wr_full           - Active high output that the FIFO is full.
 *    data_count_clk    - Clock for data count
 *    data_count_rstn   - Negative edge reset for data count.
 *    data_count        - Output that indicates the amount of data in the FIFO.
 */
module fifo #(
    parameter FIFO_DEPTH    = 256,
    parameter BYTE_WIDTH    = 1,
    parameter COUNT_WIDTH   = 8,
    parameter FWFT          = 0,
    parameter RD_SYNC_DEPTH = 0,
    parameter WR_SYNC_DEPTH = 0,
    parameter DC_SYNC_DEPTH = 0,
    parameter COUNT_DELAY   = 1,
    parameter COUNT_ENA     = 1,
    parameter DATA_ZERO     = 0,
    parameter ACK_ENA       = 0,
    parameter RAM_TYPE      = "block"
  )
  (
    input                         rd_clk,
    input                         rd_rstn,
    input                         rd_en,
    output                        rd_valid,
    output  [(BYTE_WIDTH*8)-1:0]  rd_data,
    output                        rd_empty,
    input                         wr_clk,
    input                         wr_rstn,
    input                         wr_en,
    output                        wr_ack,
    input   [(BYTE_WIDTH*8)-1:0]  wr_data,
    output                        wr_full,
    input                         data_count_clk,
    input                         data_count_rstn,
    output  [COUNT_WIDTH:0]       data_count
  );
  
  `include "util_helper_math.vh"
          
  // calculate widths
  localparam c_PWR_FIFO   = clogb2(FIFO_DEPTH); 
  localparam c_FIFO_DEPTH = 2 ** c_PWR_FIFO;
  
  // read wires
  wire                      s_rd_valid;
  wire [(BYTE_WIDTH*8)-1:0] s_rd_data;
  wire                      s_rd_empty;
  wire                      s_rd_en;
  wire                      s_rd_mem_en;
  wire [c_PWR_FIFO-1:0]     s_rd_addr;
  
  // write wires
  wire                      s_wr_ack;
  wire [(BYTE_WIDTH*8)-1:0] s_wr_data;
  wire                      s_wr_full;
  wire                      s_wr_en;
  wire                      s_wr_mem_en;
  wire [c_PWR_FIFO-1:0]     s_wr_addr;
  
  // data count
  wire [COUNT_WIDTH:0]      s_data_count;

  //Group: Instantiated Modules

  /*
   * Module: pipe
   *
   * Pipe for data sync/clock issues.
   */
  fifo_pipe #(
    .RD_SYNC_DEPTH(RD_SYNC_DEPTH),
    .WR_SYNC_DEPTH(WR_SYNC_DEPTH),
    .DC_SYNC_DEPTH(DC_SYNC_DEPTH),
    .BYTE_WIDTH(BYTE_WIDTH),
    .DATA_ZERO(DATA_ZERO),
    .COUNT_WIDTH(COUNT_WIDTH)
  ) pipe (
    .rd_clk(rd_clk),
    .rd_rstn(rd_rstn),
    .rd_en(rd_en),
    .rd_valid(s_rd_valid),
    .rd_data(s_rd_data),
    .rd_empty(s_rd_empty),
    .r_rd_en(s_rd_en),
    .r_rd_valid(rd_valid),
    .r_rd_data(rd_data),
    .r_rd_empty(rd_empty),
    .wr_clk(wr_clk),
    .wr_rstn(wr_rstn),
    .wr_en(wr_en),
    .wr_ack(s_wr_ack),
    .wr_data(wr_data),
    .wr_full(s_wr_full),
    .r_wr_en(s_wr_en),
    .r_wr_ack(wr_ack),
    .r_wr_data(s_wr_data),
    .r_wr_full(wr_full),
    .data_count_clk(data_count_clk),
    .data_count_rstn(data_count_rstn),
    .r_data_count(data_count),
    .data_count(s_data_count)
  );

  /*
   * Module: control
   *
   * Block RAM control, so it will act like a FIFO.
   */
  fifo_ctrl #(
    .FIFO_DEPTH(c_FIFO_DEPTH),
    .BYTE_WIDTH(BYTE_WIDTH),
    .ADDR_WIDTH(c_PWR_FIFO),
    .COUNT_WIDTH(COUNT_WIDTH),
    .COUNT_DELAY(COUNT_DELAY),
    .COUNT_ENA(COUNT_ENA),
    .ACK_ENA(ACK_ENA),
    .FWFT(FWFT)
  ) control (
    .rd_clk(rd_clk),
    .rd_rstn(rd_rstn),
    .rd_en(s_rd_en),
    .rd_addr(s_rd_addr),
    .rd_valid(s_rd_valid),
    .rd_mem_en(s_rd_mem_en),
    .rd_empty(s_rd_empty),
    .wr_clk(wr_clk),
    .wr_rstn(wr_rstn),
    .wr_en(s_wr_en),
    .wr_addr(s_wr_addr),
    .wr_ack(s_wr_ack),
    .wr_mem_en(s_wr_mem_en),
    .wr_full(s_wr_full),
    .data_count_clk(data_count_clk),
    .data_count_rstn( data_count_rstn),
    .data_count(s_data_count)
  );

  /*
   * Module: inst_dc_block_ram
   *
   * Block RAM
   */
  dc_block_ram #(
    .RAM_DEPTH(c_FIFO_DEPTH),
    .BYTE_WIDTH(BYTE_WIDTH),
    .ADDR_WIDTH(c_PWR_FIFO),
    .RAM_TYPE(RAM_TYPE)
  ) inst_dc_block_ram (
    .rd_clk(rd_clk),
    .rd_rstn(rd_rstn),
    .rd_en(s_rd_mem_en),
    .rd_data(s_rd_data),
    .rd_addr(s_rd_addr),
    .wr_clk(wr_clk),
    .wr_rstn(wr_rstn),
    .wr_en(s_wr_mem_en),
    .wr_ben({BYTE_WIDTH{s_wr_mem_en}}),
    .wr_data(s_wr_data),
    .wr_addr(s_wr_addr)
  );

endmodule
