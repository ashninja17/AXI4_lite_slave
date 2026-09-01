# wave.do -- Vivado XSIM waveform script for axi_lite_tb
# Restored in Stage 2 (was missing from original repo)
add_wave /axi_lite_tb/clk
add_wave /axi_lite_tb/reset_n
add_wave -divider "AW Channel"
add_wave /axi_lite_tb/awaddr
add_wave /axi_lite_tb/awvalid
add_wave /axi_lite_tb/awready
add_wave -divider "W Channel"
add_wave /axi_lite_tb/wdata
add_wave /axi_lite_tb/wvalid
add_wave /axi_lite_tb/wready
add_wave -divider "B Channel"
add_wave /axi_lite_tb/bvalid
add_wave /axi_lite_tb/bready
add_wave -divider "AR Channel"
add_wave /axi_lite_tb/araddr
add_wave /axi_lite_tb/arvalid
add_wave /axi_lite_tb/arready
add_wave -divider "R Channel"
add_wave /axi_lite_tb/rdata
add_wave /axi_lite_tb/rvalid
add_wave /axi_lite_tb/rready
add_wave -divider "Scoreboard Pulses"
add_wave /axi_lite_tb/mon_wr_done
add_wave /axi_lite_tb/mon_wr_addr
add_wave /axi_lite_tb/mon_wr_data
add_wave /axi_lite_tb/mon_rd_done
add_wave /axi_lite_tb/mon_rd_addr
add_wave /axi_lite_tb/mon_rd_data