// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_tile (clk, out_s, in_w, out_e, in_n, inst_w, inst_e, mode, reset);

parameter bw = 4;
parameter psum_bw = 16;

output [psum_bw-1:0] out_s;
input  [bw-1:0] in_w;
output [bw-1:0] out_e; 
input  [1:0] inst_w;
output [1:0] inst_e;
input  [psum_bw-1:0] in_n;
input  clk;
input  reset;
input  mode;  // 0=WS, 1=OS

reg [1:0] inst_q;
reg [bw-1:0] a_q;
reg [bw-1:0] b_q;
reg [psum_bw-1:0] c_q;
wire [psum_bw-1:0] mac_out;
reg load_ready_q;
reg mode_q;  // **KEY FIX**: Register to track previous mode

mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
    .a(a_q), 
    .b(b_q),
    .c(c_q),
    .out(mac_out)
);

assign out_e = a_q;
assign inst_e = inst_q;
assign out_s = mac_out;

always @ (posedge clk) begin
    if (reset == 1) begin
        inst_q <= 0;
        load_ready_q <= 1'b1;
        a_q <= 0;
        b_q <= 0;
        c_q <= 0;
        mode_q <= 0;  // **KEY FIX**: Reset mode tracking
    end
    else begin
        inst_q[1] <= inst_w[1];
        mode_q <= mode;  // **KEY FIX**: Track mode changes
        
        // ===============================================
        // **CORRECTED**: Mode-dependent c_q update with flush detection
        // ===============================================
        if (inst_w[1]) begin  // During execute
            if (mode == 1'b1) begin
                // Output Stationary Mode: accumulate in place
                c_q <= mac_out;
            end 
            else if (mode == 1'b0 && mode_q == 1'b1) begin
                // **KEY FIX**: Flush phase (OS→WS transition)
                // Do NOT update c_q - let accumulated value flow through
                // mac_out will naturally be c_q since a_q≈0 during flush
                c_q <= c_q;  // Explicitly keep c_q (could also omit this line)
            end
            else begin
                // Normal Weight Stationary Mode: take from north
                c_q <= in_n;
            end
        end
        // ===============================================
        
        if (inst_w[1] | inst_w[0]) begin
            a_q <= in_w;
        end
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