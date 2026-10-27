/*
 * Hierarchical (sign -> exponent -> mantissa) floating-point compare-and-swap.
 * Tiny Tapeout wrapper.  Fully synchronous and synthesizable.
 *
 * The unit compares two FP32 numbers one field at a time and stops at the first
 * field that decides the order.  The number of clock cycles it needs (1, 2 or 3)
 * is reported, so the data-dependent latency is visible on the pins.  Fields that
 * are not needed are never evaluated (their comparator inputs are held at 0).
 * This is the clocked form of the self-timed idea: same logic, early exit counted in cycles.
 *
 * Pins
 *   ui_in[7:0]   data byte
 *   uio_in[0]    WR   : on a rising clk with WR=1, ui_in is shifted in (8 bytes: a[31:24]..a[7:0], b[31:24]..b[7:0])
 *   uio_in[3:1]  SEL  : picks which byte of the result is shown on uo_out
 *   uio_out[4]   DONE : result valid
 *   uio_out[6:5] CYC : cycles used (1 = sign decided, 2 = exponent decided, 3 = mantissa)
 *   uo_out       result byte SEL: 0..3 = larger value (MSB first), 4..7 = smaller value (MSB first)
 * Loading the 8th byte starts a compare.  NaN is treated like an ordinary bit pattern (not handled).
 */
`default_nettype none

module tt_um_hier_fp_cas (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
  reg [31:0] a, b;
  reg [2:0]  cnt;          // bytes loaded
  reg [1:0]  st;           // 0 idle/load, 1 sign, 2 exponent, 3 mantissa
  reg        done, gt;
  reg [1:0]  cyc;

  wire wr = uio_in[0];
  wire [2:0] sel = uio_in[3:1];

  // field comparators; inputs are gated to 0 unless that stage is active (operand isolation)
  wire en_e = (st == 2'd2), en_m = (st == 2'd3);
  wire [7:0]  ea = en_e ? a[30:23] : 8'd0, eb = en_e ? b[30:23] : 8'd0;
  wire [22:0] ma = en_m ? a[22:0]  : 23'd0, mb = en_m ? b[22:0]  : 23'd0;
  wire e_ne = (ea != eb), e_gt = (ea > eb);
  wire m_gt = (ma > mb);
  wire neg  = a[31];                       // both have the same sign in stages 2 and 3

  always @(posedge clk) begin
    if (!rst_n) begin
      a <= 0; b <= 0; cnt <= 0; st <= 0; done <= 0; gt <= 0; cyc <= 0;
    end else begin
      case (st)
        2'd0: if (wr && ena) begin
                {a, b} <= {a[23:0], b, ui_in};     // 64-bit shift register, byte at a time
                done   <= 1'b0;
                cnt    <= cnt + 3'd1;
                if (cnt == 3'd7) begin cnt <= 0; st <= 2'd1; end
              end
        2'd1: begin                                 // stage 1: sign
                cyc <= 2'd1;
                if (a[31] != b[31]) begin gt <= ~a[31]; st <= 0; done <= 1'b1; end
                else st <= 2'd2;
              end
        2'd2: begin                                 // stage 2: exponent
                cyc <= 2'd2;
                if (e_ne) begin gt <= neg ? ~e_gt : e_gt; st <= 0; done <= 1'b1; end
                else st <= 2'd3;
              end
        2'd3: begin                                 // stage 3: mantissa (equal numbers: gt=0, either order is fine)
                cyc <= 2'd3;
                gt <= neg ? (~m_gt & (ma != mb)) : m_gt;
                st <= 0; done <= 1'b1;
              end
      endcase
    end
  end

  wire [63:0] res = gt ? {a, b} : {b, a};          // {larger, smaller}
  wire [5:0] sh = {sel, 3'b000};
  wire [63:0] rs = res << sh;
  assign uo_out  = rs[63:56];
  assign uio_out = {1'b0, cyc, done, 4'b0};   // uio[3:0] are inputs, uio[7] unused
  assign uio_oe  = 8'b0111_0000;
  wire _unused = &{1'b0, uio_in[7:4]};
endmodule
