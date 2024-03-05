# FIFO
### Emulates Xilinx FIFO FWFT and response
---

   author: Jay Convertino  
   
   date: 2021.06.29  
   
   details: Generic FIFO provides a dual clock FIFO capable of async or sync clocks. It also provides a clocked data_count that tells the user how much data is in the fifo.  
   
   license: MIT   
   
---

### Version
#### Current
  - V1.1.2 - fix some coding grammer and delayed data_count using wrong fwft signal.

#### Previous
  - V1.1.1 - readme fix
  - V1.1.0 - tcl constraints
  - V1.0.0 - initial release

### Dependencies
#### Build
  - AFRL:utility:helper:1.0.0
  
#### Simulation
  - AFRL:simulation:fifo_stimulator
  - AFRL:simulation:clock_stimulator
  - AFRL:utility:sim_helper
  
### IP USAGE
#### Parameters

* FIFO_DEPTH : Depth of the fifo, must be a power of two number(divisable aka 256 = 2^8). Any non-power of two will be rounded up to the next closest.
* COUNT_WIDTH: Data count output width in bits. Should be the same power of two as fifo depth(256 for fifo depth... this should be 8).
* BYTE_WIDTH : How many bytes wide the data in/out will be.
* FWFT       : 1 for first word fall through mode. 0 for normal.
* RD_SYNC_DEPTH : Add in pipelining to read path. Defaults to 0.
* WR_SYNC_DEPTH : Add in pipelining to write path. Defaults to 0.
* DC_SYNC_DEPTH : Add in pipelining to data count path. Defaults to 0.
* COUNT_DELAY   : Delay count by one clock cycle of the data count clock. Set this to 0 to disable (only disable if read/write/data_count are on the same clock domain!).
* RAM_TYPE      : Set the RAM type of the fifo.

### COMPONENTS
#### SRC

* fifo_ctrl.v
  * Controls the fifo_mem.v core based upon input signals.
  * Emulates Xilinx FIFO
  * First Word Fall Through mode for read is optional.
* fifo_mem.v
  * Simple dual port, dual clock RAM.
* fifo_pipe.v
  * Adds pipelining in case of timing issues.
  * Asymetic pipeline Write/Read ability.
* fifo.v
  * Wrapper that combines all the above components into a functional unit.
  
#### TB

* tb_fifo.v
  
### fusesoc

* fusesoc_info.core created.
* Simulation uses icarus to run data through the core.

#### TARGETS

* RUN WITH: (fusesoc run --target=sim VENDER:CORE:NAME:VERSION)
  - default (for IP integration builds)
  - sim
  - sim_rand_data
  - sim_rand_full_rand_data
  - sim_8bit_count_data
  - sim_rand_full_8bit_count_data
