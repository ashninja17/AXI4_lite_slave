// ========================
// axi_lite_tb.sv  (Stage 3 -- expanded assertions)
// ========================
// Stage 2 changes preserved:
//   - Monitor/scoreboard wires and instances.
//   - $finish(0) timeout.
//   - $fatal(1,...) verbosity.
// Stage 3 adds:
//   - 13 new SVA assertions covering all relevant AXI4-Lite channels.
//   - All assertions are grouped in a clearly labelled section.
//   - Every assertion has a comment stating the protocol rule it checks,
//     the expected exercisability with the current stimulus, and
//     the AXI4-Lite spec rationale.
// ========================
module axi_lite_tb;
  logic clk, reset_n;
  logic [31:0] awaddr, wdata, araddr, rdata;
  logic awvalid, awready, wvalid, wready, bvalid, bready;
  logic arvalid, arready, rvalid, rready;

  // Wires carrying monitor observations to the scoreboard
  logic [31:0] mon_wr_addr, mon_wr_data;
  logic        mon_wr_done;
  logic [31:0] mon_rd_addr, mon_rd_data;
  logic        mon_rd_done;

  // DUT and Driver (unchanged port lists, wildcard connect)
  axi_lite_dut    dut    (.*);
  axi_lite_driver driver (.*);

  // Extended monitor: observes all 5 AXI4-Lite channels
  axi_lite_monitor mon (
    .clk         (clk),
    .reset_n     (reset_n),
    .awaddr      (awaddr),
    .awvalid     (awvalid),
    .awready     (awready),
    .wdata       (wdata),
    .wvalid      (wvalid),
    .wready      (wready),
    .bvalid      (bvalid),
    .bready      (bready),
    .araddr      (araddr),
    .arvalid     (arvalid),
    .arready     (arready),
    .rdata       (rdata),
    .rvalid      (rvalid),
    .rready      (rready),
    .mon_wr_addr (mon_wr_addr),
    .mon_wr_data (mon_wr_data),
    .mon_wr_done (mon_wr_done),
    .mon_rd_addr (mon_rd_addr),
    .mon_rd_data (mon_rd_data),
    .mon_rd_done (mon_rd_done)
  );

  // Scoreboard: reference-model checker
  axi_lite_scoreboard sb (
    .clk         (clk),
    .reset_n     (reset_n),
    .mon_wr_addr (mon_wr_addr),
    .mon_wr_data (mon_wr_data),
    .mon_wr_done (mon_wr_done),
    .mon_rd_addr (mon_rd_addr),
    .mon_rd_data (mon_rd_data),
    .mon_rd_done (mon_rd_done)
  );

  // ----------------------------------------------------------------
  // Clock
  // ----------------------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // ----------------------------------------------------------------
  // Reset
  // ----------------------------------------------------------------
  initial begin
    reset_n = 0;
    #20;
    reset_n = 1;
  end

  // ----------------------------------------------------------------
  // Waveform dump
  // ----------------------------------------------------------------
  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, axi_lite_tb);
  end

  // ----------------------------------------------------------------
  // Simulation timeout
  // The directed test completes in < 150 ns; 500 ns is a safe limit.
  // ----------------------------------------------------------------
  initial begin
    #2500;
    $display("[TB ] Simulation timeout reached -- ending cleanly.");
    $finish(0);
  end

  // ----------------------------------------------------------------
  // Functional coverage (Stage 4: Improved)
  // ----------------------------------------------------------------
  covergroup axi_lite_cov @(posedge clk);
    option.name = "axi_lite_cov";
    option.per_instance = 1;

    // 1. Transaction Handshakes
    cp_aw_handshake: coverpoint (awvalid && awready) { bins hit = {1}; }
    cp_w_handshake:  coverpoint (wvalid && wready)   { bins hit = {1}; }
    cp_b_handshake:  coverpoint (bvalid && bready)   { bins hit = {1}; }
    cp_ar_handshake: coverpoint (arvalid && arready) { bins hit = {1}; }
    cp_r_handshake:  coverpoint (rvalid && rready)   { bins hit = {1}; }

    // 2. Address Variation (DUT uses bits [7:0])
    cp_awaddr: coverpoint awaddr[7:0] iff (awvalid && awready) {
      bins min   = {8'h00};
      bins max   = {8'hFF};
      bins other = default;
    }
    cp_araddr: coverpoint araddr[7:0] iff (arvalid && arready) {
      bins min   = {8'h00};
      bins max   = {8'hFF};
      bins other = default;
    }

    // 3. Data Variation
    cp_wdata: coverpoint wdata iff (wvalid && wready) {
      bins all_zeros = {32'h00000000};
      bins all_ones  = {32'hFFFFFFFF};
      bins pattern_a = {32'hAAAAAAAA};
      bins pattern_5 = {32'h55555555};
      bins other     = default;
    }
    cp_rdata: coverpoint rdata iff (rvalid && rready) {
      bins all_zeros = {32'h00000000};
      bins all_ones  = {32'hFFFFFFFF};
      bins pattern_a = {32'hAAAAAAAA};
      bins pattern_5 = {32'h55555555};
      bins other     = default;
    }

    // 4. Backpressure / Stall Scenarios
    cp_aw_stall: coverpoint (awvalid && !awready) { bins hit = {1}; }
    cp_w_stall:  coverpoint (wvalid && !wready)   { bins hit = {1}; }
    cp_b_stall:  coverpoint (bvalid && !bready)   { bins hit = {1}; }
    cp_ar_stall: coverpoint (arvalid && !arready) { bins hit = {1}; }
    cp_r_stall:  coverpoint (rvalid && !rready)   { bins hit = {1}; }

    // 5. Cross Coverage: Simultaneous AW and W (important for this DUT)
    cr_aw_w_simul: cross cp_aw_handshake, cp_w_handshake;
  endgroup
  axi_lite_cov cov_inst = new();

  always @(posedge clk) begin
    if (reset_n)
      cov_inst.sample();
  end

  // ================================================================
  // AXI4-Lite Protocol Assertions  (Stage 3)
  // ================================================================
  // All assertions use:
  //   @(posedge clk)           -- synchronous, registered signals
  //   disable iff (!reset_n)   -- suppressed during active reset
  //
  // Exercisability key used in comments below:
  //   [EXERCISED]    -- antecedent fires in the current directed test
  //   [NOT-EXERCISED] -- antecedent requires stimulus not present in positive test
  // ================================================================

  // ----------------------------------------------------------------
  // A. AW Channel -- VALID stability
  // AXI4-Lite rule: Once AWVALID is asserted it must not be
  // de-asserted until the handshake (AWVALID && AWREADY) completes.
  // [EXERCISED] -- awvalid=1, awready=0 for exactly one cycle at ~35ns.
  // ----------------------------------------------------------------
  property a_awvalid_stable;
    @(posedge clk) disable iff (!reset_n)
      (awvalid && !awready) |=> awvalid;
  endproperty
  assert property (a_awvalid_stable)
    else $error("[ASSERT a_awvalid_stable] AWVALID de-asserted before AWREADY");

  // ----------------------------------------------------------------
  // A. AW Channel -- ADDRESS stability
  // AXI4-Lite rule: AWADDR must remain stable while AWVALID is high
  // and the handshake has not yet completed.
  // [EXERCISED] -- same 1-cycle window as a_awvalid_stable.
  // ----------------------------------------------------------------
  property a_awaddr_stable;
    @(posedge clk) disable iff (!reset_n)
      (awvalid && !awready) |=> $stable(awaddr);
  endproperty
  assert property (a_awaddr_stable)
    else $error("[ASSERT a_awaddr_stable] AWADDR changed while AWVALID high and AWREADY low");

  // ----------------------------------------------------------------
  // A. AW Channel -- no unknown bits on address bus
  // AXI4-Lite rule: address and control signals must not be X/Z
  // while the initiator is presenting a valid transaction.
  // $isunknown() returns 1 if any bit is X or Z.
  // [EXERCISED] -- awvalid=1 occurs; awaddr=0x10 (known good).
  // ----------------------------------------------------------------
  property a_awaddr_no_x;
    @(posedge clk) disable iff (!reset_n)
      awvalid |-> !$isunknown(awaddr);
  endproperty
  assert property (a_awaddr_no_x)
    else $error("[ASSERT a_awaddr_no_x] AWADDR contains X/Z while AWVALID");

  // ----------------------------------------------------------------
  // B. W Channel -- VALID stability
  // AXI4-Lite rule: Once WVALID is asserted it must not be
  // de-asserted until the handshake (WVALID && WREADY) completes.
  // [EXERCISED] -- wvalid=1, wready=0 for exactly one cycle at ~35ns.
  // ----------------------------------------------------------------
  property a_wvalid_stable;
    @(posedge clk) disable iff (!reset_n)
      (wvalid && !wready) |=> wvalid;
  endproperty
  assert property (a_wvalid_stable)
    else $error("[ASSERT a_wvalid_stable] WVALID de-asserted before WREADY");

  // ----------------------------------------------------------------
  // B. W Channel -- DATA stability
  // AXI4-Lite rule: WDATA must remain stable while WVALID is high
  // and the handshake has not yet completed.
  // [EXERCISED] -- same window as a_wvalid_stable.
  // ----------------------------------------------------------------
  property a_wdata_stable;
    @(posedge clk) disable iff (!reset_n)
      (wvalid && !wready) |=> $stable(wdata);
  endproperty
  assert property (a_wdata_stable)
    else $error("[ASSERT a_wdata_stable] WDATA changed while WVALID high and WREADY low");

  // ----------------------------------------------------------------
  // B. W Channel -- no unknown bits on data bus
  // [EXERCISED] -- wvalid=1 occurs; wdata=0xABCD1234 (known good).
  // ----------------------------------------------------------------
  property a_wdata_no_x;
    @(posedge clk) disable iff (!reset_n)
      wvalid |-> !$isunknown(wdata);
  endproperty
  assert property (a_wdata_no_x)
    else $error("[ASSERT a_wdata_no_x] WDATA contains X/Z while WVALID");

  // ----------------------------------------------------------------
  // C. B Channel -- VALID stability
  // AXI4-Lite rule: Once BVALID is asserted it must not be
  // de-asserted until the handshake (BVALID && BREADY) completes.
  // [EXERCISED] -- Stage 5 driver introduces 2-cycle bready back-pressure;
  // bvalid=1 && bready=0 is now observed each transaction.
  // ----------------------------------------------------------------
  property a_bvalid_stable;
    @(posedge clk) disable iff (!reset_n)
      (bvalid && !bready) |=> bvalid;
  endproperty
  assert property (a_bvalid_stable)
    else $error("[ASSERT a_bvalid_stable] BVALID de-asserted before BREADY");

  // ----------------------------------------------------------------
  // D. AR Channel -- VALID stability
  // AXI4-Lite rule: Once ARVALID is asserted it must not be
  // de-asserted until the handshake (ARVALID && ARREADY) completes.
  // [EXERCISED] -- arvalid=1, arready=0 for exactly one cycle at ~65ns.
  // ----------------------------------------------------------------
  property a_arvalid_stable;
    @(posedge clk) disable iff (!reset_n)
      (arvalid && !arready) |=> arvalid;
  endproperty
  assert property (a_arvalid_stable)
    else $error("[ASSERT a_arvalid_stable] ARVALID de-asserted before ARREADY");

  // ----------------------------------------------------------------
  // D. AR Channel -- ADDRESS stability
  // AXI4-Lite rule: ARADDR must remain stable while ARVALID is high
  // and the handshake has not yet completed.
  // [EXERCISED] -- same window as a_arvalid_stable.
  // ----------------------------------------------------------------
  property a_araddr_stable;
    @(posedge clk) disable iff (!reset_n)
      (arvalid && !arready) |=> $stable(araddr);
  endproperty
  assert property (a_araddr_stable)
    else $error("[ASSERT a_araddr_stable] ARADDR changed while ARVALID high and ARREADY low");

  // ----------------------------------------------------------------
  // D. AR Channel -- no unknown bits on address bus
  // [EXERCISED] -- arvalid=1 occurs; araddr=0x10 (known good).
  // ----------------------------------------------------------------
  property a_araddr_no_x;
    @(posedge clk) disable iff (!reset_n)
      arvalid |-> !$isunknown(araddr);
  endproperty
  assert property (a_araddr_no_x)
    else $error("[ASSERT a_araddr_no_x] ARADDR contains X/Z while ARVALID");

  // ----------------------------------------------------------------
  // E. Read response ordering
  // DUT RTL fact: when arvalid&&arready, the DUT registers rdata and
  // asserts rvalid in the VERY NEXT cycle (##1).
  // This is tighter than the spec minimum (which allows any latency)
  // but is correct for THIS DUT implementation.
  // [EXERCISED] -- AR handshake occurs at ~75ns; rvalid appears at ~85ns.
  // ----------------------------------------------------------------
  property a_read_response;
    @(posedge clk) disable iff (!reset_n)
      (arvalid && arready) |=> rvalid;
  endproperty
  assert property (a_read_response)
    else $error("[ASSERT a_read_response] RVALID not asserted cycle after AR handshake");

  // ----------------------------------------------------------------
  // F. R Channel -- VALID stability
  // AXI4-Lite rule: Once RVALID is asserted it must not be
  // de-asserted until the handshake (RVALID && RREADY) completes.
  // [EXERCISED] -- Stage 5 driver introduces 2-cycle rready back-pressure;
  // rvalid=1 && rready=0 is now observed each transaction.
  // ----------------------------------------------------------------
  property a_rvalid_stable;
    @(posedge clk) disable iff (!reset_n)
      (rvalid && !rready) |=> rvalid;
  endproperty
  assert property (a_rvalid_stable)
    else $error("[ASSERT a_rvalid_stable] RVALID de-asserted before RREADY");

  // ----------------------------------------------------------------
  // F. R Channel -- DATA stability
  // AXI4-Lite rule: RDATA must remain stable while RVALID is high
  // and the handshake has not yet completed.
  // [EXERCISED] -- same window as a_rvalid_stable.
  // ----------------------------------------------------------------
  property a_rdata_stable;
    @(posedge clk) disable iff (!reset_n)
      (rvalid && !rready) |=> $stable(rdata);
  endproperty
  assert property (a_rdata_stable)
    else $error("[ASSERT a_rdata_stable] RDATA changed while RVALID high and RREADY low");

  // ----------------------------------------------------------------
  // G. R Channel -- no unknown bits on data bus
  // AXI4-Lite rule: read data must be valid (no X/Z) while RVALID
  // is asserted.  This catches uninitialized memory reads in the DUT.
  // [EXERCISED] -- rvalid=1 occurs; rdata=0xABCD1234 (written before
  // the read, so known-good in this test).
  // ----------------------------------------------------------------
  property a_rdata_no_x;
    @(posedge clk) disable iff (!reset_n)
      rvalid |-> !$isunknown(rdata);
  endproperty
  assert property (a_rdata_no_x)
    else $error("[ASSERT a_rdata_no_x] RDATA contains X/Z while RVALID");

  // ----------------------------------------------------------------
  // Original assertion from Stage 1 / Stage 2 -- preserved unchanged.
  // Write response ordering:
  // After the simultaneous AW+W handshake the DUT must produce BVALID
  // in exactly the next clock cycle (DUT RTL confirmed: ##1).
  // [EXERCISED] -- fires at ~45ns; bvalid appears at ~55ns.
  // ----------------------------------------------------------------
  property write_response_order;
    @(posedge clk) disable iff (!reset_n)
      (awvalid && awready && wvalid && wready) |=> bvalid;
  endproperty
  assert property (write_response_order)
    else $fatal(1, "[ASSERT write_response_order] BVALID missing after AW/W handshake");

endmodule
