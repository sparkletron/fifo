# TCL script to create fifo constraints for every instantiated core.

foreach instance [get_cells -hier -filter {ref_name==fifo || orig_ref_name==fifo}] {
  puts "INFO: Constraining $instance"

  set_false_path -from [get_cells -hier -filter "parent=~$instance* && name =~ *control/head* && IS_SEQUENTIAL"] -to [get_cells -hier -filter "parent=~$instance* && name =~ *control/rd_head* && IS_SEQUENTIAL"]
  set_false_path -from [get_cells -hier -filter "parent=~$instance* && name =~ *control/tail* && IS_SEQUENTIAL"] -to [get_cells -hier -filter "parent=~$instance* && name =~ *control/wr_tail* && IS_SEQUENTIAL"]

  #set_false_path -from [get_cells -hier -filter {name =~ *control/r_head*    && IS_SEQUENTIAL}] -to [get_cells -hier -filter {name =~ *control/*rd_head*   && IS_SEQUENTIAL}]
  #set_false_path -from [get_cells -hier -filter {name =~ *control/r_tail*    && IS_SEQUENTIAL}] -to [get_cells -hier -filter {name =~ *control/*wr_tail*   && IS_SEQUENTIAL}]
  #set_false_path -from [get_cells -hier -filter {name =~ *control/r_gr_head* && IS_SEQUENTIAL}] -to [get_cells -hier -filter {name =~ *control/*rd_head*   && IS_SEQUENTIAL}]
  #set_false_path -from [get_cells -hier -filter {name =~ *control/r_gr_tail* && IS_SEQUENTIAL}] -to [get_cells -hier -filter {name =~ *control/*wr_tail*   && IS_SEQUENTIAL}]
  #set_false_path -from [get_cells -hier -filter {name =~ *control/r_head*    && IS_SEQUENTIAL}] -to [get_cells -hier -filter {name =~ *control/*dc_head*   && IS_SEQUENTIAL}]
  #set_false_path -from [get_cells -hier -filter {name =~ *control/r_tail*    && IS_SEQUENTIAL}] -to [get_cells -hier -filter {name =~ *control/*dc_tail*   && IS_SEQUENTIAL}]
}
