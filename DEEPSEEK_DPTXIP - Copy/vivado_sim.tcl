# =============================================================================
# Vivado 2025.2 Simulation Script
# DP TX + RISC-V AUX Controller
# =============================================================================
# Usage: In Vivado Tcl Console, run:
#   source C:/Users/User/Downloads/DEEPSEEK_DPTXIP - Copy/vivado_sim.tcl
# =============================================================================

set proj_dir "C:/Users/User/Downloads/DEEPSEEK_DPTXIP - Copy/vivado_proj2"
set src_dir  "C:/Users/User/Downloads/DEEPSEEK_DPTXIP - Copy/src"
set tb_dir   "C:/Users/User/Downloads/DEEPSEEK_DPTXIP - Copy/tb"

# Create project
create_project dp_tx_sim $proj_dir -part xc7k325tffg900-2 -force
set_property simulator_language Verilog [current_project]
set_property target_language    Verilog [current_project]

# Add RTL sources
add_files [glob $src_dir/*.v]
add_files [glob $src_dir/riscv/*.v]

# Add testbench
add_files -fileset sim_1 [glob $tb_dir/dp_tx_top_full_tb.v]
add_files -fileset sim_1 [glob $tb_dir/dp_tx_top_tb.v]

# Set top module for simulation
set_property top dp_tx_top_full_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Add __ICARUS__ define for behavioral PHY model (no GTX primitives)
set_property -name {xsim.compile.xvlog.more_options} -value {-d __ICARUS__ -d SIM_QUIET} -objects [get_filesets sim_1]

# Set simulation timescale
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]

# Launch simulation
launch_simulation -mode behavioral

# Run simulation
run -all

# Print status
puts "============================================"
puts "  Simulation complete"
puts "  Check waveform and console output above"
puts "============================================"
