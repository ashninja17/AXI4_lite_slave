// ============================================================
// axi_lite_scoreboard.sv  (Stage 2 -- new file)
// ============================================================
// Lightweight, non-UVM reference checker for the AXI4-Lite DUT.
//
// Architecture
// ------------
//  * Receives one-cycle-wide "done" pulses from axi_lite_monitor.
//  * Maintains an associative-array reference model (ref_mem) that
//    mirrors what the DUT internal memory SHOULD contain.
//  * On every write-done pulse  -> writes {addr, data} into ref_mem.
//  * On every read-done  pulse  -> compares observed rdata against
//    ref_mem[addr] and reports PASS or FAIL.
//
// Ordering / Race-condition safety
// --------------------------------
//  The monitor uses always_ff (non-blocking assignments).
//  The scoreboard samples mon_wr_done / mon_rd_done via
//  always @(posedge clk) -- it sees the value committed ONE cycle
//  after the monitor detected the handshake.
//  Within a single clock step, blocking assignments guarantee the
//  write is committed to ref_mem BEFORE the read comparison runs.
// ============================================================
module axi_lite_scoreboard (
  input  logic        clk,
  input  logic        reset_n,
  input  logic [31:0] mon_wr_addr,
  input  logic [31:0] mon_wr_data,
  input  logic        mon_wr_done,
  input  logic [31:0] mon_rd_addr,
  input  logic [31:0] mon_rd_data,
  input  logic        mon_rd_done
);

  // Reference memory: associative array (address -> data)
  logic [31:0] ref_mem [int];

  // Statistics counters (blocking -- verification-only code)
  int wr_count = 0;
  int rd_pass  = 0;
  int rd_fail  = 0;

  // Use plain always (not always_ff) so blocking assignments are legal.
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      ref_mem.delete();
      wr_count = 0;
      rd_pass  = 0;
      rd_fail  = 0;
    end else begin

      // WRITE: update reference model (blocking -- must happen before read check)
      if (mon_wr_done) begin
        ref_mem[int'(mon_wr_addr)] = mon_wr_data;
        wr_count = wr_count + 1;
        $display("[SB ] %0t | WRITE | addr=0x%08h data=0x%08h | ref_mem updated",
                 $time, mon_wr_addr, mon_wr_data);
      end

      // READ: compare observed data against reference model
      if (mon_rd_done) begin
        if (ref_mem.exists(int'(mon_rd_addr))) begin
          if (mon_rd_data === ref_mem[int'(mon_rd_addr)]) begin
            rd_pass = rd_pass + 1;
            $display("[SB ] %0t | READ  | addr=0x%08h | PASS | exp=0x%08h got=0x%08h",
                     $time, mon_rd_addr, ref_mem[int'(mon_rd_addr)], mon_rd_data);
          end else begin
            rd_fail = rd_fail + 1;
            $error("[SB ] %0t | READ  | addr=0x%08h | FAIL | exp=0x%08h got=0x%08h",
                   $time, mon_rd_addr, ref_mem[int'(mon_rd_addr)], mon_rd_data);
          end
        end else begin
          rd_fail = rd_fail + 1;
          $warning("[SB ] %0t | READ  | addr=0x%08h | WARN | never written, got=0x%08h",
                   $time, mon_rd_addr, mon_rd_data);
        end
      end

    end
  end

  final begin
    $display("==============================================");
    $display("[SB ] SIMULATION SUMMARY");
    $display("[SB ]  Writes tracked : %0d", wr_count);
    $display("[SB ]  Read checks    : %0d", rd_pass + rd_fail);
    $display("[SB ]  Passes         : %0d", rd_pass);
    $display("[SB ]  Failures       : %0d", rd_fail);
    if (rd_fail == 0 && (rd_pass + rd_fail) > 0)
      $display("[SB ]  OVERALL RESULT : *** PASS ***");
    else if (rd_fail > 0)
      $display("[SB ]  OVERALL RESULT : *** FAIL ***");
    else
      $display("[SB ]  OVERALL RESULT : *** NO CHECKS PERFORMED ***");
    $display("==============================================");
  end

endmodule