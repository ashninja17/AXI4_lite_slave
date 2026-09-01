#!/usr/bin/env bash
# ============================================================
# run_regression.sh  --  AXI4-Lite Protocol Checker Regression
# ============================================================
# Requires: Vivado XSIM (2025.x) on PATH.
#
# Usage:
#   ./run_regression.sh           -- run full regression from repo root
#   ./run_regression.sh --clean   -- clean artifacts then run
#
# Exit codes:
#   0  -- all tests passed
#   1  -- one or more tests failed
# ============================================================

set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0
OVERALL=0

RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[1;33m'
NC='\033[0m'  # No colour

banner() { echo; echo "============================================================"; echo "  $1"; echo "============================================================"; }

# -----------------------------------------------------------
# Optional clean
# -----------------------------------------------------------
if [[ "${1:-}" == "--clean" ]]; then
    banner "Cleaning previous artifacts"
    rm -rf xsim.dir xsim.covdb xsim.covinfo xelab.log xelab.pb
    rm -rf xvlog.log xvlog.pb xsim.log xsim.jou waveform.vcd
    rm -rf cov_report cov_report_pos cov_final *.wdb dfx_runtime.txt
    rm -f  xcrg.log *.backup.jou *.backup.log xvlog_pos.log xelab_pos.log
    rm -f  xsim_pos.log xvlog_neg.log xelab_neg.log xsim_neg.log xcrg_run.log
    echo "Clean complete."
fi

# -----------------------------------------------------------
# STEP 1: Compile positive testbench sources
# -----------------------------------------------------------
banner "STEP 1: Compile (positive testbench)"
if xvlog -sv \
    rtl/axi_lite_dut.sv \
    tb/axi_lite_driver.sv \
    tb/axi_lite_monitor.sv \
    tb/axi_lite_scoreboard.sv \
    tb/axi_lite_tb.sv \
    2>&1 | tee xvlog_pos.log | grep -E "ERROR|error" ; then
    echo -e "${RED}[FAIL] Compilation errors in positive testbench.${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1)); OVERALL=1
else
    echo -e "${GRN}[PASS] Positive testbench compiled OK.${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
fi

# -----------------------------------------------------------
# STEP 2: Elaborate positive testbench
# -----------------------------------------------------------
banner "STEP 2: Elaborate (positive testbench)"
if xelab -debug all work.axi_lite_tb -s axi_sim \
    2>&1 | tee xelab_pos.log | grep -E "^ERROR" ; then
    echo -e "${RED}[FAIL] Elaboration errors in positive testbench.${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1)); OVERALL=1
else
    echo -e "${GRN}[PASS] Positive testbench elaborated OK.${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
fi

# -----------------------------------------------------------
# STEP 3: Simulate positive testbench
# -----------------------------------------------------------
banner "STEP 3: Simulate (positive testbench)"
xsim axi_sim -runall 2>&1 | tee xsim_pos.log

# Check for scoreboard PASS (not just any PASS keyword)
if grep -q "\[SB \]  OVERALL RESULT : \*\*\* PASS \*\*\*" xsim_pos.log; then
    echo -e "${GRN}[PASS] Positive testbench: Scoreboard PASS.${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL] Positive testbench: Scoreboard did NOT report PASS.${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1)); OVERALL=1
fi

# Check for unexpected $error/$fatal in positive sim
if grep -E "^\*\*\* Error|^\*\*\* Fatal|\[ASSERT" xsim_pos.log | grep -v "NEG_TEST" > /dev/null 2>&1; then
    echo -e "${RED}[FAIL] Unexpected assertion failure in positive testbench.${NC}"
    grep -E "^\*\*\* Error|^\*\*\* Fatal|\[ASSERT" xsim_pos.log | grep -v "NEG_TEST"
    FAIL_COUNT=$((FAIL_COUNT + 1)); OVERALL=1
else
    echo -e "${GRN}[PASS] No unexpected assertion failures in positive testbench.${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
fi

# -----------------------------------------------------------
# STEP 4: Collect functional coverage
# -----------------------------------------------------------
banner "STEP 4: Collect functional coverage"
if xcrg -cov_db_dir ./ -report_dir ./cov_report -report_format text \
    2>&1 | tee xcrg_run.log ; then
    echo -e "${GRN}[PASS] Coverage report generated: ./cov_report/functionalCoverageReport/${NC}"
else
    echo -e "${YEL}[WARN] Coverage report generation returned non-zero (check xcrg_run.log).${NC}"
fi

# -----------------------------------------------------------
# STEP 5: Compile negative testbench
# -----------------------------------------------------------
banner "STEP 5: Compile (negative testbench)"
if xvlog -sv \
    rtl/axi_lite_dut.sv \
    tb/axi_lite_monitor.sv \
    tb/axi_lite_scoreboard.sv \
    tb/axi_lite_neg_tb.sv \
    2>&1 | tee xvlog_neg.log | grep -E "ERROR|error" ; then
    echo -e "${RED}[FAIL] Compilation errors in negative testbench.${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1)); OVERALL=1
else
    echo -e "${GRN}[PASS] Negative testbench compiled OK.${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
fi

# -----------------------------------------------------------
# STEP 6: Elaborate negative testbench
# -----------------------------------------------------------
banner "STEP 6: Elaborate (negative testbench)"
if xelab -debug all work.axi_lite_neg_tb -s axi_neg_sim \
    2>&1 | tee xelab_neg.log | grep -E "^ERROR" ; then
    echo -e "${RED}[FAIL] Elaboration errors in negative testbench.${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1)); OVERALL=1
else
    echo -e "${GRN}[PASS] Negative testbench elaborated OK.${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
fi

# -----------------------------------------------------------
# STEP 7: Simulate negative testbench
# -----------------------------------------------------------
banner "STEP 7: Simulate (negative testbench)"
xsim axi_neg_sim -runall 2>&1 | tee xsim_neg.log

# The negative TB explicitly prints its own PASS/FAIL verdict.
if grep -q "\[NEG_TEST\] OVERALL RESULT : \*\*\* PASS \*\*\*" xsim_neg.log; then
    echo -e "${GRN}[PASS] Negative testbench: all 4 intentional violations correctly detected.${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL] Negative testbench did NOT report PASS.${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1)); OVERALL=1
fi

# Verify each individual violation was detected
for VIO in "a_awvalid_stable" "a_awaddr_stable" "a_wvalid_stable" "a_wdata_stable"; do
    if grep -q "EXPECTED assertion ${VIO} triggered" xsim_neg.log; then
        echo -e "  ${GRN}[DETECTED] ${VIO}${NC}"
    else
        echo -e "  ${RED}[MISSING]  ${VIO} was NOT detected!${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1)); OVERALL=1
    fi
done

# -----------------------------------------------------------
# STEP 8: Final summary
# -----------------------------------------------------------
banner "REGRESSION SUMMARY"
echo "  Checks passed : $PASS_COUNT"
echo "  Checks failed : $FAIL_COUNT"
echo ""
if [[ $OVERALL -eq 0 ]]; then
    echo -e "  ${GRN}OVERALL REGRESSION RESULT: PASS${NC}"
else
    echo -e "  ${RED}OVERALL REGRESSION RESULT: FAIL${NC}"
fi
echo ""
exit $OVERALL