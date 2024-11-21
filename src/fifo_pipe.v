//******************************************************************************
// file:    fifo_pipe.v
//
// author:  JAY CONVERTINO
//
// date:    2021/06/29
//
// about:   Brief
// Pipe fifo signals to help with timing issues, if they arise.
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
 * Module: fifo_pipe
 *
 * Pipe fifo signals to help with timing issues, if they arise.
 *
 * Parameters:
 *
 *    BYTE_WIDTH    - How many bytes wide the data in/out will be.
 *    COUNT_WIDTH   - Data count output width in bits. Should be the same power of two as fifo depth(256 for fifo depth... this should be 8).
 *    RD_SYNC_DEPTH - Add in pipelining to read path. Defaults to 0.
 *    WR_SYNC_DEPTH - Add in pipelining to write path. Defaults to 0.
 *    DC_SYNC_DEPTH - Add in pipelining to data count path. Defaults to 0.
 *    DATA_ZERO     - Zero out data output when enabled.
 *
 * Ports:
 *
 *    rd_clk            - Clock for read data
 *    rd_rstn           - Negative edge reset for read.
 *    rd_en             - Active high enable input of read interface.
 *    rd_valid          - Active high output input that the data is valid.
 *    rd_data           - Output data input
 *    rd_empty          - Registered Active high output when read is empty.
 *    r_rd_en           - Registered Active high enable of read interface.
 *    r_rd_valid        - Registered Active high output that the data is valid.
 *    r_rd_data         - Registered Output data
 *    r_rd_empty        - Active high output when read is empty.
 *    wr_clk            - Clock for write data
 *    wr_rstn           - Negative edge reset for write
 *    wr_en             - Active high enable of write interface, feed into register.
 *    wr_ack            - Active high when enabled, that data write has been done, feed into register.
 *    wr_data           - Input data, feed into register.
 *    wr_full           - Active high output that the FIFO is full, feed into register.
 *    r_wr_en           - Register Active high enable of write interface.
 *    r_wr_ack          - Register Active high when enabled, that data write has been done.
 *    r_wr_data         - Register Input data
 *    r_wr_full         - Register Active high output that the FIFO is full.
 *    data_count_clk    - Clock for data count
 *    data_count_rstn   - Negative edge reset for data count.
 *    data_count        - Output that indicates the amount of data in the FIFO.
 */
module fifo_pipe #(
    parameter RD_SYNC_DEPTH = 0,
    parameter WR_SYNC_DEPTH = 0,
    parameter DC_SYNC_DEPTH = 0,
    parameter BYTE_WIDTH = 1,
    parameter DATA_ZERO  = 0,
    parameter COUNT_WIDTH= 1
  )
  (
    input                         rd_clk,
    input                         rd_rstn,
    input                         rd_en,
    input                         rd_valid,
    input   [(BYTE_WIDTH*8)-1:0]  rd_data,
    input                         rd_empty,
    output                        r_rd_en,
    output                        r_rd_valid,
    output  [(BYTE_WIDTH*8)-1:0]  r_rd_data,
    output                        r_rd_empty,
    input                         wr_clk,
    input                         wr_rstn,
    input                         wr_en,
    input                         wr_ack,
    input   [(BYTE_WIDTH*8)-1:0]  wr_data,
    input                         wr_full,
    output                        r_wr_en,
    output                        r_wr_ack,
    output  [(BYTE_WIDTH*8)-1:0]  r_wr_data,
    output                        r_wr_full,
    input                         data_count_clk,
    input                         data_count_rstn,
    input   [COUNT_WIDTH:0]       data_count,
    output  [COUNT_WIDTH:0]       r_data_count
  );
  
  //for loop unroll index
  integer index;
  
  // Read register arrays
  reg [RD_SYNC_DEPTH-1:0]  reg_rd_valid;
  reg [RD_SYNC_DEPTH-1:0]  reg_rd_empty;
  reg [(BYTE_WIDTH*8)-1:0] reg_rd_data[RD_SYNC_DEPTH-1:0];
  
  // Write register arrays
  reg [WR_SYNC_DEPTH-1:0]  reg_wr_ack;
  reg [WR_SYNC_DEPTH-1:0]  reg_wr_full;
  reg [(BYTE_WIDTH*8)-1:0] reg_wr_data[WR_SYNC_DEPTH-1:0];
  
  // Data count register
  reg [COUNT_WIDTH:0] reg_data_count[DC_SYNC_DEPTH-1:0];

  //generate the correct block
  generate
  // No sync depth defined, just send read through.
  if (RD_SYNC_DEPTH == 0) begin
    assign r_rd_en     = rd_en;
    assign r_rd_valid  = rd_valid;
    assign r_rd_data   = ((rd_valid != 1'b1) && (DATA_ZERO > 0) ? 0 : rd_data);
    assign r_rd_empty  = rd_empty;
  end
  
  // No sync depth defined, just send write through.
  if (WR_SYNC_DEPTH == 0) begin
    assign r_wr_en     = wr_en;
    assign r_wr_ack    = wr_ack;
    assign r_wr_data   = wr_data;
    assign r_wr_full   = wr_full;
  end
  
  // No sync depth defined, just send data count through
  if (DC_SYNC_DEPTH == 0) begin
    assign r_data_count = data_count;
  end
  
  // Sync depth defined, create register pipe for read.
  if (RD_SYNC_DEPTH > 0) begin
    assign r_rd_en     = rd_en;
    assign r_rd_valid  = reg_rd_valid[RD_SYNC_DEPTH-1];
    assign r_rd_data   = ((rd_valid != 1'b1) && (DATA_ZERO > 0) ? 0 : reg_rd_data[RD_SYNC_DEPTH-1]);
    assign r_rd_empty  = reg_rd_empty[RD_SYNC_DEPTH-1];
    
    always @(posedge rd_clk) begin
      if(rd_rstn == 1'b0) begin
        reg_rd_valid <= 0;
        reg_rd_empty <= 0;
        
        for(index = 0; index < RD_SYNC_DEPTH; index = index + 1) begin
          reg_rd_data[index] <= 0;
        end
      end else begin
        reg_rd_valid[0] <= rd_valid;
        reg_rd_data[0]  <= rd_data;
        reg_rd_empty[0] <= rd_empty;
        
        //synth eliminates null vectors
        for(index = 0; index < RD_SYNC_DEPTH; index = index + 1) begin
          reg_rd_valid[index] <= reg_rd_valid[index-1];
          reg_rd_data[index]  <= reg_rd_data[index-1];
          reg_rd_empty[index] <= reg_rd_empty[index-1];
        end
      end
    end
  end
  
  // Sync depth defined, create register pipe for write.
  if (WR_SYNC_DEPTH > 0) begin
    assign r_wr_en   = wr_en;
    assign r_wr_ack  = reg_wr_ack[WR_SYNC_DEPTH-1];
    assign r_wr_data = reg_wr_data[WR_SYNC_DEPTH-1];
    assign r_wr_full = reg_wr_full[WR_SYNC_DEPTH-1];
  
    always @(posedge wr_clk) begin
      if(wr_rstn == 1'b0) begin
        reg_wr_ack  <= 0;
        reg_wr_full <= 0;
        
        for(index = 0; index < WR_SYNC_DEPTH; index = index + 1) begin
          reg_wr_data[index] <= 0;
        end
      end else begin
        reg_wr_ack[0]   <= wr_ack;
        reg_wr_data[0]  <= wr_data;
        reg_wr_full[0]  <= wr_full;
        
        //synth eliminates null vectors
        for(index = 0; index < WR_SYNC_DEPTH; index = index + 1) begin
          reg_wr_ack[index] <= reg_wr_ack[index-1];
          reg_wr_data[index]  <= reg_wr_data[index-1];
          reg_wr_full[index] <= reg_wr_full[index-1];
        end
      end
    end
  end
  
  // Sync depth defined, create register pipe for data count.
  if (DC_SYNC_DEPTH > 0) begin
    assign r_data_count = reg_data_count[DC_SYNC_DEPTH-1];
    
    always @(posedge data_count_clk) begin
      if(data_count_rstn == 1'b0) begin
        for(index = 0; index < WR_SYNC_DEPTH; index = index + 1) begin
          reg_data_count[index] <= 0;
        end
      end else begin
        reg_data_count[0] <= data_count;
        
        for(index = 0; index < WR_SYNC_DEPTH; index = index + 1) begin
          reg_data_count[index] <= reg_data_count[index-1];
        end
      end
    end
  end
  endgenerate
  
endmodule
