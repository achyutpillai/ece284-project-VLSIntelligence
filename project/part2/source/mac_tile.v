// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_tile (
    clk,
    out_s,
    in_w,
    out_e,
    in_n,
    inst_w,
    inst_e,
    reset,
    mode_2b       // 0: 4-bit vanilla, 1: 2-bit SIMD
);

parameter bw      = 4;
parameter psum_bw = 16;

output [psum_bw-1:0] out_s;
input  [bw-1:0]      in_w;   // inst[1]: execute, inst[0]: kernel loading
output [bw-1:0]      out_e; 
input  [1:0]         inst_w;
output [1:0]         inst_e;
input  [psum_bw-1:0] in_n;
input                clk;
input                reset;
input                mode_2b;  // new mode select

reg  [1:0]           inst_q;
reg  [bw-1:0]        a_q;
reg  [bw-1:0]        w0_q; // weight 0
reg  [bw-1:0]        w1_q; // weight 1 for 2-bit mode
reg  [psum_bw-1:0]   c_q;
wire [psum_bw-1:0]   mac_out;
reg                  load_ready_q;
reg                  w_load_cnt;

mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
    .a(a_q), 
    .b(w0_q),
    .c(c_q),
    .out(mac_out)
);

assign out_e  = a_q;
assign inst_e = inst_q;


wire signed [2:0] act0_s = {1'b0, a_q[1:0]};     // low 2 bits with 0 pad
wire signed [2:0] act1_s = {1'b0, a_q[3:2]};     // high 2 bits with 0 pad

wire signed [bw-1:0] wgt0_s  = w0_q;  // 4-bit signed weight
wire signed [bw-1:0] wgt1_s  = w1_q;  // 4-bit signed weight

// 3b x 4b -> 7b signed products // calculate as psum_bw to avoid overflow and extend sign
wire signed [psum_bw-1:0] prod0_s = act0_s * wgt0_s;
wire signed [psum_bw-1:0] prod1_s = act1_s * wgt1_s;

wire signed [psum_bw-1:0] c_q_s = c_q;

wire signed [psum_bw-1:0] simd_mac_out =
    c_q_s + prod0_s + prod1_s;

assign out_s = mode_2b ? simd_mac_out : mac_out;

always @ (posedge clk) begin
    if (reset == 1) begin
        inst_q       <= 0;
        load_ready_q <= 1'b1;
        a_q          <= 0;
        w0_q         <= 0;
        w1_q         <= 0;
        c_q          <= 0;
        w_load_cnt   <= 0;
    end
    else begin
        inst_q[1] <= inst_w[1];
        c_q       <= in_n;

        if (inst_w[1] | inst_w[0]) begin
            a_q <= in_w;
        end

        if (inst_w[0] & load_ready_q) begin
            if (mode_2b) begin
                // SIMD 2-bit mode: Load w0 then w1
                if (w_load_cnt == 0) begin
                    w0_q       <= in_w;
                    w_load_cnt <= 1'b1;
                end else begin
                    w1_q         <= in_w;
                    w_load_cnt   <= 0;
                    load_ready_q <= 1'b0;
                end
            end else begin
                // Vanilla 4-bit mode: Load single weight
                w0_q         <= in_w;
                load_ready_q <= 1'b0;
            end
        end

        if (load_ready_q == 1'b0) begin
            inst_q[0] <= inst_w[0];
        end
    end
end

endmodule