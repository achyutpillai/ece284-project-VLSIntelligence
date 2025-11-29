// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_tile (clk, out_s, in_w, out_e, in_n, inst_w, inst_e, reset, mode_2b);

parameter bw = 4;
parameter psum_bw = 16;

output [psum_bw-1:0] out_s;
input  [bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
output [bw-1:0] out_e; 
input  [1:0] inst_w;
output [1:0] inst_e;
input  [psum_bw-1:0] in_n;
input  clk;
input  reset;
input  mode_2b; // 1: 2-bit Act/4-bit Wgt, 0: 4-bit Act/4-bit Wgt

reg [1:0] inst_q;
reg [bw-1:0] a_q;
reg [psum_bw-1:0] c_q;
reg load_ready_q;
reg [bw-1:0] w_q0; // Weight 0
reg [bw-1:0] w_q1; // Weight 1
reg w_load_cnt;    // Counter for loading 2 weights in SIMD mode

// --- Arithmetic Logic ---

// Sign extension: Act is Unsigned (zero-pad MSB), Weight is Signed.
wire signed [bw:0]   a_4b_ext = {1'b0, a_q};             // 5-bit signed (positive)
wire signed [bw-1:0] w_0_signed = w_q0;                  // 4-bit signed
wire signed [bw-1:0] w_1_signed = w_q1;                  // 4-bit signed

// 2-bit Slices (extended to signed)
wire signed [2:0] a_2b_lo = {1'b0, a_q[1:0]};            // 3-bit signed (positive)
wire signed [2:0] a_2b_hi = {1'b0, a_q[3:2]};            // 3-bit signed (positive)

reg signed [psum_bw-1:0] mac_product;

always @(*) begin
    if (mode_2b) begin
        // SIMD Mode: 2-bit Act, 4-bit Weight [cite: 151]
        // Process 2 Input Channels: (Act_Lo * W0) + (Act_Hi * W1)
        mac_product = (a_2b_lo * w_0_signed) + (a_2b_hi * w_1_signed);
    end else begin
        // Vanilla Mode: 4-bit Act, 4-bit Weight [cite: 32]
        // Standard MAC: Act * W0
        mac_product = a_4b_ext * w_0_signed;
    end
end

// Output calculation: PSUM_in (from North) + Calculated Product
// Note: We perform the add combinationaly here, c_q captures the input PSUM
wire [psum_bw-1:0] mac_out = c_q + mac_product; 

assign out_s = mac_out;
assign out_e = a_q;
assign inst_e = inst_q;

// --- Control & Loading Logic ---

always @ (posedge clk) begin
    if (reset == 1) begin
        inst_q <= 0;
        load_ready_q <= 1'b1;
        a_q <= 0;
        c_q <= 0;
        w_q0 <= 0;
        w_q1 <= 0;
        w_load_cnt <= 0;
    end
    else begin
        inst_q[1] <= inst_w[1];
        c_q <= in_n; // Capture PSUM from North
        
        // Activation Loading (Execute)
        if (inst_w[1] | inst_w[0]) begin
            a_q <= in_w;
        end

        // Weight Loading Logic 
        if (inst_w[0] & load_ready_q) begin
            if (mode_2b) begin
                // SIMD Mode: Load W0 then W1
                if (w_load_cnt == 0) begin
                    w_q0 <= in_w;
                    w_load_cnt <= 1;
                    // load_ready_q stays 1 to accept second weight
                end else begin
                    w_q1 <= in_w;
                    w_load_cnt <= 0;
                    load_ready_q <= 1'b0; // Done loading
                end
            end else begin
                // Vanilla Mode: Load W0 only
                w_q0 <= in_w;
                load_ready_q <= 1'b0;
            end
        end

        // Pass load instruction to neighbor only when this tile is full
        if (load_ready_q == 1'b0) begin
            inst_q[0] <= inst_w[0];
        end
    end
end

endmodule