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
    end
    else begin
        inst_q[1] <= inst_w[1];
        
        // ===============================================
        // FIXED: Correct mode-dependent c_q update
        // ===============================================
        // The key insight: in OS mode, we accumulate the PREVIOUS mac_out
        // In WS mode, we take fresh data from the north
        // ===============================================
        
        if (mode == 1'b0) begin
            // Weight Stationary Mode (WS)
            // Pass partial sums from north to south
            if (inst_w[1]) begin
                c_q <= in_n;
            end
        end
        else begin
            // Output Stationary Mode (OS)  
            // Accumulate in place - retain c_q unless we're in the first execute
            // The accumulation happens automatically because mac_out = a*b + c_q
            // We DON'T update c_q here - it stays the same, allowing accumulation
            // ONLY update c_q during the flush phase (when mode switches back to WS)
            if (inst_w[1]) begin
                c_q <= mac_out;  // Store result for next accumulation
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