// ============================================================
// axi_lite_neg_tb.sv (Stage 5)
// ============================================================
// A standalone negative-test environment for the AXI4-Lite DUT.
// It explicitly injects protocol violations and verifies that
// the correct SVA assertions are triggered.
// ============================================================
module axi_lite_neg_tb;

  // --------------------------------------------------------
  // Signals & DUT Instantiation
  // --------------------------------------------------------
  logic clk;
  logic reset_n;

  // AXI4-Lite Interface
  logic [31:0] awaddr;
  logic        awvalid;
  logic        awready;
  logic [31:0] wdata;
  logic        wvalid;
  logic        wready;
  logic [1:0]  bresp;
  logic        bvalid;
  logic        bready;
  logic [31:0] araddr;
  logic        arvalid;
  logic        arready;
  logic [31:0] rdata;
  logic [1:0]  rresp;
  logic        rvalid;
  logic        rready;

  // Monitor interfaces (required for scoreboard/monitor instantiation)
  logic [31:0] mon_wr_addr, mon_wr_data;
  logic        mon_wr_done;
  logic [31:0] mon_rd_addr, mon_rd_data;
  logic        mon_rd_done;

  axi_lite_dut dut (
    .clk(clk),
    .reset_n(reset_n),
    .awaddr(awaddr),
    .awvalid(awvalid),
    .awready(awready),
    .wdata(wdata),
    .wvalid(wvalid),
    .wready(wready),
    .bvalid(bvalid),
    .bready(bready),
    .araddr(araddr),
    .arvalid(arvalid),
    .arready(arready),
    .rdata(rdata),
    .rvalid(rvalid),
    .rready(rready)
  );

  axi_lite_monitor mon (
    .clk(clk),
    .reset_n(reset_n),
    .awaddr(awaddr),
    .awvalid(awvalid),
    .awready(awready),
    .wdata(wdata),
    .wvalid(wvalid),
    .wready(wready),
    .bvalid(bvalid),
    .bready(bready),
    .araddr(araddr),
    .arvalid(arvalid),
    .arready(arready),
    .rdata(rdata),
    .rvalid(rvalid),
    .rready(rready),
    .mon_wr_addr(mon_wr_addr),
    .mon_wr_data(mon_wr_data),
    .mon_wr_done(mon_wr_done),
    .mon_rd_addr(mon_rd_addr),
    .mon_rd_data(mon_rd_data),
    .mon_rd_done(mon_rd_done)
  );

  axi_lite_scoreboard sb (
    .clk(clk),
    .reset_n(reset_n),
    .mon_wr_addr(mon_wr_addr),
    .mon_wr_data(mon_wr_data),
    .mon_wr_done(mon_wr_done),
    .mon_rd_addr(mon_rd_addr),
    .mon_rd_data(mon_rd_data),
    .mon_rd_done(mon_rd_done)
  );

  // --------------------------------------------------------
  // Clock generation
  // --------------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // --------------------------------------------------------
  // Negative Test Assertion Handlers
  // --------------------------------------------------------
  int expected_fails = 0;
  logic test_awvalid_fail = 0;
  logic test_awaddr_fail  = 0;
  logic test_wvalid_fail  = 0;
  logic test_wdata_fail   = 0;

  property a_awvalid_stable;
    @(posedge clk) disable iff (!reset_n) (awvalid && !awready) |=> awvalid;
  endproperty
  assert property (a_awvalid_stable) else begin
    $display("[NEG_TEST] EXPECTED assertion a_awvalid_stable triggered");
    test_awvalid_fail = 1;
    expected_fails++;
  end

  property a_awaddr_stable;
    @(posedge clk) disable iff (!reset_n) (awvalid && !awready) |=> $stable(awaddr);
  endproperty
  assert property (a_awaddr_stable) else begin
    $display("[NEG_TEST] EXPECTED assertion a_awaddr_stable triggered");
    test_awaddr_fail = 1;
    expected_fails++;
  end

  property a_wvalid_stable;
    @(posedge clk) disable iff (!reset_n) (wvalid && !wready) |=> wvalid;
  endproperty
  assert property (a_wvalid_stable) else begin
    $display("[NEG_TEST] EXPECTED assertion a_wvalid_stable triggered");
    test_wvalid_fail = 1;
    expected_fails++;
  end

  property a_wdata_stable;
    @(posedge clk) disable iff (!reset_n) (wvalid && !wready) |=> $stable(wdata);
  endproperty
  assert property (a_wdata_stable) else begin
    $display("[NEG_TEST] EXPECTED assertion a_wdata_stable triggered");
    test_wdata_fail = 1;
    expected_fails++;
  end

  // --------------------------------------------------------
  // Negative Stimulus Sequences
  // --------------------------------------------------------
  initial begin
    // Setup
    reset_n = 0;
    awvalid <= 0; wvalid <= 0; arvalid <= 0;
    bready <= 1; rready <= 1;
    awaddr <= 0; wdata <= 0; araddr <= 0;
    
    #20 reset_n = 1;
    @(posedge clk);

    // ==========================================
    // NEGATIVE TEST 1 ? AWVALID stability
    // ==========================================
    $display("[NEG_TEST] Injecting AWVALID stability violation");
    awaddr <= 32'h10;
    awvalid <= 1; // Assert AWVALID (AWREADY is 0 initially)
    @(posedge clk);
    // At this posedge, DUT samples awvalid <= 1 and will raise AWREADY.
    // However, the rule says AWVALID must remain high until AWREADY is asserted.
    // We drop it immediately (before we see the handshake).
    awvalid <= 0;
    @(posedge clk); // Assertion should fire here
    @(posedge clk);
    @(posedge clk);

    // ==========================================
    // NEGATIVE TEST 2 ? AWADDR stability
    // ==========================================
    $display("[NEG_TEST] Injecting AWADDR stability violation");
    awaddr <= 32'h20;
    awvalid <= 1; // Assert AWVALID
    @(posedge clk);
    // Next cycle, before handshake is observed, change AWADDR
    awaddr <= 32'h24;
    @(posedge clk); // Assertion should fire here
    // Handshake occurs this cycle because AWREADY goes high. 
    // We can safely drop AWVALID next cycle.
    awvalid <= 0;
    @(posedge clk);
    @(posedge clk);

    // ==========================================
    // NEGATIVE TEST 3 ? WVALID stability
    // ==========================================
    $display("[NEG_TEST] Injecting WVALID stability violation");
    wdata <= 32'h1111;
    wvalid <= 1;
    @(posedge clk);
    // Drop WVALID before WREADY responds
    wvalid <= 0;
    @(posedge clk); // Assertion should fire here
    @(posedge clk);
    @(posedge clk);

    // ==========================================
    // NEGATIVE TEST 4 ? WDATA stability
    // ==========================================
    $display("[NEG_TEST] Injecting WDATA stability violation");
    wdata <= 32'h2222;
    wvalid <= 1;
    @(posedge clk);
    // Change WDATA before handshake
    wdata <= 32'h3333;
    @(posedge clk); // Assertion should fire here
    wvalid <= 0;
    @(posedge clk);
    @(posedge clk);

    // ==========================================
    // Result Evaluation
    // ==========================================
    $display("==============================================");
    if (expected_fails == 4 && test_awvalid_fail && test_awaddr_fail && test_wvalid_fail && test_wdata_fail) begin
      $display("[NEG_TEST] OVERALL RESULT : *** PASS ***");
      $display("[NEG_TEST] All 4 intentional protocol violations were successfully detected.");
    end else begin
      $display("[NEG_TEST] OVERALL RESULT : *** FAIL ***");
      $display("[NEG_TEST] Expected 4 specific failures, but got %0d total.", expected_fails);
      $display("[NEG_TEST] Status: awvalid <= %b, awaddr <= %b, wvalid <= %b, wdata <= %b", 
               test_awvalid_fail, test_awaddr_fail, test_wvalid_fail, test_wdata_fail);
    end
    $display("==============================================");
    $finish(0);
  end

endmodule