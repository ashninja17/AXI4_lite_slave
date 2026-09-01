// ============================================================
// axi_lite_monitor.sv  (Stage 2 -- extended, all 5 channels)
// ============================================================
// Observes every AXI4-Lite channel and drives one-cycle-wide
// "transaction complete" pulses to the scoreboard.
//
// Race-condition strategy
// -----------------------
// All outputs use NON-BLOCKING assignments (always_ff).
// The scoreboard samples them on the NEXT posedge, so it
// always reads the value from the cycle AFTER the event.
// This is the standard clocked-pipeline separation and
// requires no extra synchronisation logic.
// ============================================================
module axi_lite_monitor (
  input  logic        clk,
  input  logic        reset_n,
  // ----- AW channel -----
  input  logic [31:0] awaddr,
  input  logic        awvalid,
  input  logic        awready,
  // ----- W channel ------
  input  logic [31:0] wdata,
  input  logic        wvalid,
  input  logic        wready,
  // ----- B channel ------
  input  logic        bvalid,
  input  logic        bready,
  // ----- AR channel -----
  input  logic [31:0] araddr,
  input  logic        arvalid,
  input  logic        arready,
  // ----- R channel ------
  input  logic [31:0] rdata,
  input  logic        rvalid,
  input  logic        rready,
  // ----- Scoreboard outputs (one-cycle-wide pulses) -----
  output logic [31:0] mon_wr_addr,
  output logic [31:0] mon_wr_data,
  output logic        mon_wr_done,
  output logic [31:0] mon_rd_addr,
  output logic [31:0] mon_rd_data,
  output logic        mon_rd_done
);

  // Pending capture registers
  logic [31:0] pend_wr_addr;
  logic [31:0] pend_wr_data;
  logic [31:0] pend_rd_addr;

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      mon_wr_addr  <= 32'h0;
      mon_wr_data  <= 32'h0;
      mon_wr_done  <= 1'b0;
      mon_rd_addr  <= 32'h0;
      mon_rd_data  <= 32'h0;
      mon_rd_done  <= 1'b0;
      pend_wr_addr <= 32'h0;
      pend_wr_data <= 32'h0;
      pend_rd_addr <= 32'h0;
    end else begin
      // Default: de-assert pulses every cycle
      mon_wr_done <= 1'b0;
      mon_rd_done <= 1'b0;

      // AW handshake: latch write address
      if (awvalid && awready) begin
        pend_wr_addr <= awaddr;
        $display("[MON] %0t | AW | addr=0x%08h", $time, awaddr);
      end

      // W handshake: latch write data
      if (wvalid && wready) begin
        pend_wr_data <= wdata;
        $display("[MON] %0t |  W | data=0x%08h", $time, wdata);
      end

      // B handshake: write transaction complete
      if (bvalid && bready) begin
        mon_wr_addr <= pend_wr_addr;
        mon_wr_data <= pend_wr_data;
        mon_wr_done <= 1'b1;
        $display("[MON] %0t |  B | write_done addr=0x%08h data=0x%08h",
                 $time, pend_wr_addr, pend_wr_data);
      end

      // AR handshake: latch read address
      if (arvalid && arready) begin
        pend_rd_addr <= araddr;
        $display("[MON] %0t | AR | addr=0x%08h", $time, araddr);
      end

      // R handshake: read transaction complete
      if (rvalid && rready) begin
        mon_rd_addr <= pend_rd_addr;
        mon_rd_data <= rdata;
        mon_rd_done <= 1'b1;
        $display("[MON] %0t |  R | read_done addr=0x%08h data=0x%08h",
                 $time, pend_rd_addr, rdata);
      end
    end
  end

endmodule