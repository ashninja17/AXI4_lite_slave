// ========================
// axi_lite_driver.sv
// ========================
module axi_lite_driver (
  input  logic        clk,
  input  logic        reset_n,
  output logic [31:0] awaddr,
  output logic        awvalid,
  input  logic        awready,
  output logic [31:0] wdata,
  output logic        wvalid,
  input  logic        wready,
  input  logic        bvalid,
  output logic        bready,
  output logic [31:0] araddr,
  output logic        arvalid,
  input  logic        arready,
  input  logic [31:0] rdata,
  input  logic        rvalid,
  output logic        rready
);

  typedef enum {IDLE, WRITE, READ, DONE} state_t;
  state_t state;
  int trans_idx;

  // Test vectors to hit coverage bins (Address: min, max, other. Data: zeros, ones, pattern_a, pattern_5)
  logic [31:0] test_addr [4] = '{32'h00000000, 32'h000000FF, 32'h000000AA, 32'h00000055};
  logic [31:0] test_data [4] = '{32'h00000000, 32'hFFFFFFFF, 32'hAAAAAAAA, 32'h55555555};

  int bwait, rwait;

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      state     <= IDLE;
      trans_idx <= 0;
      awaddr    <= 32'h0;
      awvalid   <= 1'b0;
      wdata     <= 32'h0;
      wvalid    <= 1'b0;
      araddr    <= 32'h0;
      arvalid   <= 1'b0;
      
      bready    <= 1'b0;
      rready    <= 1'b0;
      bwait     <= 2;
      rwait     <= 2;
    end else begin
      // Backpressure logic for B-channel
      if (!bvalid) begin
        bwait  <= 2;
        bready <= 1'b0;
      end else if (bwait > 0) begin
        bwait <= bwait - 1;
        if (bwait == 1) bready <= 1'b1;
      end

      // Backpressure logic for R-channel
      if (!rvalid) begin
        rwait  <= 2;
        rready <= 1'b0;
      end else if (rwait > 0) begin
        rwait <= rwait - 1;
        if (rwait == 1) rready <= 1'b1;
      end

      case (state)
        IDLE: begin
          if (trans_idx < 4) begin
            awaddr  <= test_addr[trans_idx];
            wdata   <= test_data[trans_idx];
            awvalid <= 1'b1;
            wvalid  <= 1'b1;
            state   <= WRITE;
          end else begin
            state   <= DONE;
          end
        end
        WRITE: begin
          if (awready && wready) begin
            awvalid <= 1'b0;
            wvalid  <= 1'b0;
          end
          // Only transition to READ once the write response is received
          if (bvalid && bready) begin
            araddr  <= test_addr[trans_idx];
            arvalid <= 1'b1;
            state   <= READ;
          end
        end
        READ: begin
          if (arready) begin
            arvalid <= 1'b0;
          end
          if (rvalid && rready) begin
            trans_idx <= trans_idx + 1;
            state     <= IDLE;
          end
        end
        DONE: begin
          // Keep signals stable when done
        end
      endcase
    end
  end

endmodule