// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Modified to support mixed precision (2-bit unsigned act, 4-bit signed weight)
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
input  mode_2b; // New control signal

reg [1:0] inst_q;
reg [bw-1:0] a_q;
reg [bw-1:0] b_q;
reg [psum_bw-1:0] c_q;
wire [psum_bw-1:0] mac_out;
reg load_ready_q;

// Internal wire for the MAC input "a"
wire [bw-1:0] a_mac_input;

// -----------------------------------------------------------------
// Mode Selection Logic
// -----------------------------------------------------------------
// Mode 1 (2-bit): Activations are Unsigned. We take the LSBs and Zero-Extend.
//                 Example: 2'b11 (3) -> 4'b0011 (3). 
//                 This prevents the MAC from interpreting it as -1.
// Mode 0 (4-bit): Pass the full 4-bit value directly (Standard behavior).
assign a_mac_input = (mode_2b) ? { {(bw-2){1'b0}}, a_q[1:0] } : a_q;

mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
    .a(a_mac_input), // Use the processed activation
    .b(b_q),         // Weights are always 4-bit signed
    .c(c_q),
    .out(mac_out)
);

assign out_e = a_q; // Pass the original packed/full value to the neighbor
assign inst_e = inst_q;
assign out_s = mac_out;

always @ (posedge clk) begin
    if (reset == 1) begin
        inst_q <= 0;
        load_ready_q <= 1'b1;
        a_q <= 0;
        b_q <= 0;
        c_q <= 0;
    end
    else begin
        inst_q[1] <= inst_w[1];
        c_q <= in_n;
        // Latch activation from West
        if (inst_w[1] | inst_w[0]) begin
            a_q <= in_w;
        end
        // Latch Weight
        if (inst_w[0] & load_ready_q) begin
            b_q <= in_w;
            load_ready_q <= 1'b0;
        end
        if (load_ready_q == 1'b0) begin
            inst_q[0] <= inst_w[0];
        end
    end
end

endmodule