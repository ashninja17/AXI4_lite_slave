# ============================================================
# Makefile for AXI4-Lite Protocol Checker Verification Suite
# Tools: Vivado XSIM (2025.x)
# ============================================================

.PHONY: all sim neg cov clean help

all: sim neg cov

# Compile and run positive testbench
sim:
	xvlog -sv rtl/axi_lite_dut.sv tb/axi_lite_driver.sv tb/axi_lite_monitor.sv tb/axi_lite_scoreboard.sv tb/axi_lite_tb.sv
	xelab -debug all work.axi_lite_tb -s axi_sim
	xsim axi_sim -runall

# Compile and run negative testbench
neg:
	xvlog -sv rtl/axi_lite_dut.sv tb/axi_lite_monitor.sv tb/axi_lite_scoreboard.sv tb/axi_lite_neg_tb.sv
	xelab -debug all work.axi_lite_neg_tb -s axi_neg_sim
	xsim axi_neg_sim -runall

# Generate functional coverage report
cov:
	xcrg -cov_db_dir ./ -report_dir ./cov_report -report_format text

# Clean simulation artifacts
clean:
	rm -rf xsim.dir xsim.covdb xsim.covinfo xelab.log xelab.pb
	rm -rf xvlog.log xvlog.pb xsim.log xsim.jou waveform.vcd
	rm -rf cov_report cov_report_pos cov_final *.wdb dfx_runtime.txt
	rm -f xcrg.log *.backup.jou *.backup.log *.log

help:
	@echo "Targets:"
	@echo "  make all   - Run complete positive & negative suite with coverage"
	@echo "  make sim   - Run positive testbench with scoreboard & SVA"
	@echo "  make neg   - Run negative protocol violation testbench"
	@echo "  make cov   - Generate text coverage report"
	@echo "  make clean - Remove all generated simulation files"