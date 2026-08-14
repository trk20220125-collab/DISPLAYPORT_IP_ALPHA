create_project dp_tx_pack_test "C:/Users/User/AppData/Local/Temp/vivado_pack" -part xc7k325tffg900-2 -force
add_files "C:/Users/User/AppData/Local/Temp/dp_tx_riscv_full.v"
set_property top dp_tx_top_full_tb [current_fileset -simset]
set_property -name {xsim.compile.xvlog.more_options} -value {-d __ICARUS__ -d SIM_QUIET} -objects [current_fileset -simset]
launch_simulation -mode behavioral
run -all
puts "PACKED FILE SIMULATION COMPLETE"
